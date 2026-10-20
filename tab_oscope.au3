#include-once

#cs

todo:

  check on the button overlays, they got put over the top of the webview canvas.
  are they a child of the tab or the hMainGui?
  did some resize limit move them to within the viewport?
#ce







Global $g_aMenuList[1][2], $aVars
Global $g_oscope_hIpAddr, $g_oscope_hScreenFile, $g_oscope_cScriptMenuBtn

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



Global $g_oscope_iTabIdx

; called during the Tab control section of main gui window setup
Func oscopeTab_TabGuiCreate($iTabIdx, $oCanvas)
	$g_oscope_iTabIdx = $iTabIdx

	Local $iBtnScale = 20                                                           ; size of each button
	Local $iBtnSpace = 5                                                            ; space between buttons
	Local $iRight = 5                                                               ; right margin from edge of window
	Local $iTop = 2                                                                 ; top margin from top of window

	Local $aBtns = [ _
			[$ICON_MENU1, 16, -1, "Script Menu", "oscopeTab_OnScriptMenuBtn"], _
			[$ICON_SCREENSHOT, 16, -1, "Take a screenshot of the scope", "oscopeTab_OnScreenShotBtn"], _
			[$ICON_REFRESH, 16, 600, "Reload scope webpage interface", "oscopeTab_OnRefreshBtn"], _
			[$ICON_NET, 16, 600, "Oscilloscope IP Address", "oscopeTab_OnCfgBtn"], _
			[$ICON_BOOK, 16, -1, "Variables", "oscopeTab_OnVarsBtn"] _
			]

	Local $iW = __IsDictionary($oCanvas) ? $oCanvas.Item('iW') : 600
	Local $i, $iN = UBound($aBtns) - 1, $c
	Local $aCtrls[$iN + 1]
	For $i = 0 To $iN
		$c = GUICtrlCreateButton($aBtns[$i][0], $iW - $iBtnScale - $iRight - ($iBtnScale + $iBtnSpace) * $i, $iTop, _
				$iBtnScale, $iBtnScale, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $BS_VCENTER))
		GUICtrlSetFont(-1, $aBtns[$i][1], $aBtns[$i][2])
		GUICtrlSetResizing(-1, BitOR($GUI_DOCKTOP, $GUI_DOCKRIGHT, $GUI_DOCKSIZE, $GUI_DOCKHEIGHT))
		GUICtrlSetTip(-1, $aBtns[$i][3])
		GUICtrlSetOnEvent(-1, $aBtns[$i][4])
		$aCtrls[$i] = GUICtrlGetHandle($c)
		If $i = 0 Then $g_oscope_cScriptMenuBtn = $c
	Next

	Local $hTbo_Menu = GUICtrlCreateContextMenu($g_oscope_cScriptMenuBtn)           ; create context menu and tie it to the menu button
	oscopeTab_SetUpMenu($hTbo_Menu)

	$g_oscope_hIpAddr = GUICtrlCreateCombo("|abc", 5, 5, 100, 22)                   ; hidden place to store ip address
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetState(-1, $GUI_HIDE)
	GUICtrlSetData($g_oscope_hIpAddr, "|192.168.0.25", "192.168.0.25")
	$g_oscope_hScreenFile = GUICtrlCreateEdit(@ScriptDir & "\MSO5_Screenshot.png", 5, 5, 100, 20)   ; place to store screen shot file name in gui
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetState(-1, $GUI_HIDE)

	$oCanvas.Item('aCtrls') = $aCtrls                                        		; set aZoomControls for later processing
EndFunc   ;==>oscopeTab_TabGuiCreate



Func oscopeTab_SetUpMenu($hMenu)
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFile = _PathMake($sDrive, $sDir, $sFileName & "_menu", ".txt")          ; script menu file

	Local $aLines = FileReadToArray($sFile)                                         ; read script menu file into array
	Local $N = UBound($aLines)
	Local $aItem
	ReDim $g_aMenuList[$N][2]                                                       ; set the global array size
	$N -= 1
	For $i = 0 To $N
		$aItem = StringSplit($aLines[$i], ",", 0)
		If $aItem[0] < 2 Then ContinueLoop
		$g_aMenuList[$i][0] = GUICtrlCreateMenuItem($aItem[1], $hMenu)              ; menu item name
		$g_aMenuList[$i][1] = $aItem[2]                                             ; menu item associated visa script file
		GUICtrlSetOnEvent($g_aMenuList[$i][0], "oscopeTab_OnScriptMenu")
	Next
EndFunc   ;==>oscopeTab_SetUpMenu



Func oscopeTab_CanvasGuiCreate($iTabIdx, $oCanvas, $hCanvas)
	Local $iW = 960
	Local $iH = 540
	$oCanvas.Item('iMinW') = $iW
	$oCanvas.Item('iMinH') = $iH
	$oCanvas.Item('iW') = $iW
	$oCanvas.Item('iH') = $iH
	__WebView2_CanvasGuiCreate($iTabIdx, $oCanvas, $hCanvas)
	Local $a[] = [ $iW, $iH ]
	return $a
EndFunc   ;==>oscopeTab_CanvasGuiCreate



Func oscopeTab_init()
	Local $oCanvas = $g_aCanvas[$g_oscope_iTabIdx]
	;$oCanvas.Item('iMinW') = 1920
	;$oCanvas.Item('iMinH') = 1080

	LoopRegister("oscopeTab_Loop")                                                                              ; register our loop function
EndFunc   ;==>oscopeTab_init



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; main loop function

Func oscopeTab_Loop()                                       ; main loop function
	Local $vRet = __tableEditReturn()                       ; check table edit dialog for input
	If IsArray($vRet) Then
		$aVars = $vRet
		Vars_ConfigWrite()
		Vars_Assert()
	EndIf

	Local $sIpAddr = __viSelectDeviceReturn()               ; check select device dialog for input
	If $sIpAddr <> "" And Not StringIsInt($sIpAddr) Then
		GUICtrlSetData($g_oscope_hIpAddr, "|" & $sIpAddr, $sIpAddr)
		oscopeTab_Navigate()
		oscopeTab_ConfigWrite()
	EndIf

EndFunc   ;==>oscopeTab_Loop





;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; gui event handler functions




Func oscopeTab_OnScriptMenuBtn()
	ControlClick($g_hMainGui, "", $g_oscope_cScriptMenuBtn, "secondary")
EndFunc   ;==>oscopeTab_OnScriptMenuBtn


Func oscopeTab_OnScreenShotBtn()
	Local $sLocalFilePath = GUICtrlRead($g_oscope_hScreenFile)
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($sLocalFilePath, $sDrive, $sDir, $sFileName, $sExtension)
	$sLocalFilePath = FileSaveDialog("Save Scope Shot", $sDrive & $sDir, "(*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $g_hMainGui)
	If $sLocalFilePath = "" Then Return
	GUICtrlSetData($g_oscope_hScreenFile, $sLocalFilePath)

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

	Local $viDev = oscopeTab_GetIP()
	__viScript($viDev, $sCmds, $sLocalFilePath, 15000)
	$sLocalFilePath = __viFlush($viDev)
	If Not @error Then MsgBox($MB_ICONINFORMATION, "Success", "Screenshot successfully saved to: " & @CRLF & $sLocalFilePath)
	GUICtrlSetData($g_oscope_hScreenFile, $sLocalFilePath)
	oscopeTab_ConfigWrite()
EndFunc   ;==>oscopeTab_OnScreenShotBtn


Func oscopeTab_OnRefreshBtn()
	oscopeTab_Navigate()
	WinActivate($g_hMainGui)
EndFunc   ;==>oscopeTab_OnRefreshBtn


Func oscopeTab_OnVarsBtn()
	Local $aHeader = ["Var", "Value"]
	Local $aHw = [100, 180]
	__tableEdit($aVars, $aHeader, $aHw, "ManTestStation", "Variables")
EndFunc   ;==>oscopeTab_OnVarsBtn


Func oscopeTab_OnCfgBtn()
	Local $ipAddr = oscopeTab_GetIP()
	__viSelectDevice($ipAddr, $g_hMainGui, "Oscilloscope")
EndFunc   ;==>oscopeTab_OnCfgBtn


Func oscopeTab_OnScriptMenu()
	Local $i, $iClickedID = @GUI_CtrlId                                 ; @GUI_CtrlId contains the explicit Control ID of the menu option clicked
	Local $N = UBound($g_aMenuList) - 1
	For $i = 0 To $N
		If $iClickedID = $g_aMenuList[$i][0] Then
			__viScriptFile(oscopeTab_GetIP(), $g_aMenuList[$i][1])      ; Trigger the visa script execution using the file path matching this item row
			ExitLoop
		EndIf
	Next
EndFunc   ;==>oscopeTab_OnScriptMenu





;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; gui functions





Func oscopeTab_GetIP()
	Return __viGetIP($g_oscope_hIpAddr)
EndFunc   ;==>oscopeTab_GetIP


Func oscopeTab_GetID()
	Local $s = __viGetID(oscopeTab_GetIP())
	;ConsoleWrite("oscopeTab_GetID()=" & $s & @CRLF)
	Return $s
EndFunc   ;==>oscopeTab_GetID


Func oscopeTab_Navigate()
	;if $g_oscope_iTabIdx < 0 then return
	oscopeTab_GetID()
	Local $aIP = __viParseIPaddress(oscopeTab_GetIP())                 ; strip port number from address
	Local $oCanvas = $g_aCanvas[$g_oscope_iTabIdx]
	__WebView2navigate($oCanvas.Item('aWebView'), "http://" & $aIP[0] & "/Tektronix/")
EndFunc   ;==>oscopeTab_Navigate







;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; config functions


Global $oscopeTab_ConfigSection = "Oscillocope"                                                                    ; oscope config section



Func oscopeTab_ConfigWrite()
	__viSaveIP($g_oscope_hIpAddr, $oscopeTab_ConfigSection)
	IniWrite($g_configFile, $oscopeTab_ConfigSection, "screenShot", GUICtrlRead($g_oscope_hScreenFile))            ; file name of the screenshot file
EndFunc   ;==>oscopeTab_ConfigWrite



Func oscopeTab_ConfigRead()
	__viLoadIP($g_oscope_hIpAddr, $oscopeTab_ConfigSection)
	GUICtrlSetData($g_oscope_hScreenFile, IniRead($g_configFile, $oscopeTab_ConfigSection, "screenShot", GUICtrlRead($g_oscope_hScreenFile)))   ; file name of the screenshot file

	oscopeTab_Navigate()
EndFunc   ;==>oscopeTab_ConfigRead



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;
