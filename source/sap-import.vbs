' ============================================================================
'  Import to Route Planner  —  SAP GUI macro
'  Reads the service-order list on your current SAP screen (built for IW49N)
'  and opens the online Route Planner with your whole call list already loaded.
'
'  HOW TO USE
'    1. Sign into SAP Logon (system 800).
'    2. Run IW49N (or your usual call-list transaction) and let the list display.
'    3. Double-click this file  (Import_to_RoutePlanner.vbs).
'       -> Edge opens the Route Planner with your calls loaded; the old list is replaced.
'
'  REQUIREMENT: SAP GUI Scripting must be enabled (see the setup guide). If it is
'  off, SAP shows "Scripting is disabled by the server/client" — ask IT to turn on
'  sapgui/user_scripting, and tick SAP GUI Options > Accessibility & Scripting >
'  Scripting > Enable scripting.
'
'  Nothing is sent anywhere except the Route Planner URL you open in your own browser.
' ============================================================================

Option Explicit

' ---- SETTINGS you can change -----------------------------------------------
Dim PLANNER_URL
PLANNER_URL = "https://aaronzandman.github.io/Route2/ALL.html"   ' online Route Planner (company-wide). Opens in Edge.
' ----------------------------------------------------------------------------

' The 15 columns the Route Planner expects, in order. Each entry is a list of
' possible SAP column titles (pipe-separated) — the macro matches your grid's
' titles against these so column order/renames don't matter. Order number and
' description are the ones that must be present.
Dim WANT(14)
WANT(0)  = "Order Type|Order type|OrderType|Auart"
WANT(1)  = "MaintActivType|Maint.Activ.Type|Activity Type"
WANT(2)  = "Basic fin. date|Bas. fin. date|Basic finish date|Basic fin.date"
WANT(3)  = "Earliest finish|Latest finish|Finish"
WANT(4)  = "Priority|Priorty"
WANT(5)  = "Customer|Sold-To Party|Sold-to party"
WANT(6)  = "Personnel No.|Personnel no.|Personnel Number"
WANT(7)  = "Activity"
WANT(8)  = "Serial Number|Serial number|SerialNo"
WANT(9)  = "Order|Order Number|Order No."
WANT(10) = "Description|Short text|Short Text|Description of technical object"
WANT(11) = "Oper.WorkCenter|Main WorkCtr|Work center|Work Center|Oper. Work center"
WANT(12) = "User status|User Status|Status|System Status"
WANT(13) = "Material"
WANT(14) = "Location|Functional Location|Func. Location|TchObjAltLabel"

Dim HEADER
HEADER = "Order Type" & vbTab & "MaintActivType" & vbTab & "Basic fin. date" & vbTab & _
  "Earliest finish" & vbTab & "Priority" & vbTab & "Customer" & vbTab & "Personnel No." & vbTab & _
  "Activity" & vbTab & "Serial Number" & vbTab & "Order" & vbTab & "Description" & vbTab & _
  "Oper.WorkCenter" & vbTab & "User status" & vbTab & "Material" & vbTab & "Location"

' ---- connect to the running SAP session ------------------------------------
Dim SapGuiAuto, app, connection, session
On Error Resume Next
Set SapGuiAuto = GetObject("SAPGUI")
If Err.Number <> 0 Or SapGuiAuto Is Nothing Then
  MsgBox "SAP GUI isn't running, or scripting can't reach it." & vbCrLf & vbCrLf & _
         "Open SAP Logon, sign in, display your IW49N list, then run this again." & vbCrLf & _
         "If it still fails, SAP GUI Scripting is probably turned off (see the setup guide).", vbExclamation, "Route Planner import"
  WScript.Quit
End If
Set app = SapGuiAuto.GetScriptingEngine
Set connection = app.Children(0)
Set session = connection.Children(0)
On Error GoTo 0
If session Is Nothing Then
  MsgBox "No open SAP session found. Sign into SAP (system 800) first.", vbExclamation, "Route Planner import"
  WScript.Quit
End If

' ---- find the ALV grid on the current screen -------------------------------
Dim grid
Set grid = FindGrid(session.ActiveWindow)
If grid Is Nothing Then
  MsgBox "No service-order list found on the current SAP screen." & vbCrLf & vbCrLf & _
         "Run IW49N (or your call-list transaction) and let the list display, then run this again.", vbExclamation, "Route Planner import"
  WScript.Quit
End If

' ---- map the planner's wanted columns to the grid's actual columns ---------
Dim gcols, colId(14), i, j, k, title, found
Set gcols = grid.ColumnOrder
For i = 0 To 14
  colId(i) = ""
  Dim names : names = Split(WANT(i), "|")
  For j = 0 To gcols.Count - 1
    Dim id : id = gcols.ElementAt(j)
    title = ""
    On Error Resume Next
    title = grid.GetDisplayedColumnTitle(id)
    On Error GoTo 0
    For k = 0 To UBound(names)
      If Norm(title) = Norm(names(k)) Then colId(i) = id : Exit For
    Next
    If colId(i) <> "" Then Exit For
  Next
Next

If colId(9) = "" Then
  MsgBox "Couldn't find the 'Order' column in this list." & vbCrLf & vbCrLf & _
         "Make sure the IW49N list shows the Order and Description columns, then run this again." & vbCrLf & _
         "(If your columns are named differently, send me the column titles and I'll adjust the macro.)", vbExclamation, "Route Planner import"
  WScript.Quit
End If

' ---- read every row (scrolling the grid so all rows load) ------------------
Dim total, visible, rowsText, r, line, v
total = grid.RowCount
visible = grid.VisibleRowCount
If visible < 1 Then visible = 1
rowsText = HEADER
r = 0
Do While r < total
  grid.firstVisibleRow = r
  Dim last : last = r + visible - 1
  If last > total - 1 Then last = total - 1
  Dim rr
  For rr = r To last
    line = ""
    For i = 0 To 14
      v = ""
      If colId(i) <> "" Then
        On Error Resume Next
        v = grid.GetCellValue(rr, colId(i))
        On Error GoTo 0
      End If
      ' tabs/newlines inside a cell would break the row layout
      v = Replace(Replace(Replace(v, vbTab, " "), vbCr, " "), vbLf, " ")
      If i > 0 Then line = line & vbTab
      line = line & v
    Next
    ' only keep rows that actually have an order number
    If Trim(Split(line, vbTab)(9)) <> "" Then rowsText = rowsText & vbLf & line
  Next
  r = last + 1
Loop

Dim nLines : nLines = UBound(Split(rowsText, vbLf))   ' minus the header
If nLines < 1 Then
  MsgBox "The list has no calls to import.", vbInformation, "Route Planner import"
  WScript.Quit
End If

' ---- encode to base64url and open the planner ------------------------------
' A full list encodes to ~15-20 KB, which is too long for a command line. So we write a tiny local launcher page
' that carries the data and redirects the browser to the planner — the long part lives in the file, not the command line.
Dim payload, url
payload = Base64Url(rowsText)
url = PLANNER_URL & "#sap=" & payload

Dim sh : Set sh = CreateObject("WScript.Shell")
Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim tempFile : tempFile = sh.ExpandEnvironmentStrings("%TEMP%") & "\RoutePlannerImport.html"

Dim html
html = "<!doctype html><html><head><meta charset=""utf-8""><title>Opening Route Planner</title></head>" & _
       "<body style=""font-family:Segoe UI,Arial,sans-serif;padding:28px;color:#1F6B4F"">" & _
       "Opening Route Planner with " & nLines & " call(s)&hellip;" & _
       "<script>location.replace(" & JsStr(url) & ");<" & "/script></body></html>"

Dim ts : Set ts = fso.CreateTextFile(tempFile, True, False)   ' overwrite; content is pure ASCII, matches meta utf-8
ts.Write html : ts.Close

' Open the launcher in Edge (falls back to the default browser if Edge isn't found).
Dim shellApp : Set shellApp = CreateObject("Shell.Application")
On Error Resume Next
shellApp.ShellExecute "msedge.exe", """" & tempFile & """", "", "open", 1
If Err.Number <> 0 Then
  Err.Clear
  shellApp.ShellExecute tempFile, "", "", "open", 1   ' default browser
End If
On Error GoTo 0

' done — the launcher redirects, and the planner replaces its list. Silent on success.
WScript.Quit

' ============================================================================
' helpers
' ============================================================================
' JavaScript string literal (for the launcher page).
Function JsStr(s)
  Dim t : t = CStr(s)
  t = Replace(t, "\", "\\")
  t = Replace(t, """", "\""")
  JsStr = """" & t & """"
End Function

Function Norm(s)
  Dim t, ch, out
  t = LCase(CStr(s))
  out = ""
  Dim p
  For p = 1 To Len(t)
    ch = Mid(t, p, 1)
    If (ch >= "a" And ch <= "z") Or (ch >= "0" And ch <= "9") Then out = out & ch
  Next
  Norm = out
End Function

' Depth-first search for the first GuiGridView under a node.
Function FindGrid(node)
  Set FindGrid = Nothing
  On Error Resume Next
  Dim t : t = node.Type
  On Error GoTo 0
  If t = "GuiGridView" Then
    Set FindGrid = node
    Exit Function
  End If
  Dim kids : Set kids = Nothing   ' leaf controls have no .Children; keep it a valid object ref for "Is Nothing"
  On Error Resume Next
  Set kids = node.Children
  On Error GoTo 0
  If kids Is Nothing Then Exit Function
  Dim i2, res
  For i2 = 0 To kids.Count - 1
    Set res = FindGrid(kids.ElementAt(i2))
    If Not (res Is Nothing) Then
      Set FindGrid = res
      Exit Function
    End If
  Next
End Function

' UTF-8 base64url (no padding), the format the Route Planner's #sap= import expects.
Function Base64Url(text)
  Dim stm, b64
  ' UTF-8 bytes. ADODB.Stream writes a 3-byte UTF-8 BOM first, so skip it (Position = 3) before reading.
  Set stm = CreateObject("ADODB.Stream")
  stm.Type = 2 : stm.Charset = "utf-8" : stm.Open : stm.WriteText text
  stm.Position = 0 : stm.Type = 1 : stm.Position = 3 : Dim bytes : bytes = stm.Read : stm.Close
  ' standard base64 via MSXML
  Dim xml, node
  Set xml = CreateObject("MSXML2.DOMDocument")
  Set node = xml.createElement("b64")
  node.DataType = "bin.base64"
  node.NodeTypedValue = bytes
  b64 = node.Text
  ' make it url-safe, strip padding and whitespace
  b64 = Replace(b64, vbCrLf, "") : b64 = Replace(b64, vbLf, "") : b64 = Replace(b64, vbCr, "") : b64 = Replace(b64, " ", "")
  b64 = Replace(b64, "+", "-") : b64 = Replace(b64, "/", "_") : b64 = Replace(b64, "=", "")
  Base64Url = b64
End Function
