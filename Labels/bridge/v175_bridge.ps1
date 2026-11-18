# V175 label print bridge
# Lets the scan station page (GitHub Pages or http://127.0.0.1:9123/) send RAW ZPL to the Zebra share.
# Endpoints: /status /printers /print /unknown /save  (plus / and /layout/* for a local copy of the page)
# No inventory passes through here: the page reads your SAP exports in the browser.
# Start it with Start-V175-Labels.bat. Close this window to stop it.
param(
  [int]$Port = 9123,
  [string]$Printer = '\\localhost\ZEBRA',
  # Page to open when the bridge starts. Put your GitHub Pages address here, e.g.
  # 'https://yourname.github.io/v175-scan-station/'
  [string]$DashboardUrl = 'https://aaronzandman.github.io/Route2/Labels/',
  [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path      # ...\bridge
$Site = Split-Path -Parent $Root                                # repo folder with index.html
$Data = Join-Path $Root 'logs'                                  # git-ignored
$Files = @{
  unknown  = 'unknown_scans.csv'
  printlog = 'print_log.csv'
}
if (-not (Test-Path $Data)) { New-Item -ItemType Directory -Path $Data | Out-Null }
$Headers = @{ unknown = 'Code,Tag,FirstSeen'; printlog = 'Time,Kind,Scanned,Tag,Serial,Copies,Result' }
foreach ($k in $Files.Keys) {
  $p = Join-Path $Data $Files[$k]
  if (-not (Test-Path $p)) { [IO.File]::WriteAllText($p, $Headers[$k] + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
}
function FPath([string]$key) { Join-Path $Data $Files[$key] }
$Utf8 = New-Object System.Text.UTF8Encoding($false)

# ---------- file helpers (read even while Excel has the file open) ----------
function Read-Shared([string]$path) {
  $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
  try { $sr = New-Object IO.StreamReader($fs, $Utf8, $true); $sr.ReadToEnd() } finally { $fs.Dispose() }
}
function Csv-Escape([string]$v) {
  if ($null -eq $v) { return '' }
  if ($v -match '[",\r\n]') { return '"' + $v.Replace('"', '""') + '"' }
  return $v
}
function Append-Row([string]$key, [string[]]$values) {
  # Append only. Existing rows are never rewritten.
  $line = (($values | ForEach-Object { Csv-Escape $_ }) -join ',') + "`r`n"
  $path = FPath $key
  $fs = New-Object IO.FileStream($path, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
  try { $b = $Utf8.GetBytes($line); $fs.Write($b, 0, $b.Length) } finally { $fs.Dispose() }
}
function Now { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }

# ---------- printing: RAW ZPL via copy /b to the Windows share ----------
function Send-Zpl([string]$zpl) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('v175_' + [guid]::NewGuid().ToString('N') + '.zpl')
  [IO.File]::WriteAllText($tmp, $zpl, [Text.Encoding]::ASCII)
  try {
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c copy /b "' + $tmp + '" "' + $Printer + '"') `
         -WindowStyle Hidden -Wait -PassThru
    return ($p.ExitCode -eq 0)
  } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

# ---------- HTTP plumbing ----------
function Find-HeaderEnd([byte[]]$b, [int]$len) {
  for ($i = 3; $i -lt $len; $i++) {
    if ($b[$i-3] -eq 13 -and $b[$i-2] -eq 10 -and $b[$i-1] -eq 13 -and $b[$i] -eq 10) { return $i + 1 }
  }
  return -1
}
function Read-Request($stream) {
  $ms = New-Object IO.MemoryStream
  $buf = New-Object byte[] 65536
  $hEnd = -1
  while ($hEnd -lt 0) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return $null }
    $ms.Write($buf, 0, $n)
    $all = $ms.ToArray()
    $hEnd = Find-HeaderEnd $all $all.Length
    if ($ms.Length -gt 1MB) { return $null }
  }
  $head = [Text.Encoding]::ASCII.GetString($all, 0, $hEnd)
  $lines = $head -split "`r`n"
  $parts = $lines[0] -split ' '
  $len = 0
  foreach ($l in $lines) { if ($l -match '^(?i)content-length:\s*(\d+)') { $len = [int]$matches[1] } }
  while ($ms.Length - $hEnd -lt $len) {
    $n = $stream.Read($buf, 0, $buf.Length); if ($n -le 0) { break }; $ms.Write($buf, 0, $n)
  }
  $all = $ms.ToArray()
  $body = if ($len -gt 0) { $Utf8.GetString($all, $hEnd, [Math]::Min($len, $all.Length - $hEnd)) } else { '' }
  $path = ($parts[1] -split '\?')[0]
  return @{ Method = $parts[0].ToUpper(); Path = $path; Body = $body }
}
function Send-Response($stream, [int]$code, [string]$type, $body) {
  $reason = switch ($code) { 200 {'OK'} 204 {'No Content'} 400 {'Bad Request'} 404 {'Not Found'} default {'Server Error'} }
  if ($body -is [string]) { $bytes = $Utf8.GetBytes($body) } elseif ($null -eq $body) { $bytes = New-Object byte[] 0 } else { $bytes = $body }
  $h = "HTTP/1.1 $code $reason`r`n" +
       "Content-Type: $type`r`n" +
       "Content-Length: $($bytes.Length)`r`n" +
       "Access-Control-Allow-Origin: *`r`n" +
       "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
       "Access-Control-Allow-Headers: Content-Type`r`n" +
       "Access-Control-Allow-Private-Network: true`r`n" +
       "Cache-Control: no-store`r`n" +
       "Connection: close`r`n`r`n"
  $hb = [Text.Encoding]::ASCII.GetBytes($h)
  $stream.Write($hb, 0, $hb.Length)
  if ($bytes.Length) { $stream.Write($bytes, 0, $bytes.Length) }
  $stream.Flush()
}
function Json($obj) { ConvertTo-Json $obj -Depth 5 -Compress }

# ---------- routes ----------
function Handle($req, $stream) {
  if ($req.Method -eq 'OPTIONS') { Send-Response $stream 204 'text/plain' $null; return }
  switch ($req.Path) {
    { $_ -in '/', '/index.html' } {
      Send-Response $stream 200 'text/html; charset=utf-8' (Read-Shared (Join-Path $Site 'index.html')); return }
    { $_ -in '/layout/v175_bins.csv', '/layout/v175_locations.csv' } {
      Send-Response $stream 200 'text/csv; charset=utf-8' (Read-Shared (Join-Path $Site ($_.TrimStart('/').Replace('/', '\')))); return }
    '/status' {
      $m = @{}
      foreach ($k in $Files.Keys) { $p = FPath $k; $m[$k] = if (Test-Path $p) { (Get-Item $p).LastWriteTimeUtc.Ticks.ToString() } else { '' } }
      Send-Response $stream 200 'application/json' (Json @{ ok = $true; printer = $Printer; files = $m; time = (Now) }); return }
    '/printers' {
      try { $list = @(Get-Printer | Select-Object Name, ShareName, Shared, PortName, DriverName) } catch { $list = @() }
      Send-Response $stream 200 'application/json' (Json @{ ok = $true; using = $Printer; printers = $list }); return }
    '/unknown' {
      Send-Response $stream 200 'text/csv; charset=utf-8' (Read-Shared (FPath 'unknown')); return }
    '/print' {
      $j = $req.Body | ConvertFrom-Json
      $copies = [Math]::Max(1, [Math]::Min(99, [int]$j.copies))
      $zpl = ($j.zpl * $copies)        # ^PQ1 per label, sent n times
      $ok = Send-Zpl $zpl
      $result = if ($ok) { 'OK' } else { 'FAILED' }
      try { Append-Row 'printlog' @((Now), [string]$j.kind, [string]$j.scanned, [string]$j.tag, [string]$j.serial, [string]$copies, $result) } catch {}
      Write-Host ("{0}  {1,-7} {2,-18} x{3}  {4}" -f (Now), $j.kind, $j.tag, $copies, $result)
      Send-Response $stream 200 'application/json' (Json @{ ok = $ok; result = $result }); return }
    '/save' {
      # Body: { "file": "unknown", "code": "..." }  Logs an unknown code once, Tag left blank.
      $j = $req.Body | ConvertFrom-Json
      if ($j.file -ne 'unknown' -or -not $j.code) { Send-Response $stream 400 'application/json' (Json @{ ok = $false; error = 'only file=unknown with a code is accepted' }); return }
      $code = ([string]$j.code).Trim()
      $known = @(ConvertFrom-Csv (Read-Shared (FPath 'unknown')) | ForEach-Object { $_.Code })
      $added = $false
      if ($known -notcontains $code) { Append-Row 'unknown' @($code, '', (Now)); $added = $true }
      Send-Response $stream 200 'application/json' (Json @{ ok = $true; added = $added }); return }
    default { Send-Response $stream 404 'application/json' (Json @{ ok = $false; error = 'not found' }) }
  }
}

# ---------- start listening on 127.0.0.1 and ::1 ----------
$listeners = @()
foreach ($ip in @([Net.IPAddress]::Loopback, [Net.IPAddress]::IPv6Loopback)) {
  try { $l = New-Object Net.Sockets.TcpListener($ip, $Port); $l.Start(); $listeners += $l }
  catch { Write-Host "Could not listen on $ip port $Port : $($_.Exception.Message)" -ForegroundColor Yellow }
}
if (-not $listeners) { Write-Host 'Bridge could not start. Is another copy already running?' -ForegroundColor Red; exit 1 }

$Host.UI.RawUI.WindowTitle = 'V175 label bridge - keep this window open'
Write-Host "V175 label bridge running on http://127.0.0.1:$Port/   printer: $Printer" -ForegroundColor Green
Write-Host 'Leave this window open while you scan. Close it to stop.'
Write-Host "Logs: $Data"
if (-not $NoBrowser) { Start-Process $DashboardUrl }

while ($true) {
  $busy = $false
  foreach ($l in $listeners) {
    if ($l.Pending()) {
      $busy = $true
      $client = $l.AcceptTcpClient()
      try {
        $stream = $client.GetStream(); $stream.ReadTimeout = 3000
        # Browsers open spare connections that never send anything; drop those quickly.
        $waited = 0
        while (-not $stream.DataAvailable -and $waited -lt 1500) { Start-Sleep -Milliseconds 10; $waited += 10 }
        if ($stream.DataAvailable) {
          $req = Read-Request $stream
          if ($req) { Handle $req $stream }
        }
      } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        try { Send-Response $stream 500 'application/json' (Json @{ ok = $false; error = $_.Exception.Message }) } catch {}
      } finally { $client.Close() }
    }
  }
  if (-not $busy) { Start-Sleep -Milliseconds 20 }
}
