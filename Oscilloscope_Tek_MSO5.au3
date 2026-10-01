; todo
;
; test additional vi script functions
;   read to file command in vi script - can be used for scope shots and other file transfers
;   file upload function to visascpi
;   write from file command to visa target as a command in vi script
;
; add a generic 2D array gui editor.  use edit boxes for each cell
;   make it resizable
;   use a generic font size or some size variable to recalculate the size of each edit box and font
;   if the matrix does not fit within the resizable window, then use an offset x, y coordinates and only show enough edit boxes to fit in window
;
; add a tab menu button on the title bar to switch between oscope view and other tabs
; - control dashboard with power supply, chamber, and frequency counter - including showing current status
; - profile page with input fields for IPN, SN, and other information as well as temperature ranges and test item names (clocks/i2c busses/...)
;
; add a small status section to the title bar
; - chamber temperature (if available)
; - power supply on/off
; - test profile name (I2C, SPI, SMBus...)
; - current test item name
;










; Oscilloscope Tektronix MSO5 remote control and screenshot capture
;
;


#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Icon=mso_oscope.ico

;#AutoIt3Wrapper_Change2CUI=y
;#pargma compile(Console, true)

#include "general.au3" ; general stuff

; globals
Global $g_screenShotFile = @ScriptDir & "\MSO5_Screenshot.png"
Global $g_ipAddr = "192.168.0.14"                        ; IP address of scope
Global $g_ipAddrList = "192.168.0.14|192.168.0.24"        ; list of possible scopes
Global $scopeIPvalid = 0                                ; IP address and/or communications are valid (DC power supply is responding)


#include "mso_config_file.au3" ; config file
#include "visascpi.au3" ; visa functions
#include "mso_titlebarOverlay.au3" ; add buttons To the title bar

Global $g_SaveScreenCmds = [['SAVE:IMAGe "C:/Temp_Scope.png"', $VI_NOWAIT], _
		["*OPC?", 20000], _
		['FILESystem:READFile "C:/Temp_Scope.png"', $VI_NOWAIT]]


ProgressOn("Oscilloscope Remote", "Starting Oscilloscope remote console", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
ProgressSet(0, "Initializing webview...")

#include "webview2.au3" ; web view - browse web page inside gui





; Main window

Global Const $V_WIDTH = 800
Global Const $V_HEIGHT = 600
Global $hMainGUI
$hMainGUI = GUICreate("Oscilloscope Tek MSO5", $V_WIDTH, $V_HEIGHT, -1, -1, _
		BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX))

;GUISetOnEvent($GUI_EVENT_CLOSE, "scopeFormClose")

titlebarOverlayInit($hMainGUI)                           ; initialize the titlebar button overlay

ProgressSet(50)
__webview2gui($hMainGUI, 0, 0, $V_WIDTH, $V_HEIGHT)            ; add the webview element to the gui

;PositionTitleBarButtons($hMainGUI, $hBtnGUI)    ; Position the overlay button precisely onto the native title bar

GUIRegisterMsg($WM_SIZE, "WM_SIZE2")
GUIRegisterMsg($WM_WINDOWPOSCHANGED, "WM_WINDOWPOSCHANGED")
GUIRegisterMsg($WM_MOVE, "WM_MOVE2")

ProgressSet(60, "Loading config...")
ConfigRead()

ProgressSet(75, "Connecting to scope...")
;scopeGetID()
ProgressSet(80)

PositionTitleBarButtons($hMainGUI, $hBtnGUI)

; ------- Display both main window and title bar overlay simultaneously
GUISetState(@SW_SHOW, $hMainGUI)
GUISetState(@SW_SHOW, $hBtnGUI)
WinActivate($hMainGUI)


scopeNavigate()

ProgressSet(100)
ProgressOff()

;_WinAPI_RedrawWindow($hBtnGUI, 0, 0, BitOR($RDW_FRAME, $RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))

; Position the overlay button precisely onto the native title bar
;PositionTitleBarButtons($hMainGUI, $hBtnGUI)
;_WinAPI_RedrawWindow($hBtnGUI, 0, 0, BitOR($RDW_FRAME, $RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))


#forcedef $g_aMenuList
Local $i


While 1
	; 1. Poll the Windows Message Queue
	Local $nMsg = GUIGetMsg()

	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			scopeFormClose()

		Case $hCfgBtn
			scopeCfgClick()

		Case $hRefreshBtn
			scopeRefreshClick()

		Case $hScreenShotBtn
			scopeShot()

		Case $hMenuBtn
			ControlClick($hBtnGUI, "", $hMenuBtn, "secondary")

	EndSwitch

	;Local $ipAddr = $g_ipAddr
	For $i = 0 To UBound($g_aMenuList) - 1
		If $nMsg = $g_aMenuList[$i][0] Then __viScript("" & $g_ipAddr, $g_aMenuList[$i][1])    ; if user clicked option, then launch visa script
	Next

WEnd

Exit



; ---------  AutoIT gui event handlers -----------


Func scopeFormClose()
	;ProgressOn("Oscilloscope Remote", "Closing remote console", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
	;ProgressSet(90, "Saving configuration...")
	ConfigWrite()
	;ProgressSet(80, "Closing webgui...")
	GUIDelete($hMainGUI)
	Sleep(200)
	;ProgressOff()
	Exit
EndFunc   ;==>scopeFormClose



;  VISA functions



Func scopeGetID()
	;Local $ipAddr = $g_ipAddr
	Local $sR = __viGetID("" & $g_ipAddr)
	;msgbox(0,"hi","IP=" & $g_ipAddr & @CRLF & "ID=" & $sR)
	$scopeIPvalid = ($sR = "") ? 0 : 1
	Return $sR
EndFunc   ;==>scopeGetID



; ------------------------------------------------------------
; functions for windows without virtual canvas and scroll bars



Func WM_WINDOWPOSCHANGED($hWnd, $iMsg, $wParam, $lParam)
	WM_MOVE2($hWnd, $iMsg, $wParam, $lParam)
	Return 0
EndFunc   ;==>WM_WINDOWPOSCHANGED

Func WM_MOVE2($hWnd, $iMsg, $wParam, $iParam)
	#forcedef $hMainGUI, $g_aWebView2, $hBtnGUI
	If $hWnd = $hMainGUI Then
		; adjust webview2
		Local $iNewHeight = _WinAPI_GetClientHeight($hWnd)
		Local $iNewWidth = _WinAPI_GetClientWidth($hWnd)
		If $iNewHeight > 50 And $iNewWidth > 50 Then _WebView2_SetBounds($g_aWebView2, 0, 0, $iNewWidth, $iNewHeight)
		; adjust titlebar button overlay
		PositionTitleBarButtons($hMainGUI, $hBtnGUI)
	EndIf
	Return 0
EndFunc   ;==>WM_MOVE2


; Handle Window Resizing (Dynamically adjusts scroll thumb sizes)
Func WM_SIZE2($hWnd, $iMsg, $wParam, $lParam)
	WM_MOVE2($hWnd, $iMsg, $wParam, $lParam)
	Return 0
EndFunc   ;==>WM_SIZE2









; task:		Prompt user for file name
;			Save scope screenshot to given file name
Func scopeShot()
	#forcedef $g_ipAddr, $hMainGUI, $g_screenShotFile

	Local $sLocalFilePath = $g_screenShotFile
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($sLocalFilePath, $sDrive, $sDir, $sFileName, $sExtension)
	$sLocalFilePath = FileSaveDialog("Save Scope Shot", $sDrive & $sDir, "(*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $hMainGUI)
	If $sLocalFilePath = "" Then Return
	$g_screenShotFile = $sLocalFilePath

	Local $aCmds = [['SAVE:IMAGe "C:/Temp_Scope.png"', $VI_NOWAIT], _
			["*OPC?", 20000], _
			['FILESystem:READFile "C:/Temp_Scope.png"', $VI_NOWAIT]]
	;Local $ipAddr = $g_ipAddr
	If __viSaveScreenShot("" & $g_ipAddr, $g_screenShotFile, $aCmds) Then _
			MsgBox($MB_ICONINFORMATION, "Success", "Screenshot successfully saved to: " & @CRLF & $g_screenShotFile)
	ConfigWrite()
EndFunc   ;==>scopeShot



