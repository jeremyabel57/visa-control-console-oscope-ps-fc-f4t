#include-once

#include <ProgressConstants.au3>
#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <GuiScrollBars.au3>
#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>

#include "general.au3"
#include "webview2.au3"
#include "visascpi.au3"
#include "mso_config_file.au3"
#include "windowresize.au3"


Global $g_aMenuList[1][2]            ; list of menu item handles and visa script files to execute



;-----------   title bar button functions


; title bar button overlay
#forcedef $hMainGUI
Func titlebarOverlayInit($hMGUI = $hMainGUI)
	Local $iButtonCount = 4                ; number of buttons on this titlebar overlay

	; Create the overlapping Child GUI to house the Title Bar Button
	; $WS_POPUP removes borders, and setting $hMainGUI as the parent ensures it minimizes/closes together
	Local $scopeButtonScale = 25
	Local $scopeButtonSpace = 5
	Global $titleButtonsOffset = 160 + $iButtonCount * $scopeButtonScale  ; offset from right side of window
	Global $hBtnGUI = GUICreate("", $iButtonCount * $scopeButtonScale + ($iButtonCount - 1) * $scopeButtonSpace, $scopeButtonScale, 0, 0, $WS_POPUP, $WS_EX_MDICHILD, $hMGUI)

	Local $iBtn = 0

	Global $hCfgBtn = GUICtrlCreateButton($ICON_CFG, ($scopeButtonScale + $scopeButtonSpace) * $iBtn, 0, _
			$scopeButtonScale, $scopeButtonScale, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $BS_BOTTOM))
	GUICtrlSetFont(-1, 11)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Select Scope IP Address")

	$iBtn += 1
	Global $hRefreshBtn = GUICtrlCreateButton($ICON_REFRESH, ($scopeButtonScale + $scopeButtonSpace) * $iBtn, 0, _
			$scopeButtonScale, $scopeButtonScale, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $BS_VCENTER))
	GUICtrlSetFont(-1, 16, 600)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Reload scope webpage interface")

	$iBtn += 1
	Global $hScreenShotBtn = GUICtrlCreateButton($ICON_SCREENSHOT, ($scopeButtonScale + $scopeButtonSpace) * $iBtn, 0, _
			$scopeButtonScale, $scopeButtonScale, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $BS_VCENTER))
	GUICtrlSetFont(-1, 16)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Take a screenshot of the scope")

	$iBtn += 1
	Global $hMenuBtn = GUICtrlCreateButton($ICON_MENU1, ($scopeButtonScale + $scopeButtonSpace) * $iBtn, 0, _
			$scopeButtonScale, $scopeButtonScale, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $BS_VCENTER))
	GUICtrlSetFont(-1, 16)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Menu")

	Local $hMenu = GUICtrlCreateContextMenu($hMenuBtn)        ; create context menu and tie it to the menu button
	SetUpMenu($hMenu)

EndFunc   ;==>titlebarOverlayInit



Func SetUpMenu($hMenu)
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFile = _PathMake($sDrive, $sDir, $sFileName & "_menu", ".txt")         ; script menu file

	Local $aLines = FileReadToArray($sFile)                                        ; read script menu file into array
	Local $aItem
	ReDim $g_aMenuList[UBound($aLines)][2]                                         ; set the global array size
	For $i = 0 To UBound($aLines) - 1
		$aItem = StringSplit($aLines[$i], ",", 0)
		If $aItem[0] < 2 Then ContinueLoop
		$g_aMenuList[$i][0] = GUICtrlCreateMenuItem($aItem[1], $hMenu)             ; menu item name
		$g_aMenuList[$i][1] = $aItem[2]                                            ; menu item associated visa script file
		ConsoleWrite("$g_aMenuList[" & $i & "][0]=" & $aItem[1] & @CRLF & _
				"$g_aMenuList[" & $i & "][1]=" & $aItem[2] & @CRLF)
	Next
EndFunc   ;==>SetUpMenu



; Helper function to snap the overlay GUI exactly over the top frame
Func PositionTitleBarButtons($hMain, $hBtn)
	Local $aPos = WinGetPos($hMain)
	;_ArrayDisplay($aPos)
	If IsArray($aPos) Then
		; Adjust these offsets to reposition the button horizontally or vertically
		Local $iXoverlay = $aPos[0] + $aPos[2] - $titleButtonsOffset             ; Positions it to the left of the Min/Max/Close buttons
		Local $iYoverlay = $aPos[1] + 5                                          ; Drops it perfectly inside the vertical title bar bounds
		WinMove($hBtn, "", $iXoverlay, $iYoverlay)
		; 4. SWP_FRAMECHANGED forces Windows to recalculate the window's display space
		; across multi-monitor DPI boundaries instantly, preventing the "invisible until moved" bug.
		Local $SWP_FLAGS = BitOR(0x0001, 0x0002, 0x0020) ; SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED
		_WinAPI_SetWindowPos($hBtn, 0, 0, 0, 0, 0, $SWP_FLAGS)
	EndIf
EndFunc   ;==>PositionTitleBarButtons




;--------   gui button events


Func scopeRefreshClick()
	#forcedef $hMainGUI
	scopeNavigate()
	;_WebView2_Reload($g_aWebView2)
	WinActivate($hMainGUI)
EndFunc   ;==>scopeRefreshClick



Func scopeCfgClick()
	#forcedef $g_ipAddr, $g_ipAddrList, $hMainGUI
	Local $ipAddr = $g_ipAddr
	Local $ipAddrList = $g_ipAddrList
	Local $n = __viSelectDevice($ipAddr, $ipAddrList, $hMainGUI, "Oscilloscope")
	If $n <> "" Then
		$g_ipAddr = $n
		$g_ipAddrList = $ipAddrList
		scopeNavigate()
		ConfigWrite()
	EndIf
EndFunc   ;==>scopeCfgClick



Func scopeNavigate()
	#forcedef $g_ipAddr, $scopeIPvalid, $hMainGUI, $g_aWebView2
	;MsgBox(0, "navigate", $scopeIP)
	scopeGetID()
	WinSetTitle($hMainGUI, "", "Oscilloscope Tektronix MSO5 at " & $g_ipAddr & ($scopeIPvalid ? "" : "  (Not Found)"))
	_WebView2_Navigate($g_aWebView2, "about:blank")                               ; flush out the old URL
	Sleep(200)
	Local $aIP = __viParseIPaddress($g_ipAddr)          ; strip port number from address
	_WebView2_Navigate($g_aWebView2, "http://" & $aIP[0] & "/Tektronix/")        ; navigate to the scope web control
	Sleep(200)
	WM_WINDOWPOSCHANGED($hMainGUI, 0, 0, 0)                                      ; for some reason the webview2 window is being reset to a small size, this fixes it
EndFunc   ;==>scopeNavigate



