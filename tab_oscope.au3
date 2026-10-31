#include-once





Global $g_aMenuList[1][2], $aVars
Global $g_sc_hIpAddr, $g_sc_hScreenFile, $g_sc_cScriptMenuBtn

Global $g_sc_iReadTimer, $g_sc_iRefreshInterval = 450
Global $g_sc_oDev, $g_sc_bCommValid = False


#include "webview2tab.au3" ; web view - browse web page inside gui

#include "winmgmt.au3"
#include "myconstants.au3"
#include "tableEdit.au3"
#include "visascpi.au3"
#include "misc.au3"



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; initialization functions



Global $g_sc_iTabIdx

; called during the Tab control section of main gui window setup
Func scTab_TabGuiCreate($iTabIdx, $oCanvas)
	$g_sc_iTabIdx = $iTabIdx

	Local $iBtnScale = 20                                                           ; size of each button
	Local $iBtnSpace = 5                                                            ; space between buttons
	Local $iRight = 5                                                               ; right margin from edge of window
	Local $iTop = 2                                                                 ; top margin from top of window

	Local $aBtns = [ _
			[$ICON_SEARCH, 16, 600, "Scan Network", "scTab_ScanNetwork"], _
			[$ICON_BOOK, 16, -1, "Variables", "scTab_OnVarsBtn"], _
			[$ICON_NET, 16, 600, "Oscilloscope IP Address", "scTab_OnCfgBtn"], _
			[$ICON_REFRESH, 16, 600, "Reload scope webpage interface", "scTab_OnRefreshBtn"], _
			[$ICON_SCREENSHOT, 16, -1, "Take a screenshot of the scope", "scTab_OnScreenShotBtn"], _
			[$ICON_MENU1, 16, -1, "Script Menu", "scTab_OnScriptMenuBtn"] _
			]

	Local $iW = __IsDictionary($oCanvas) ? $oCanvas.Item('iW') : 600
	Local $i, $n = UBound($aBtns) - 1, $c, $s
	Local $aCtrls[$n + 2]       ; making room for IpAddr field
	For $i = 0 To $n
		$c = GUICtrlCreateButton($aBtns[$i][0], $iW - $iBtnScale - $iRight - ($iBtnScale + $iBtnSpace) * ($n - $i), $iTop, _
				$iBtnScale, $iBtnScale, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $BS_VCENTER, $SS_CENTERIMAGE))
		$aCtrls[$i] = GUICtrlGetHandle($c)
		GUICtrlSetFont(-1, $aBtns[$i][1], $aBtns[$i][2])
		GUICtrlSetResizing(-1, BitOR($GUI_DOCKTOP, $GUI_DOCKRIGHT, $GUI_DOCKSIZE, $GUI_DOCKHEIGHT))
		$s = $aBtns[$i][3]
		If StringLeft($s, 6) = "Script" Then $g_sc_cScriptMenuBtn = $c
		GUICtrlSetTip(-1, $s)
		GUICtrlSetOnEvent(-1, $aBtns[$i][4])
	Next

	Local $hTbo_Menu = GUICtrlCreateContextMenu($g_sc_cScriptMenuBtn)                               ; create context menu and tie it to the menu button
	scTab_SetUpMenu($hTbo_Menu)

	Local $icW = 150
	Local $iX = $iW - $iRight - ($iBtnScale + $iBtnSpace) * ($n + 1) - $icW
	$g_sc_hIpAddr = GUICtrlCreateCombo("|192.168.0.14", $iX, $iTop, $icW, 17)                       ; place to store ip address
	$aCtrls[$n + 1] = $g_sc_hIpAddr
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKTOP, $GUI_DOCKRIGHT, $GUI_DOCKSIZE, $GUI_DOCKHEIGHT))
	GUICtrlSetOnEvent(-1, "scTab_OnRefreshBtn")

	$g_sc_hScreenFile = GUICtrlCreateEdit(@ScriptDir & "\MSO5_Screenshot.png", 5, 5, 100, 20)       ; place to store screen shot file name in gui
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetState(-1, $GUI_HIDE)

	$oCanvas.Item('aCtrls') = $aCtrls                                                                   ; set aZoomControls for later processing
EndFunc   ;==>scTab_TabGuiCreate



Func scTab_SetUpMenu($hMenu)
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFile = _PathMake($sDrive, $sDir, $sFileName & "_menu", ".txt")          ; script menu file

	Local $aLines = FileReadToArray($sFile)                                         ; read script menu file into array
	Local $n = UBound($aLines)
	Local $aItem
	ReDim $g_aMenuList[$n][2]                                                       ; set the global array size
	$n -= 1
	For $i = 0 To $n
		$aItem = StringSplit($aLines[$i], ",", 0)
		If $aItem[0] < 2 Then ContinueLoop
		$g_aMenuList[$i][0] = GUICtrlCreateMenuItem($aItem[1], $hMenu)              ; menu item name
		$g_aMenuList[$i][1] = $aItem[2]                                             ; menu item associated visa script file
		GUICtrlSetOnEvent($g_aMenuList[$i][0], "scTab_OnScriptMenu")
	Next
EndFunc   ;==>scTab_SetUpMenu



Func scTab_CanvasGuiCreate($iTabIdx, $oCanvas, $hCanvas)
	Local $iW = 960
	Local $iH = 540
	$oCanvas.Item('iMinW') = $iW
	$oCanvas.Item('iMinH') = $iH
	$oCanvas.Item('iW') = $iW
	$oCanvas.Item('iH') = $iH
	__WebView2_CanvasGuiCreate($iTabIdx, $oCanvas, $hCanvas)
	Local $a[] = [$iW, $iH]
	Return $a
EndFunc   ;==>scTab_CanvasGuiCreate



Func scTab_init()
	Local $oCanvas = $g_aCanvas[$g_sc_iTabIdx]
	;$oCanvas.Item('iMinW') = 1920
	;$oCanvas.Item('iMinH') = 1080

	LoopRegister("scTab_Loop")                                                                              ; register our loop function
	$g_sc_iReadTimer = TimerInit()

	$g_sc_oDev = scTab_GetIP()
EndFunc   ;==>scTab_init



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; main loop function

Func scTab_Loop()                                           ; main loop function
	If TimerDiff($g_sc_iReadTimer) < $g_sc_iRefreshInterval Then Return
	$g_sc_iReadTimer = TimerInit()

	Local $vRet = __tableEditReturn()                       ; check table edit dialog for input
	If IsArray($vRet) Then
		$aVars = $vRet
		Vars_ConfigWrite()
		Vars_Assert()
	EndIf

	Local $sIpAddr = __viSelectDeviceReturn()               ; check select device dialog for input
	If $sIpAddr <> "" And Not StringIsInt($sIpAddr) Then
		GUICtrlSetData($g_sc_hIpAddr, $__viSD_sResultListRef, $sIpAddr)
		scTab_Navigate()
		scTab_ConfigWrite()
	EndIf

EndFunc   ;==>scTab_Loop





;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; gui event handler functions




Func scTab_ScanNetwork()
	__viScanSubnet()
	;__viScanSubnet("192.168.0.0", $g_sc_hIpAddr, "Oscilloscope")
EndFunc   ;==>scTab_ScanNetwork


Func scTab_OnScriptMenuBtn()
	ControlClick($g_hMainGui, "", $g_sc_cScriptMenuBtn, "secondary")
EndFunc   ;==>scTab_OnScriptMenuBtn


Func scTab_OnScreenShotBtn()
	Local $sLocalFilePath = GUICtrlRead($g_sc_hScreenFile)
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($sLocalFilePath, $sDrive, $sDir, $sFileName, $sExtension)
	$sLocalFilePath = FileSaveDialog("Save Scope Shot", $sDrive & $sDir, "(*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $g_hMainGui)
	If $sLocalFilePath = "" Then Return
	GUICtrlSetData($g_sc_hScreenFile, $sLocalFilePath)

	Local $sCmds = _
			'FILESystem:DELEte "C:/Temp2_Scope.png"' & @CRLF & _
			'FILESystem:DELEte "C:/Temp_Scope.png"' & @CRLF & _
			'SAVE:IMAGe "C:/Temp_Scope.png"' & @CRLF & _
			'do' & @CRLF & _
			'  *CLS' & @CRLF & _
			'  sleep 500' & @CRLF & _
			'  FILESystem:REName "C:/Temp_Scope.png","C:/Temp2_Scope.png"' & @CRLF & _
			'  $oscopeESR=*ESR?' & @CRLF & _
			'until {BitAND($oscopeESR,0x10) = 0}' & @CRLF & _
			'##FILESystem:READFile "C:/Temp2_Scope.png"' & @CRLF & _
			'FILESystem:DELEte "C:/Temp2_Scope.png"' & @CRLF & _
			'FILESystem:DELEte "C:/Temp_Scope.png"'

	if not $g_sc_bCommValid then $g_sc_oDev = scTab_GetIP()
	__viScript($g_sc_oDev, $sCmds, $sLocalFilePath, 5000)
	$sLocalFilePath = __viFlush($g_sc_oDev)
	If Not @error Then MsgBox($MB_ICONINFORMATION, "Success", "Screenshot successfully saved to: " & @CRLF & $sLocalFilePath)
	GUICtrlSetData($g_sc_hScreenFile, $sLocalFilePath)
	scTab_ConfigWrite()
EndFunc   ;==>scTab_OnScreenShotBtn


Func scTab_OnRefreshBtn()
	scTab_Navigate()
	WinActivate($g_hMainGui)
EndFunc   ;==>scTab_OnRefreshBtn


Func scTab_OnVarsBtn()
	Local $aHeader = ["Var", "Value"]
	Local $aHw = [100, 180]
	__tableEdit($aVars, $aHeader, $aHw, "ManTestStation", "Variables")
EndFunc   ;==>scTab_OnVarsBtn


Func scTab_OnCfgBtn()
	Local $ipAddr = scTab_GetIP()
	__viSelectDevice($ipAddr, $g_hMainGui, "sc")
EndFunc   ;==>scTab_OnCfgBtn


Func scTab_OnScriptMenu()
	if not $g_sc_bCommValid then $g_sc_oDev = scTab_GetIP()
	Local $i, $iClickedID = @GUI_CtrlId                             ; @GUI_CtrlId contains the explicit Control ID of the menu option clicked
	Local $n = UBound($g_aMenuList) - 1
	For $i = 0 To $n
		If $iClickedID = $g_aMenuList[$i][0] Then
			__viScriptFile($g_sc_oDev, $g_aMenuList[$i][1])         ; Trigger the visa script execution using the file path matching this item row
			ExitLoop
		EndIf
	Next
EndFunc   ;==>scTab_OnScriptMenu





;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; gui functions





Func scTab_GetIP()
	Return __viGUIGetIP($g_sc_hIpAddr)
EndFunc   ;==>scTab_GetIP


Func scTab_GetID()
	$g_sc_oDev = scTab_GetIP()

	__viGUIGetIDbg("", $g_sc_hIpAddr, $g_sc_oDev, "g_sc_bCommValid")

	;Local $s = __viGetID($g_sc_oDev)
	;;ConsoleWrite("scTab_GetID()=" & $s & @CRLF)
	;$g_sc_bCommValid = Not ($s = "")
	;Return $s
EndFunc   ;==>scTab_GetID


Func scTab_Navigate()
	;if $g_sc_iTabIdx < 0 then return
	scTab_GetID()
	Local $aIP = __viParseIPaddress(scTab_GetIP())                 ; strip port number from address
	Local $oCanvas = $g_aCanvas[$g_sc_iTabIdx]
	__WebView2navigate($oCanvas.Item('aWebView'), "http://" & $aIP[0] & "/Tektronix/")
EndFunc   ;==>scTab_Navigate







;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; config functions


Global $scTab_ConfigSection = "Oscillocope"                                                                    ; oscope config section



Func scTab_ConfigWrite()
	__viSaveIP($g_sc_hIpAddr, $scTab_ConfigSection)
	IniWrite($g_configFile, $scTab_ConfigSection, "screenShot", GUICtrlRead($g_sc_hScreenFile))            ; file name of the screenshot file
EndFunc   ;==>scTab_ConfigWrite



Func scTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	__viLoadIP($g_sc_hIpAddr, $scTab_ConfigSection)
	GUICtrlSetData($g_sc_hScreenFile, IniRead($g_configFile, $scTab_ConfigSection, "screenShot", GUICtrlRead($g_sc_hScreenFile)))   ; file name of the screenshot file

	scTab_Navigate()
EndFunc   ;==>scTab_ConfigRead



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;
