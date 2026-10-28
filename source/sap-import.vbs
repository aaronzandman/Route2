' ============================================================================
'  Copy calls to Route Planner  —  SAP GUI macro
'  Reads the service-order list on your current SAP screen (built for IW49N)
'  and copies it to the clipboard. You then paste it into the Route Planner.
'
'  HOW TO USE
'    1. Sign into SAP Logon (system 800).
'    2. Run IW49N (or your usual call-list transaction) and let the list display.
'    3. Run this macro  (double-click, or play it from SAP GUI Alt+F12).
'       -> It copies your calls. A box tells you how many.
'    4. Open the Route Planner, click the "Paste service call rows" box,
'       press Ctrl+V, then select "Load calls".  Done.
'
'  This script only reads SAP and copies text to your clipboard. It does not
'  write any files, open any programs, or send anything anywhere.
'
'  REQUIREMENT: SAP GUI Scripting must be enabled (Alt+F12 test in the guide).
' ============================================================================

Option Explicit

' Set to False if you'd rather open your IW49N list yourself before running this.
Const RUN_IW49N = True

' The 15 columns the Route Planner expects, in order. Each entry is a list of
' possible SAP column titles (pipe-separated); the macro matches your grid's
' titles against these, so column order or renames don't matter.
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
         "Open SAP Logon, sign in, display your IW49N list, then run this again.", vbExclamation, "Copy calls to Route Planner"
  WScript.Quit
End If
Set app = SapGuiAuto.GetScriptingEngine
Set connection = app.Children(0)
Set session = connection.Children(0)
On Error GoTo 0
If session Is Nothing Then
  MsgBox "No open SAP session found. Sign into SAP (system 800) first.", vbExclamation, "Copy calls to Route Planner"
  WScript.Quit
End If

' ---- optionally run IW49N and execute with your last-used selection --------
' SAP remembers your last IW49N selection per user, so Execute (F8) reproduces your list. If you pick a saved
' variant each time instead, record those steps once (Alt+F12) and send them to me, and I'll wire them in here.
If RUN_IW49N Then
  On Error Resume Next
  session.findById("wnd[0]/tbar[0]/okcd").Text = "/nIW49N"
  session.findById("wnd[0]").sendVKey 0        ' open IW49N (lands on the selection screen)
  session.findById("wnd[0]").sendVKey 8        ' Execute (F8) with your remembered selection
  On Error GoTo 0
End If

' ---- find the ALV grid on the current screen -------------------------------
Dim grid
Set grid = FindGrid(session.ActiveWindow)
If grid Is Nothing Then
  MsgBox "No service-order list found on the current SAP screen." & vbCrLf & vbCrLf & _
         "Run IW49N (or your call-list transaction) and let the list display, then run this again.", vbExclamation, "Copy calls to Route Planner"
  WScript.Quit
End If

' ---- map the planner's wanted columns to the grid's actual columns ---------
Dim gcols, colId(14), i, j, k, title
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
         "(If your columns are named differently, send me the column titles and I'll adjust the macro.)", vbExclamation, "Copy calls to Route Planner"
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
      v = Replace(Replace(Replace(v, vbTab, " "), vbCr, " "), vbLf, " ")
      If i > 0 Then line = line & vbTab
      line = line & v
    Next
    If Trim(Split(line, vbTab)(9)) <> "" Then rowsText = rowsText & vbLf & line
  Next
  r = last + 1
Loop

Dim nLines : nLines = UBound(Split(rowsText, vbLf))   ' minus the header row
If nLines < 1 Then
  MsgBox "The list has no calls to copy.", vbInformation, "Copy calls to Route Planner"
  WScript.Quit
End If

' ---- copy to the clipboard -------------------------------------------------
SetClipboard rowsText

MsgBox "Copied " & nLines & " call(s)." & vbCrLf & vbCrLf & _
       "Now open the Route Planner, click the 'Paste service call rows' box, press Ctrl+V, " & _
       "and select Load calls. Your whole list is replaced.", vbInformation, "Copy calls to Route Planner"
WScript.Quit

' ============================================================================
' helpers
' ============================================================================

' Put text on the Windows clipboard by piping it to the built-in clip tool.
Sub SetClipboard(text)
  Dim sh, ex
  Set sh = CreateObject("WScript.Shell")
  Set ex = sh.Exec("clip")
  ex.StdIn.Write text
  ex.StdIn.Close
  ' wait briefly for clip to finish reading
  Do While ex.Status = 0
    WScript.Sleep 50
  Loop
End Sub

Function Norm(s)
  Dim t, ch, out, p
  t = LCase(CStr(s))
  out = ""
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
