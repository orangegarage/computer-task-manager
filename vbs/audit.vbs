'#============================================================================================
'#============================================================================================
'#  SCRIPT.........:	ProcessAudit.hta
'#  AUTHOR.........:	McKenney's Inc
'#  VERSION........:	2.01
'#  CREATED........:	05/07/18
'#  LICENSE........:	Freeware
'#  REQUIREMENTS...:  
'#
'#  DESCRIPTION....:	Retrieves a list of running processes on a remote
'#						PC and allows the user to kill any as required.
'#
'#  NOTES..........:	Built on a script by spiceuser
'# 
'#  CUSTOMIZE......:  
'#============================================================================================
'#  REVISED BY.....:    Jinyong Jeong 
'#  EMAIL..........:    jinyong.jeong@mckenneys.com
'#  REVISION DATE..:    06/20/2019
'#  REVISION NOTES.:    Edit structure of tool so that code is more legible.
'#============================================================================================
'#	SUBS...........:	ShowProcessItems, SortProcessItems, KillProcess, ExportProcessDetails
'#	...............:	OpenURL, PauseScript, ResetForm, Window_onLoad
'#	FUNCTIONS......:	Reachable, ConvertToDiskSize, EncodeCSV
'#============================================================================================
	
	Const adVarChar = 200 : Const adInteger = 3 : Const MaxCharacters = 255
	
	Dim strPC, intProcessCount
	Dim booProcessNameSort, booPIDSort, booMemUsageSort, booUserSort

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objShell = CreateObject("Wscript.Shell")
	Set DataList = CreateObject("ADOR.Recordset")
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	ShowProcessItems()
    '#	PURPOSE........:	Displays a list of running processes on the PC
    '#	ARGUMENTS......:	
    '#	EXAMPLE........:	
    '#	NOTES..........:	
    '#--------------------------------------------------------------------------
	Sub ShowProcessItems()
		On Error Resume Next

		document.body.style.cursor = "wait"
		PauseScript(0)
		
		Set DataList = CreateObject("ADOR.Recordset")
		
		booProcessNameSort = 1
		booPIDSort = 0
		booMemUsageSort = 1
		booUserSort = 0
		intProcessCount = 0
		
		WMIError.className = "hidden"
		NotFoundArea.className = "hidden"
		DataArea.className = ""
		btnShowProcess.Disabled = True
		btnShowProcess.className = "disabled"
		txtComputerName.Disabled = True
		txtComputerName.className = "text disabled"
		txtComputerName.style.fontweight = "bold"
		txtComputerName.Title = ""
		btnShowProcess.Title = ""
		
		If IsNull(txtComputerName.Value) OR txtComputerName.Value = "" OR txtComputerName.Value = "." Then
			txtComputerName.Value = objShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
		End If
		
		txtComputerName.Value = UCase(txtComputerName.Value)
		strPC = txtComputerName.Value
		
		If NOT Reachable(strPC) Then
			ResetForm()
			NotFoundArea.className = ""
			DataArea.className = "hidden"
			document.body.style.cursor = "default"
			Exit Sub
		End If
		
		DataArea.InnerHTML = "<h3>Fetching Process info for " & strPC & ", please wait.</h3>"
		PauseScript(0)
		
		DataList.Fields.Append "ProcessName", adVarChar, MaxCharacters
		DataList.Fields.Append "PID", adInteger, MaxCharacters
		DataList.Fields.Append "ProcessUser", adVarChar, MaxCharacters
		DataList.Fields.Append "MemUsage", adInteger, MaxCharacters
		DataList.Open
		
		strHTML = "<form name=""processform"" method=""post"">" & _
		"<table class=""processtable"">" & _
			"<tr>" & _
				"<th style=""width:25%;text-align:left;cursor:hand;"" " & _
					"title=""Sort by Process Name"" onClick=SortProcessItems(1)>" & _
					"Process&nbsp;&nbsp;&nbsp;^</th>" & _
				"<th style=""width:10%;cursor:hand;"" " & _
					"title=""Sort by Process ID"" onClick=SortProcessItems(2)>PID</th>" & _
				"<th style=""width:19%;text-align:left;cursor:hand;"" " & _
					"title=""Sort by Username"" onClick=SortProcessItems(3)>User</th>" & _
				"<th style=""width:16%;text-align:left;cursor:hand;"" " & _
					"title=""Sort by Mem Usage"" onClick=SortProcessItems(4)>Mem Usage</th>" & _
				"<th style=""width:11%;"">Process Library</th>" & _
				"<th style=""width:11%;"">Google</th>" & _
				"<th style=""width:8%;"">Kill</th>" & _
			"</tr>"
		
		Err.Clear
		Set objWMIService = GetObject("winmgmts:\\" & strPC & "\root\cimv2")
		
		If Err.Number <> 0 Then
			ResetForm()
			WMIError.className = ""
			DataArea.className = "hidden"
			document.body.style.cursor = "default"
			Exit Sub
		End If

		DataArea.InnerHTML = "<h3>Fetching Process info for " & strPC & ", please wait..</h3>"
		PauseScript(0)
		
		Err.Clear
		
		Set colProcesses = objWMIService.ExecQuery _
			("Select * From Win32_Process")
		
		For Each objItem in colProcesses
			intProcessCount = intProcessCount + 1
			strProcessName = objItem.Caption
			intProcessID = objItem.ProcessID
			intMemUsage = objItem.WorkingSetSize
			If IsNull(intMemUsage) OR intMemUsage = "" Then intMemUsage = 0
			
			colProperties = objItem.GetOwner _
					(strProcessUser,strProcessUserDomain)
			
			DataList.AddNew		
			
			DataList("ProcessName") = strProcessName
			DataList("PID") = intProcessID
			DataList("MemUsage") = intMemUsage
			DataList("ProcessUser") = strProcessUserDomain & "\" & strProcessUser
			
			DataList.Update
		Next
		
		DataArea.InnerHTML = "<h3>Fetching Process info for " & strPC & ", please wait...</h3>"
		PauseScript(0)
		
		DataList.Sort = "ProcessName"
		
		DataList.MoveFirst
		Do Until DataList.EOF
			strProcessName = DataList.Fields.Item("ProcessName")
			intProcessID = DataList.Fields.Item("PID")
			
			strProcessUser = DataList.Fields.Item("ProcessUser")
			If strProcessUser = "\" Then
				strProcessUser = ""
				strProcessUserName = ""
				Else
					arrProcessUser = Split(strProcessUser, "\")
					strProcessUserName = arrProcessUser(1)
			End If
			
			intMemUsage = DataList.Fields.Item("MemUsage")
			If intMemUsage = 0 Then
				strMemUsage = "0 MB" 
				Else
					strMemUsage = ConvertToDiskSize(intMemUsage)
			End If
			
			DataList.MoveNext
			
			strProcessSearch = Replace(strProcessName, " ", "_")
			
			strHTML = strHTML & "<tr>"
			strHTML = strHTML & "<td title=""" & strProcessName & """ style=""word-break:break-all;"">" & strProcessName & "</td>"
			strHTML = strHTML & "<td style=""text-align:center;"">" & intProcessID & "</td>"
			strHTML = strHTML & "<td title=""" & strProcessUser & """>" & strProcessUserName & "</td>" 
			strHTML = strHTML & "<td>" & strMemUsage & "</td>"
			strHTML = strHTML & "<td style=""text-align:center""><span class=""spanlink"" onClick=OpenURL(""http://www.processlibrary.com/search/?q=" & _
				strProcessSearch & """) title=""Search Process Library for '" & strProcessName & "'"">Search" & _
				"</span></td>"
			strHTML = strHTML & "<td style=""text-align:center""><span class=""spanlink"" onClick=OpenURL(""http://www.google.com/search?q=" & _
				strProcessSearch & """) title=""Search Google for '" & strProcessName & "'"">Search" & _
				"</span></td>"
			strHTML = strHTML &	"<th style=""width:8%;background-color:white;""><input type=""checkbox"" value=""" & _
				intProcessID & "||" & strProcessName & """ title=""Select '" & strProcessName & "'""></th>"
			strHTML = strHTML &	"</tr>" 
		Loop
		
		strHTML = strHTML & "</table></form>"
		
		DataArea.InnerHTML = "<h3>Fetching Process info for " & strPC & ", please wait....</h3>"
		PauseScript(0)

		DataArea.InnerHTML = strHTML

		BottomBar.className = ""
		NumItemsSpan.InnerHTML = intProcessCount & " items"
		
		document.body.style.cursor = "default"
	End Sub
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	SortProcessItems(intSort)
    '#	PURPOSE........:	Sorts the list of running processes
    '#	ARGUMENTS......:	intSort = index of row to sort
    '#	EXAMPLE........:	SortProcessItems(3)
    '#	NOTES..........:	The above example would sort the Mem Usage row
    '#--------------------------------------------------------------------------
	Sub SortProcessItems(intSort)
		On Error Resume Next
		
		document.body.style.cursor = "wait"
		PauseScript(0)

		Select Case intSort
			Case 1
				booPIDSort = 0
				booMemUsageSort = 1
				booUserSort = 0
				
				If booProcessNameSort = 0 Then
					booProcessNameSort = 1
					strSortHTML = "Process&nbsp;&nbsp;&nbsp;^"
					DataList.Sort = "ProcessName ASC"
					Else
						booProcessNameSort = 0
						strSortHTML = "Process&nbsp;&nbsp;&nbsp;<span style=""font-size:0.6em"">v</span>"
						DataList.Sort = "ProcessName DESC"
				End If

				strHTML = "<form name=""processform"" method=""post"">" & _
				"<table class=""processtable"">" & _
					"<tr>" & _
						"<th style=""width:25%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Process Name"" onClick=SortProcessItems(1)>" & _
							strSortHTML & "</th>" & _
						"<th style=""width:10%;cursor:hand;"" " & _
							"title=""Sort by Process ID"" onClick=SortProcessItems(2)>PID</th>" & _
						"<th style=""width:19%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Username"" onClick=SortProcessItems(3)>User</th>" & _
						"<th style=""width:16%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Mem Usage"" onClick=SortProcessItems(4)>Mem Usage</th>" & _
						"<th style=""width:11%;"">Process Library</th>" & _
						"<th style=""width:11%;"">Google</th>" & _
						"<th style=""width:8%;"">Kill</th>" & _
					"</tr>"
			Case 2
				booProcessNameSort = 0
				booMemUsageSort = 1
				booUserSort = 0
				
				If booPIDSort = 0 Then
					booPIDSort = 1
					strSortHTML = "PID&nbsp;&nbsp;&nbsp;^"
					DataList.Sort = "PID ASC"
					Else
						booPIDSort = 0
						strSortHTML = "PID&nbsp;&nbsp;&nbsp;<span style=""font-size:0.6em"">v</span>"
						DataList.Sort = "PID DESC"
				End If
				
				strHTML = "<form name=""processform"" method=""post"">" & _
				"<table class=""processtable"">" & _
					"<tr>" & _
						"<th style=""width:25%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Process Name"" onClick=SortProcessItems(1)>Process</th>" & _
						"<th style=""width:10%;cursor:hand;"" " & _
							"title=""Sort by Process ID"" onClick=SortProcessItems(2)>" & _
							strSortHTML & "</th>" & _
						"<th style=""width:19%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Username"" onClick=SortProcessItems(3)>User</th>" & _
						"<th style=""width:16%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Mem Usage"" onClick=SortProcessItems(4)>Mem Usage</th>" & _
						"<th style=""width:11%;"">Process Library</th>" & _
						"<th style=""width:11%;"">Google</th>" & _
						"<th style=""width:8%;"">Kill</th>" & _
					"</tr>"
			Case 3
				booProcessNameSort = 0
				booPIDSort = 0
				booMemUsageSort = 1
				
				If booUserSort = 0 Then
					booUserSort = 1
					strSortHTML = "User&nbsp;&nbsp;&nbsp;^"
					DataList.Sort = "ProcessUser ASC"
					Else
						booUserSort = 0
						strSortHTML = "User&nbsp;&nbsp;&nbsp;<span style=""font-size:0.6em"">v</span>"
						DataList.Sort = "ProcessUser DESC"
				End If
				
				strHTML = "<form name=""processform"" method=""post"">" & _
				"<table class=""processtable"">" & _
					"<tr>" & _
						"<th style=""width:25%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Process Name"" onClick=SortProcessItems(1)>Process</th>" & _
						"<th style=""width:10%;cursor:hand;"" " & _
							"title=""Sort by Process ID"" onClick=SortProcessItems(2)>PID</th>" & _
						"<th style=""width:19%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Username"" onClick=SortProcessItems(3)>" & _
							strSortHTML & "</th>" & _
						"<th style=""width:16%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Mem Usage"" onClick=SortProcessItems(4)>Mem Usage</th>" & _
						"<th style=""width:11%;"">Process Library</th>" & _
						"<th style=""width:11%;"">Google</th>" & _
						"<th style=""width:8%;"">Kill</th>" & _
					"</tr>"
			Case 4
				booProcessNameSort = 0
				booPIDSort = 0
				booUserSort = 0
				
				If booMemUsageSort = 0 Then
					booMemUsageSort = 1
					strSortHTML = "Mem Usage&nbsp;&nbsp;&nbsp;^"
					DataList.Sort = "MemUsage ASC"
					Else
						booMemUsageSort = 0
						strSortHTML = "Mem Usage&nbsp;&nbsp;&nbsp;<span style=""font-size:0.6em"">v</span>"
						DataList.Sort = "MemUsage DESC"
				End If
				
				strHTML = "<form name=""processform"" method=""post"">" & _
				"<table class=""processtable"">" & _
					"<tr>" & _
						"<th style=""width:25%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Process Name"" onClick=SortProcessItems(1)>Process</th>" & _
						"<th style=""width:10%;cursor:hand;"" " & _
							"title=""Sort by Process ID"" onClick=SortProcessItems(2)>PID</th>" & _
						"<th style=""width:19%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Username"" onClick=SortProcessItems(3)>User</th>" & _
						"<th style=""width:16%;text-align:left;cursor:hand;"" " & _
							"title=""Sort by Mem Usage"" onClick=SortProcessItems(4)>" & _
							strSortHTML & "</th>" & _
						"<th style=""width:11%;"">Process Library</th>" & _
						"<th style=""width:11%;"">Google</th>" & _
						"<th style=""width:8%;"">Kill</th>" & _
					"</tr>"
		End Select
		
		DataList.MoveFirst
		Do Until DataList.EOF
			strProcessName = DataList.Fields.Item("ProcessName")
			intProcessID = DataList.Fields.Item("PID")
			
			strProcessUser = DataList.Fields.Item("ProcessUser")
			If strProcessUser = "\" Then
				strProcessUser = ""
				strProcessUserName = ""
				Else
					arrProcessUser = Split(strProcessUser, "\")
					strProcessUserName = arrProcessUser(1)
			End If
			
			intMemUsage = DataList.Fields.Item("MemUsage")
			If intMemUsage = 0 Then
				strMemUsage = "0 MB" 
				Else
					strMemUsage = ConvertToDiskSize(intMemUsage)
			End If
			
			DataList.MoveNext
			
			strProcessSearch = Replace(strProcessName, " ", "_")
			
			strHTML = strHTML & "<tr>"
			strHTML = strHTML & "<td title=""" & strProcessName & """>" & strProcessName & "</td>"
			strHTML = strHTML & "<td style=""text-align:center;"">" & intProcessID & "</td>"
			strHTML = strHTML & "<td title=""" & strProcessUser & """>" & strProcessUserName & "</td>" 
			strHTML = strHTML & "<td>" & strMemUsage & "</td>"
			strHTML = strHTML & "<td style=""text-align:center""><span class=""spanlink"" onClick=OpenURL(""http://www.processlibrary.com/search/?q=" & _
				strProcessSearch & """) title=""Search Process Library for '" & strProcessName & "'"">Search" & _
				"</span></td>"
			strHTML = strHTML & "<td style=""text-align:center""><span class=""spanlink"" onClick=OpenURL(""http://www.google.com/search?q=" & _
				strProcessSearch & """) title=""Search Google for '" & strProcessName & "'"">Search" & _
				"</span></td>"
			strHTML = strHTML &	"<th style=""width:8%;background-color:white;""><input type=""checkbox"" value=""" & _
				intProcessID & "||" & strProcessName & """ title=""Select '" & strProcessName & "'""></th>"
			strHTML = strHTML &	"</tr>" 
		Loop
		
		strHTML = strHTML & "</table></form>"

		DataArea.InnerHTML = strHTML
		
		document.body.style.cursor = "default"
	End Sub
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	KillProcess()
    '#	PURPOSE........:	Kill selected process(es)
    '#	ARGUMENTS......:	
    '#	EXAMPLE........:	
    '#	NOTES..........:	
    '#--------------------------------------------------------------------------
	Sub KillProcess()
		On Error Resume Next
		
		booChecked = False
		
		Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _
		strPC & "\root\cimv2") 
		
		strInput = document.processform.checkbox
		For Each strInput in processform
			If strInput.Checked = True Then
				booChecked = True
				arrValues = Split(strInput.Value, "||")
				strProcessName = arrValues(1)
				
				strMsg = strMsg & vbCrLf & strProcessName
			End If
		Next
		
		If booChecked = False Then
			MsgBox "You did not select any processes to kill!   ", vbExclamation, "Error"
			Exit Sub
		End If
		
		KillProcPrompt = MsgBox("Are you sure you wish to kill the following process(es) on " & _
		strPC & ": " & vbCrLf & strMsg, vbQuestion+vbYesNo, "Process Audit")
		
		If KillProcPrompt = vbYes Then
			For Each strInput in processform
				If strInput.Checked = True Then
					arrValues = Split(strInput.Value, "||")
					intProcessID = arrValues(0)
					strProcessName = arrValues(1)
					
					Set colProcesses = objWMIService.ExecQuery _
						("Select * from Win32_Process Where ProcessID = '" & intProcessID & "'")
						
					For Each objItem in colProcesses
						objItem.Terminate()
						strMsg2 = strMsg2 & vbCrLf & strProcessName
					Next
				End If
			Next
						
			MsgBox "You killed the following process(es) on " & strPC & ": " & vbCrLf & strMsg2, vbInformation,"Process Audit" 
			ShowProcessItems()
			Else
				For Each strInput in processform
					strInput.Checked = False
				Next
		End If
	End Sub
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	ExportProcessDetails()
    '#	PURPOSE........:	Export the details for the Process Items
    '#	ARGUMENTS......:	
    '#	EXAMPLE........:	
    '#	NOTES..........:	
    '#--------------------------------------------------------------------------
	Sub ExportProcessDetails()
		On Error Resume Next
		
		document.body.style.cursor = "wait"
		PauseScript(0)

		strTemp = objShell.ExpandEnvironmentStrings("%TEMP%")
		
		Select Case ExportSelect.Value
			Case 1
				Set objFile = objFSO.CreateTextFile(strTemp & "\ProcessDetails" & strPC & ".csv",True)
				objFile.WriteLine "Process Items on " & strPC
				objFile.WriteLine ""
				objFile.WriteLine "Total: " & intProcessCount & " Applications"
				objFile.WriteLine ""
				objFile.WriteLine "Process Name,Process ID,Username,Mem Usage (KB)"
			Case 2
				Const xlContinuous = 1
				Const xlThin = 2
				Const xlAutomatic = -4105
				
				strExcelPath = objShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe\")
			   
				If strExcelPath = "" Then
					MsgBox "Unable to export. Excel does not appear to be installed.", vbExclamation, "Error"
					ExportSelect.Value = 0
					document.body.style.cursor = "default"
					Exit Sub
				End If
				
				Set objExcel = CreateObject("Excel.Application")
				objExcel.Visible = False
				Set objWorkBook = objExcel.WorkBooks.Add
				Set objWorksheet = objWorkbook.Worksheets(1)
				objExcel.DisplayAlerts = False
				For i = 1 to 3
					objWorkbook.Worksheets(2).Delete
				Next
				objExcel.DisplayAlerts = True
				objWorksheet.Name = "Process Details"
				
				objWorkSheet.Cells(1, 1) = "Process Items on " & strPC
				objWorkSheet.Cells(3, 1) = "Total: " & intProcessCount & " Applications"

				intStartRow = 6
				
				objWorkSheet.Cells(5, 1) = "Process Name"
				objWorkSheet.Cells(5, 2) = "Process ID"
				objWorkSheet.Cells(5, 3) = "Username"
				objWorkSheet.Cells(5, 4) = "Mem Usage (KB)"
			Case 3
				Set objFile = objFSO.CreateTextFile(strTemp & "\ProcessDetails" & strPC & ".htm",True)
				objFile.WriteLine "<style type=""text/css"">"
				objFile.WriteLine "body{background-color:#CEF0FF;}"
				objFile.WriteLine "table.export{border-width:1px;border-spacing:1px;border-style:solid;border-color:gray;border-collapse:collapse;}"
				objFile.WriteLine "table.export th{border-width:1px;padding:1px;border-style:solid;border-color:gray;padding:2px 7px 2px 7px;}"
				objFile.WriteLine "table.export td{border-width:1px;padding:1px;border-style:dotted;border-color:gray;padding:2px 7px 2px 7px;}"
				objFile.WriteLine ".backtotop a {font-size:0.9em;}"
				objFile.WriteLine "</style>"
				objFile.WriteLine "<div style=""font-weight:bold;""><a name =""top"">Process Items on " & strPC & "</a><p>"
				objFile.WriteLine "Total: " & intProcessCount & " Applications<p></div>"
				objFile.WriteLine "<table class=""export"">"
				objFile.WriteLine "	<tr>"
				objFile.WriteLine "		<th style=""text-align:left;"">"
				objFile.WriteLine "			Process Name"
				objFile.WriteLine "		</th>"
				objFile.WriteLine "		<th>"
				objFile.WriteLine "			Process ID"
				objFile.WriteLine "		</th>"
				objFile.WriteLine "		<th>"
				objFile.WriteLine "			Username"
				objFile.WriteLine "		</th>"
				objFile.WriteLine "		<th>"
				objFile.WriteLine "			Mem Usage"
				objFile.WriteLine "		</th>"
				objFile.WriteLine "		<th>"
				objFile.WriteLine "			Process Library"
				objFile.WriteLine "		</th>"
				objFile.WriteLine "		<th>"
				objFile.WriteLine "			Google"
				objFile.WriteLine "		</th>"
				objFile.WriteLine "	</tr>"
		End Select
		
		DataList.Sort = "ProcessName"
		
		DataList.MoveFirst
		Do Until DataList.EOF
			strProcessName = DataList.Fields.Item("ProcessName")
			intProcessID = DataList.Fields.Item("PID")
			
			strProcessUser = DataList.Fields.Item("ProcessUser")
			If strProcessUser = "\" Then strProcessUser = ""
			
			intMemUsage = DataList.Fields.Item("MemUsage")
			If intMemUsage = 0 Then
				strMemUsage = "0 MB" 
				Else
					strMemUsage = ConvertToDiskSize(intMemUsage)
					intMemUsage = Round(intMemUsage / 1024,2)
			End If
			
			DataList.MoveNext
			
			Select Case ExportSelect.Value
				Case 1
					strProcessName = EncodeCsv(strProcessName)
					strProcessUser = EncodeCsv(strProcessUser)
					
					strCSV = strCSV & strProcessName & "," & _
					intProcessID & "," & strProcessUser & "," & _
					intMemUsage & vbCrLf
				Case 2
					objWorkSheet.Cells(intStartRow, 1) = strProcessName
					objWorkSheet.Cells(intStartRow, 2) = intProcessID
					objWorkSheet.Cells(intStartRow, 3) = strProcessUser
					objWorkSheet.Cells(intStartRow, 4) = intMemUsage
					intStartRow = intStartRow + 1
				Case 3
					objFile.WriteLine "	<tr>"
					objFile.WriteLine "		<td>"
					objFile.WriteLine "			" & strProcessName
					objFile.WriteLine "		</td>"
					objFile.WriteLine "		<td>"
					objFile.WriteLine "			" & intProcessID
					objFile.WriteLine "		</td>"
					objFile.WriteLine "		<td>"
					objFile.WriteLine "			" & strProcessUser
					objFile.WriteLine "		</td>"
					objFile.WriteLine "		<td>"
					objFile.WriteLine "			" & strMemUsage
					objFile.WriteLine "		</td>"
					objFile.WriteLine "		<td>"
					objFile.WriteLine "		 	<a target=_blank href=""http://www.processlibrary.com/search/?q=" & _
						strProcessName & """ title=""Search Process Library for " & _
						strProcessName & """>Search</a>"
					objFile.WriteLine "		</td>"
					objFile.WriteLine "		<td>"
					objFile.WriteLine "		 	<a target=_blank href=""http://www.google.com/search?q=" & _
						strProcessName & """ title=""Search Google for " & _
						strProcessName & """>Search</a>"
					objFile.WriteLine "		</td>"
					objFile.WriteLine "	</tr>"
			End Select
		Loop		

		Select Case ExportSelect.Value
			Case 1
				objFile.WriteLine strCSV
				objFile.Close
				Set objFile = Nothing
				objShell.Run strTemp & "\ProcessDetails" & strPC & ".csv"
			Case 2
				Set objRange = objWorkSheet.Range("A1:Z5")
				Set objRangeH = objWorkSheet.Range("A5:D5")
				Set objRange2 = objWorkSheet.Range("A5:D" & intStartRow - 1)
				Set objRange3 = objWorksheet.Range("D:D")
				
				objRange.Font.Bold = True
				objRangeH.AutoFilter
				
				objRange2.Borders.LineStyle = xlContinuous
				objRange2.Borders.Weight = xlThin
				objRange2.Borders.ColorIndex = xlAutomatic
				objRange3.NumberFormat = "#,##0"
				
				objWorksheet.Range("A6").Select
				objExcel.ActiveWindow.FreezePanes = "True"
				objWorksheet.Range("A1").Select
				
				objWorkSheet.Columns("A:ZZ").EntireColumn.AutoFit
				objExcel.DisplayAlerts = False
				objExcel.ActiveWorkbook.SaveAs(strTemp & "\ProcessDetails" & strPC & ".xls")
				objExcel.Visible = True
				Set objExcel = Nothing
			Case 3
				strHTMLTempDir = Replace(LCase(strTemp), "c:", "file:///c:")
				strHTMLTempDir = Replace(strHTMLTempDir, "\", "/")
				
				objFile.WriteLine "</table>"
				objFile.WriteLine "<p class=""backtotop""><a href=""" & strHTMLTempDir & "/ProcessDetails" & _
				strPC & ".htm#top"">[..back to top..]</a></p>"
				objFile.Close
				Set objFile = Nothing
				objShell.Run strTemp & "\ProcessDetails" & strPC & ".htm"
			End Select
		
		ExportSelect.Value = 0
		
		document.body.style.cursor = "default"
	End Sub
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	OpenURL(strURL)
    '#	PURPOSE........:	Opens the supplied URL in default browser
    '#	ARGUMENTS......:	strURL = URL
    '#	EXAMPLE........:	OpenURL("http://www.google.com"
    '#	NOTES..........:	Any spaces in URL must be encoded as underscores ( _ )
    '#--------------------------------------------------------------------------	
	Sub OpenURL(strURL)
		strURL = Replace(strURL, "_", " ")
		objShell.Run(Chr(34) & strURL & Chr(34))
	End Sub
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	PauseScript(intPause)
    '#	PURPOSE........:	Pauses the script
    '#	ARGUMENTS......:	intPause = number of milliseconds to pause
    '#	EXAMPLE........:	PauseScript(1000)
    '#	NOTES..........:	Above example will pause script for 1 second
    '#--------------------------------------------------------------------------
	Sub PauseScript(intPause)
		objShell.Run "%COMSPEC% /c ping -w " & intPause & " -n 1 1.0.0.0", 0, True
	End Sub
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	ResetForm()
    '#	PURPOSE........:	Reset the form
    '#	ARGUMENTS......:		
    '#	EXAMPLE........:	
    '#	NOTES..........:	
    '#--------------------------------------------------------------------------
	Sub ResetForm()
		strPC = ""
		txtComputerName.Value = ""
		txtComputerName.Disabled = False
		btnShowProcess.Disabled = False
		txtComputerName.className = "text"
		btnShowProcess.className = "button"
		txtComputerName.Title = "Computer Name"
		btnShowProcess.Title = "Show process list"
		
		BottomBar.className = "hidden"
		DataArea.InnerHTML = ""
		NumItemsSpan.InnerHTML = ""
		txtComputerName.Focus()
	End Sub

	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	Window_onLoad()
    '#	PURPOSE........:	Sets Window size
    '#	ARGUMENTS......:	
    '#	EXAMPLE........:	
    '#	NOTES..........:	
    '#--------------------------------------------------------------------------	
	Sub Window_onLoad
		self.ResizeTo 850,780
		VersionSpan.InnerHTML = objProcessAudit.Version
	End Sub

	'#--------------------------------------------------------------------------
	'#  FUNCTION.......:	Reachable(strPC)
	'#  PURPOSE........:	Checks whether the remote PC is online
	'#  ARGUMENTS......:	strPC = PC on which to perform action
	'#  EXAMPLE........:	Reachable(PC1)
	'#  NOTES..........:  
	'#--------------------------------------------------------------------------
	Function Reachable(strPC)
		Set objWMIService2 = GetObject("winmgmts:\\.\root\cimv2")
		Set colPing = objWMIService2.ExecQuery _
			("Select * from Win32_PingStatus Where Address = '" & strPC & "'")
		For Each objItem in colPing
			If IsNull(objItem.StatusCode) Or objItem.Statuscode <> 0 Then
				Reachable = False
				Else
					Reachable = True
			End If
		Next
	End Function
	
	'#--------------------------------------------------------------------------
	'#  FUNCTION.......:	ConvertToDiskSize(intValue)
	'#  PURPOSE........:	Gets disk size string (eg. 1 MB)
	'#  ARGUMENTS......:	intValue = number of bytes to convert
	'#  EXAMPLE........:	ConvertToDiskSize(1024)
	'#  NOTES..........:  
	'#--------------------------------------------------------------------------
	Function ConvertToDiskSize(intValue)
		If (intValue / 1099511627776) > 1 Then
			ConvertToDiskSize = Round(intValue / 1099511627776,1) & " TB " 
			ElseIf (intValue / 1073741824) > 1 Then
				ConvertToDiskSize = Round(intValue / 1073741824,1) & " GB " 
				ElseIf (intValue / 1048576) > 1 Then
					ConvertToDiskSize = Round(intValue / 1048576,2) & " MB " 
					ElseIf (intValue / 1024) > 1 Then
						ConvertToDiskSize = Round(intValue / 1024,2) & " KB " 
						Else
							ConvertToDiskSize = Round(intValue) & " Bytes " 
		End If
	End Function
	
	'#--------------------------------------------------------------------------
    '#	SUBROUTINE.....:	EncodeCsv(strText)
    '#	PURPOSE........:	Encode provided text for CSV export
    '#	ARGUMENTS......:	strText = text to encode
    '#	EXAMPLE........:	EncodeCsv("Some text, etc.")
    '#	NOTES..........:	
    '#--------------------------------------------------------------------------
	Function EncodeCsv(strText)
		strText = Replace(strText, Chr(34), "")
		strText = Replace(strText, vbCrLf, " ")
		strText = Chr(34) & strText & Chr(34)
		EncodeCsv = strText
	End Function