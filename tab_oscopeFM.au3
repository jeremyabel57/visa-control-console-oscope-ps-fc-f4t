#include-once

#include <GuiEdit.au3>
#include <GuiListBox.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>

#include "misc.au3"
#include "datatypes.au3"
#include "filemisc.au3"
#include "visascpi.au3"
#include "winmgmt.au3"

; Global tracker components mapping to Python configuration settings
Global $g_ofm_iTabIdx
Global $g_ofm_hIpAddr, $g_ofm_hDevID, $g_ofm_oDev
Global $g_ofm_bCommValid = False
Global $g_ofm_iRefreshTimer, $g_ofm_iRefreshInterval = 450

; GUI Control references
Global $g_ofm_hPathEntry, $g_ofm_hGoBtn, $g_ofm_hListBox
Global $g_ofm_hDownloadBtn, $g_ofm_hUploadBtn, $g_ofm_hStatusBar

; Active internal caching parameters
Global $g_ofm_sCurrentPath = ""
Global $g_ofm_sLastFolder = ""
Global $g_ofm_sResultListRef = ""
Global $g_ofm_ConfigSection = "Oscilloscope_FM"

; ==============================================================================
; Initialization & Main Run Loops
; ==============================================================================

Func sfTab_init()
    LoopRegister("sfTab_Loop")
    $g_ofm_iRefreshTimer = TimerInit()
    $g_ofm_oDev = sfTab_GetIP()
EndFunc   ;==>sfTab_init

Func sfTab_Loop()
    If TimerDiff($g_ofm_iRefreshTimer) < $g_ofm_iRefreshInterval Then Return
    $g_ofm_iRefreshTimer = TimerInit()

    ; Only update properties if the file manager tab is explicitly active
    If GUICtrlRead($g_cTab) <> $g_ofm_iTabIdx Then Return

    ; Intercept non-blocking layout returns from asynchronous dialog requests
    ;Local $sIpAddr = __viSelectDeviceReturn()
    ;If $sIpAddr <> "" And Not StringIsInt($sIpAddr) Then
    ;    GUICtrlSetData($g_ofm_hIpAddr, $__viSD_sResultListRef, $sIpAddr)
    ;    sfTab_IpAddrChange()
    ;EndIf
EndFunc   ;==>sfTab_Loop



; ==============================================================================
; Graphical Layout Creation Window
; ==============================================================================

Func sfTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
    $g_ofm_iTabIdx = $iTabIdx

    Local $x = 10
    Local $y = 5
    Local $iW = __IsDictionary($oCanvas) ? $oCanvas.Item('iW') : 780

    ; --- Network Connection Area Container ---
    GUICtrlCreateLabel("Scope IP Address:", $x, $y + 3, 95, 17)
    GUICtrlSetResizing(-1, $GUI_DOCKALL)
    $g_ofm_hIpAddr = GUICtrlCreateCombo("", $x + 100, $y, 140, 22)
    GUICtrlSetData($g_ofm_hIpAddr, "|192.168.0.14", "192.168.0.14")
    GUICtrlSetResizing(-1, $GUI_DOCKALL)
    GUICtrlSetOnEvent(-1, "sfTab_IpAddrChange")

    GUICtrlCreateButton($ICON_NET, $x + 245, $y - 3, 25, 25)
    GUICtrlSetResizing(-1, $GUI_DOCKALL)
    GUICtrlSetTip(-1, "Select Active Instrument Address")
    GUICtrlSetFont(-1, 14, 600)
    GUICtrlSetOnEvent(-1, "sfTab_OnCfgBtn")

    GUICtrlCreateButton($ICON_SEARCH, $x + 275, $y - 3, 25, 25)
    GUICtrlSetResizing(-1, $GUI_DOCKALL)
    GUICtrlSetTip(-1, "Scan Network Subnet")
    GUICtrlSetFont(-1, 14, 600)
    GUICtrlSetOnEvent(-1, "sfTab_ScanNetwork")

    $g_ofm_hDevID = GUICtrlCreateButton("Connect", $x + 310, $y - 3, 90, 25)
    GUICtrlSetResizing(-1, $GUI_DOCKALL)
    GUICtrlSetOnEvent(-1, "sfTab_ToggleConnection")
    $y += 35

    ; --- Scope File Browser Components ---
    GUICtrlCreateLabel("Current Path:", $x, $y + 3, 75, 17)
    GUICtrlSetResizing(-1, $GUI_DOCKALL)
    $g_ofm_hPathEntry = GUICtrlCreateInput("", $x + 80, $y, $iW - 210, 20)
    GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKTOP, $GUI_DOCKRIGHT, $GUI_DOCKHEIGHT))
    GUICtrlSetState(-1, $GUI_DISABLE)

    $g_ofm_hGoBtn = GUICtrlCreateButton("Go/Refresh", $iW - 120, $y - 2, 90, 22)
    GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKSIZE))
    GUICtrlSetState(-1, $GUI_DISABLE)
    GUICtrlSetOnEvent(-1, "sfTab_RefreshDirectory")
    $y += 25

    ; --- Data Layout Browser Control Container ---
    $g_ofm_hListBox = GUICtrlCreateList("", $x, $y, $iW - 40, 360, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY, $LBS_HASSTRINGS))
    GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKTOP, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM))
    GUICtrlSetFont(-1, 10, 400, 0, "Courier New")
    GUICtrlSetOnEvent(-1, "sfTab_OnItemDoubleClick")
    $y += 370

    ; --- Interactive Transfer Tasks buttons ---
    $g_ofm_hDownloadBtn = GUICtrlCreateButton("?? Download Selected", $x, $y, 220, 30)
    GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
    GUICtrlSetState(-1, $GUI_DISABLE)
    GUICtrlSetOnEvent(-1, "sfTab_DownloadAction")

    $g_ofm_hUploadBtn = GUICtrlCreateButton("?? Upload File Here", $x + 240, $y, 220, 30)
    GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
    GUICtrlSetState(-1, $GUI_DISABLE)
    GUICtrlSetOnEvent(-1, "sfTab_UploadAction")
    $y += 40

    ; --- Low Level Status Notification Bar Layout ---
    $g_ofm_hStatusBar = GUICtrlCreateLabel("Status: Disconnected", $x, $y, $iW - 40, 20, BitOR($SS_SIMPLE, $SS_SUNKEN))
    GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKHEIGHT))
    $y += 25

    Local $a[] = [$iW, $y]
    Return $a
EndFunc   ;==>sfTab_GuiCreate


; ==============================================================================
; Core Instrumentation Logic Tasks
; ==============================================================================

Func sfTab_GetIP()
    Return __viGUIGetIP($g_ofm_hIpAddr)
EndFunc   ;==>sfTab_GetIP

Func sfTab_ToggleConnection()
    If Not $g_ofm_bCommValid Then
        GUICtrlSetData($g_ofm_hStatusBar, "Connecting...")
        $g_ofm_oDev = sfTab_GetIP()

        ; Query target instrument ID dynamically without locking the main thread context
        Local $sId = __viGetID($g_ofm_oDev)
        If $sId = "" Then
            GUICtrlSetData($g_ofm_hStatusBar, "Status: Network Connection Error!")
            MsgBox($MB_ICONERROR, "Connection Error", "Could not connect to target Scope via " & $g_ofm_oDev)
            Return
        EndIf

        $g_ofm_bCommValid = True
        GUICtrlSetData($g_ofm_hStatusBar, "Connected to: " & $sId)
        GUICtrlSetData($g_ofm_hDevID, "Disconnect")
        GUICtrlSetState($g_ofm_hIpAddr, $GUI_DISABLE)

        ; Enable interactive browser controls
        GUICtrlSetState($g_ofm_hPathEntry, $GUI_ENABLE)
        GUICtrlSetState($g_ofm_hGoBtn, $GUI_ENABLE)
        GUICtrlSetState($g_ofm_hDownloadBtn, $GUI_ENABLE)
        GUICtrlSetState($g_ofm_hUploadBtn, $GUI_ENABLE)

        ; Jump back to your historical tracking directory path if valid
        If $g_ofm_sLastFolder <> "" Then
            __viReqBl($g_ofm_oDev, 'FILESystem:CWD "' & $g_ofm_sLastFolder & '"', False)
        EndIf

        sfTab_RefreshDirectory()
    Else
        sfTab_Disconnect()
    EndIf
EndFunc   ;==>sfTab_ToggleConnection

Func sfTab_Disconnect()
    $g_ofm_bCommValid = False
    GUICtrlSetData($g_ofm_hDevID, "Connect")
    GUICtrlSetState($g_ofm_hIpAddr, $GUI_ENABLE)

    ; Clear active visual layout strings
    GUICtrlSetData($g_ofm_hPathEntry, "")
    _GUICtrlListBox_ResetContent($g_ofm_hListBox)

    ; Disable controls
    GUICtrlSetState($g_ofm_hPathEntry, $GUI_DISABLE)
    GUICtrlSetState($g_ofm_hGoBtn, $GUI_DISABLE)
    GUICtrlSetState($g_ofm_hDownloadBtn, $GUI_DISABLE)
    GUICtrlSetState($g_ofm_hUploadBtn, $GUI_DISABLE)
    GUICtrlSetData($g_ofm_hStatusBar, "Status: Disconnected")
EndFunc   ;==>sfTab_Disconnect

Func sfTab_RefreshDirectory()
    If Not $g_ofm_bCommValid Then Return

    GUICtrlSetData($g_ofm_hStatusBar, "Reading remote directory path...")

    ; Query current working directory bounds
    Local $sCWD = __viReqBl($g_ofm_oDev, "FILESystem:CWD?")
    $sCWD = StringStripWS(StringReplace($sCWD, '"', ""), 3)
    $g_ofm_sCurrentPath = $sCWD
    GUICtrlSetData($g_ofm_hPathEntry, $sCWD)

    ; Query and parse raw comma-separated tracking lists
    Local $sRawDir = __viReqBl($g_ofm_oDev, "FILESystem:DIR?")
    _GUICtrlListBox_ResetContent($g_ofm_hListBox)
    _GUICtrlListBox_AddString($g_ofm_hListBox, "[ .. (Go Up Directory) ]")

    Local $aItems = StringSplit($sRawDir, ",", 1)
    Local $sCleanItem = ""
    For $i = 1 To $aItems[0]
        $sCleanItem = StringStripWS(StringReplace($aItems[$i], '"', ""), 3)
        If $sCleanItem = "" Then ContinueLoop

        ; Emulate folder type classifications based on suffix markers
        If StringRight($sCleanItem, 1) = "/" Or StringRight($sCleanItem, 1) = "\" Or StringInStr($sCleanItem, ":") Then
            _GUICtrlListBox_AddString($g_ofm_hListBox, "?? " & $sCleanItem)
        Else
            _GUICtrlListBox_AddString($g_ofm_hListBox, "?? " & $sCleanItem)
        EndIf
    Next

    GUICtrlSetData($g_ofm_hStatusBar, "Directory updated successfully.")
    $g_ofm_sLastFolder = $g_ofm_sCurrentPath
    sfTab_ConfigWrite()
EndFunc   ;==>sfTab_RefreshDirectory

; ==============================================================================
; Interactive GUI Navigation Events
; ==============================================================================

Func sfTab_OnItemDoubleClick()
    If Not $g_ofm_bCommValid Then Return
    Local $iIdx = _GUICtrlListBox_GetCurSel($g_ofm_hListBox)
    If $iIdx = $LB_ERR Then Return

    Local $sText = _GUICtrlListBox_GetText($g_ofm_hListBox, $iIdx)

    ; Trigger parent navigation deconstruction loop
    If StringInStr($sText, "[ .. ") Then
        Local $sDrive, $sDir, $sName, $sExt
        _PathSplit($g_ofm_sCurrentPath, $sDrive, $sDir, $sName, $sExt)
        Local $sParent = _PathFull($sDrive & $sDir & "..\")
        __viReqBl($g_ofm_oDev, 'FILESystem:CWD "' & $sParent & '"', False)
        sfTab_RefreshDirectory()
        Return
    EndIf

    Local $sCleanItem = StringReplace(StringReplace($sText, "?? ", ""), "?? ", "")
    $sCleanItem = StringStripWS($sCleanItem, 3)

    ; Evaluate file selection routing
    If StringInStr($sCleanItem, ":") And (StringRight($sCleanItem, 1) = "/" Or StringRight($sCleanItem, 1) = "\") Then
        __viReqBl($g_ofm_oDev, 'FILESystem:CWD "' & $sCleanItem & '"', False)
        sfTab_RefreshDirectory()
    ElseIf StringRight($sCleanItem, 1) = "/" Or StringRight($sCleanItem, 1) = "\" Then
        Local $sSep = (StringRight($g_ofm_sCurrentPath, 1) <> "/" And StringRight($g_ofm_sCurrentPath, 1) <> "\") ? "/" : ""
        __viReqBl($g_ofm_oDev, 'FILESystem:CWD "' & $g_ofm_sCurrentPath & $sSep & $sCleanItem & '"', False)
        sfTab_RefreshDirectory()
    Else
        ; Trigger immediate download mapping if user clicks down onto a direct package asset
        sfTab_DownloadAction()
    EndIf
EndFunc   ;==>sfTab_OnItemDoubleClick

Func sfTab_DownloadAction()
    Local $iIdx = _GUICtrlListBox_GetCurSel($g_ofm_hListBox)
    If $iIdx = $LB_ERR Then Return
    Local $sText = _GUICtrlListBox_GetText($g_ofm_hListBox, $iIdx)
    If StringInStr($sText, "[ ..") Then Return

    Local $sFilename = StringReplace(StringReplace($sText, "?? ", ""), "?? ", "")
    $sFilename = StringStripWS($sFilename, 3)

    Local $sLocalDest = FileSaveDialog("Save downloaded scope file to PC", @ScriptDir, "All Files (*.*)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFilename, $g_hMainGui)
    If $sLocalDest = "" Then Return

    GUICtrlSetData($g_ofm_hStatusBar, "Downloading " & $sFilename & "...")

    ; Run binary block file download operations safely
    __viDownloadFile($g_ofm_oDev, $sLocalDest, 'FILESystem:READFile "' & $sFilename & '"', 15000)
    Local $sResult = __viFlush($g_ofm_oDev)

    If FileExists($sLocalDest) Then
        GUICtrlSetData($g_ofm_hStatusBar, "Download completed successfully!")
        MsgBox($MB_ICONINFORMATION, "Success", "'" & $sFilename & "' downloaded successfully!")
    Else
        GUICtrlSetData($g_ofm_hStatusBar, "Download failed.")
        MsgBox($MB_ICONERROR, "Transfer Error", "Failed to download asset file path context from scope layer.")
    EndIf
    sfTab_RefreshDirectory()
EndFunc   ;==>sfTab_DownloadAction

Func sfTab_UploadAction()
    Local $sLocalSrc = FileOpenDialog("Select file from PC to upload", @ScriptDir, "All Files (*.*)", BitOR($FD_FILEMUSTEXIST, $FD_PATHMUSTEXIST), "", $g_hMainGui)
    If $sLocalSrc = "" Then Return

    Local $sDrive, $sDir, $sFilename, $sExt
    _PathSplit($sLocalSrc, $sDrive, $sDir, $sFilename, $sExt)
    Local $sTargetName = $sFilename & $sExt

    GUICtrlSetData($g_ofm_hStatusBar, "Uploading " & $sTargetName & " to scope...")

    ; Run definite-length binary block payload processing
    __viUploadFile($g_ofm_oDev, $sLocalSrc, 'FILESystem:WRITEFile "' & $sTargetName & '",', 15000)
    __viFlush($g_ofm_oDev)

    GUICtrlSetData($g_ofm_hStatusBar, "Upload operation query sent.")
    MsgBox($MB_ICONINFORMATION, "Success", "'" & $sTargetName & "' uploaded successfully!")
    sfTab_RefreshDirectory()
EndFunc   ;==>sfTab_UploadAction

; ==============================================================================
; Utility Layout Support Triggers
; ==============================================================================

Func sfTab_IpAddrChange()
    sfTab_Disconnect()
    sfTab_ToggleConnection()
EndFunc   ;==>sfTab_IpAddrChange

Func sfTab_OnCfgBtn()
    Local $ipAddr = sfTab_GetIP()
    __viSelectDevice($ipAddr, $g_hMainGui, "sc")
EndFunc   ;==>sfTab_OnCfgBtn

Func sfTab_ScanNetwork()
    __viScanSubnet()
EndFunc   ;==>sfTab_ScanNetwork

; ==============================================================================
; Persisted Configuration Profiles Handling
; ==============================================================================

Func sfTab_ConfigWrite()
    __viSaveIP($g_ofm_hIpAddr, $g_ofm_ConfigSection)
    IniWrite($g_configFile, $g_ofm_ConfigSection, "LastFolder", $g_ofm_sLastFolder)
EndFunc   ;==>sfTab_ConfigWrite

Func sfTab_ConfigRead()
    If $g_configFile = "" Then Return
    If Not FileExists($g_configFile) Then Return
    __viLoadIP($g_ofm_hIpAddr, $g_ofm_ConfigSection)
    $g_ofm_sLastFolder = IniRead($g_configFile, $g_ofm_ConfigSection, "LastFolder", "")
EndFunc   ;==>sfTab_ConfigRead
