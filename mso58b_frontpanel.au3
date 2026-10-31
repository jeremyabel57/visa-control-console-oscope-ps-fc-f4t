#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <SendMessage.au3>

; --- Global Variables for Controls & States ---
Global $bIsRunning = False
Global $aChStates[8] = [False, False, False, False, False, False, False, False]

; Tektronix channel color palette: Ch1 (Yellow), Ch2 (Cyan), Ch3 (Pink), Ch4 (Green), etc.
Global $aChColors[8] = [0xFFFF00, 0x00FFFF, 0xFF00FF, 0x00FF00, 0xFF8000, 0x0080FF, 0x8000FF, 0xFFFFFF]
Global $aChButtons[8], $aChLeds[8]
; --- VISA Command Dispatcher ---
Func _viReq($sCommand)
	ConsoleWrite("VISA Tx: " & $sCommand & @CRLF)
EndFunc   ;==>_viReq

; Helper function to shape standard rectangular controls into true circles
Func _MakeControlRound($hWnd)
	Local $aPos = ControlGetPos("", "", $hWnd)
	If Not @error Then
		Local $hRgn = DllCall("gdi32.dll", "handle", "CreateEllipticRgn", "int", 0, "int", 0, "int", $aPos[2], "int", $aPos[3])
		If Not @error And $hRgn[0] Then
			DllCall("user32.dll", "int", "SetWindowRgn", "hwnd", $hWnd, "handle", $hRgn[0], "bool", True)
		EndIf
	EndIf
EndFunc   ;==>_MakeControlRound

; ==============================================================================
; SYSTEM CHASSIS WINDOW SETUP
; ==============================================================================
$hMainGUI = GUICreate("Tektronix MSO58B Front Panel Control Matrix", 1150, 680, -1, -1)
GUISetBkColor(0x1F1F1F)

; --- 15.6" HD Capacitive Touchscreen Window Placeholder ---
GUICtrlCreateLabel("Tektronix MSO58B Touchscreen Interface", 20, 20, 780, 630)
GUICtrlSetBkColor(-1, 0x050505)
GUICtrlSetColor(-1, 0x3A3A3A)
GUICtrlSetFont(-1, 13, 600, 0, "Arial")

; --- TOP SECTION: MULTIPURPOSE NAVIGATION KNOBS & UTILITY KEYS ---
GUICtrlCreateGroup("NAVIGATION & UTILITY", 820, 15, 310, 105)
GUICtrlSetColor(-1, 0x888888)

$btn_KnobA = GUICtrlCreateButton("A", 840, 40, 44, 44)
GUICtrlSetBkColor(-1, 0x333333)
GUICtrlSetColor(-1, 0xFFFFFF)
_MakeControlRound(GUICtrlGetHandle($btn_KnobA))

$btn_KnobB = GUICtrlCreateButton("B", 910, 40, 44, 44)
GUICtrlSetBkColor(-1, 0x333333)
GUICtrlSetColor(-1, 0xFFFFFF)
_MakeControlRound(GUICtrlGetHandle($btn_KnobB))

$btn_Clear = GUICtrlCreateButton("Clear", 980, 35, 65, 28)
$btn_Default = GUICtrlCreateButton("Default Setup", 1050, 35, 75, 28)
$btn_AutoSet = GUICtrlCreateButton("Autoset", 980, 75, 65, 28)
$btn_Screen = GUICtrlCreateButton("Capture", 1050, 75, 75, 28)
GUICtrlCreateGroup("", -1, -1, -1, -1)



; --- SECOND SECTION: HORIZONTAL ACQUISITION ENGINE ---
GUICtrlCreateGroup("HORIZONTAL SYSTEM", 820, 130, 310, 105)
GUICtrlSetColor(-1, 0x00D2FF)

$btn_HorizPos = GUICtrlCreateButton("POS", 840, 165, 40, 40)
GUICtrlSetBkColor(-1, 0x333333)
GUICtrlSetColor(-1, 0x00D2FF)
_MakeControlRound(GUICtrlGetHandle($btn_HorizPos))

$btn_HorizScale = GUICtrlCreateButton("SCALE", 905, 155, 55, 55)
GUICtrlSetBkColor(-1, 0x222222)
GUICtrlSetColor(-1, 0x00D2FF)
_MakeControlRound(GUICtrlGetHandle($btn_HorizScale))

$btn_Zoom = GUICtrlCreateButton("Zoom", 980, 165, 65, 30)
$btn_HorizM = GUICtrlCreateButton("Mode", 1050, 165, 65, 30)
GUICtrlCreateGroup("", -1, -1, -1, -1)

; --- THIRD SECTION: TRIGGERING MATRIX ---
GUICtrlCreateGroup("TRIGGER SYSTEM", 820, 245, 310, 110)
GUICtrlSetColor(-1, 0xFFD200)

$btn_TrigLevel = GUICtrlCreateButton("LVL", 840, 285, 42, 42)
GUICtrlSetBkColor(-1, 0x333333)
GUICtrlSetColor(-1, 0xFFD200)
_MakeControlRound(GUICtrlGetHandle($btn_TrigLevel))

$btn_TrigSlope = GUICtrlCreateButton("Slope", 910, 285, 65, 32)
$btn_TrigMode = GUICtrlCreateButton("Mode", 985, 285, 65, 32)
$btn_ForceTrig = GUICtrlCreateButton("Force", 1060, 285, 60, 32)
GUICtrlCreateGroup("", -1, -1, -1, -1)

; --- FOURTH SECTION: VERTICAL ANALOG SCALING Engine ---
GUICtrlCreateGroup("VERTICAL SYSTEM", 820, 365, 310, 115)
GUICtrlSetColor(-1, 0xFFFFFF)

$btn_VertPos = GUICtrlCreateButton("POS", 840, 400, 40, 40)
GUICtrlSetBkColor(-1, 0x333333)
GUICtrlSetColor(-1, 0xFFFFFF)
_MakeControlRound(GUICtrlGetHandle($btn_VertPos))

$btn_VertScale = GUICtrlCreateButton("SCALE", 905, 390, 55, 55)
GUICtrlSetBkColor(-1, 0x222222)
GUICtrlSetColor(-1, 0xFFFFFF)
_MakeControlRound(GUICtrlGetHandle($btn_VertScale))

$btn_Math = GUICtrlCreateButton("Math", 980, 400, 65, 30)
$btn_Ref = GUICtrlCreateButton("Ref", 1050, 400, 65, 30)
GUICtrlCreateGroup("", -1, -1, -1, -1)


; --- FIFTH SECTION: CH CHASSIS SELECTION MATRIX (With Indicator LEDs) ---
GUICtrlCreateGroup("FLEXCHANNEL SELECT (1 - 8)", 820, 490, 310, 80)
GUICtrlSetColor(-1, 0xCCCCCC)

Local $iXStart = 830
For $i = 0 To 7
	$aChLeds[$i] = GUICtrlCreateLabel("", $iXStart + ($i * 37) + 11, 502, 10, 10)
	GUICtrlSetBkColor(-1, 0x111111)
	_MakeControlRound(GUICtrlGetHandle($aChLeds[$i]))

	$aChButtons[$i] = GUICtrlCreateButton($i + 1, $iXStart + ($i * 37), 520, 32, 32)
	GUICtrlSetBkColor(-1, 0x2D2D2D)
	GUICtrlSetColor(-1, 0xFFFFFF)
	GUICtrlSetFont(-1, 9, 800)
	_MakeControlRound(GUICtrlGetHandle($aChButtons[$i]))
Next
GUICtrlCreateGroup("", -1, -1, -1, -1)

; --- BASE ROW: STATE EXECUTION Engine & HARDWARE STATUS LIGHTS ---
GUICtrlCreateGroup("RUN / STOP CONTROL", 820, 580, 310, 70)
GUICtrlSetColor(-1, 0x00FF00)

$lbl_LedRunState = GUICtrlCreateLabel("", 840, 610, 16, 16)
GUICtrlSetBkColor(-1, 0x550000)
_MakeControlRound(GUICtrlGetHandle($lbl_LedRunState))

$btn_RunStop = GUICtrlCreateButton("RUN / STOP", 870, 602, 120, 34)
GUICtrlSetBkColor(-1, 0x2A2A2A)
GUICtrlSetColor(-1, 0xFFFFFF)

$btn_Single = GUICtrlCreateButton("SINGLE", 1005, 602, 110, 34)
GUICtrlSetBkColor(-1, 0x2A2A2A)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlCreateGroup("", -1, -1, -1, -1)

GUISetState(@SW_SHOW)


; Register the Mouse Wheel Windows Message interceptor
GUIRegisterMsg($WM_MOUSEWHEEL, "WM_MOUSEWHEEL")

Func WM_MOUSEWHEEL($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $lParam
	Local $iDelta = BitShift($wParam, 16)
	Local $sDir = ($iDelta > 0) ? "UP" : "DOWN"
	Local $aMousePos = GUIGetCursorInfo($hMainGUI)
	If @error Then Return $GUI_RUNDEFMSG
	Local $iCtrlId = $aMousePos[4]

	Switch $iCtrlId
		Case $btn_KnobA
			_viReq("DISplay:NAVigation:KNOBA:DIRECTION " & $sDir)
		Case $btn_KnobB
			_viReq("DISplay:NAVigation:KNOBB:DIRECTION " & $sDir)
		Case $btn_HorizPos
			_viReq("HORIZONTAL:POSITION:STEP " & (($sDir == "UP") ? "1" : "-1"))
		Case $btn_HorizScale
			_viReq("HORIZONTAL:SCALE:" & (($sDir == "UP") ? "INCREASE" : "DECREASE"))
		Case $btn_TrigLevel
			_viReq("TRIGGER:A:LEVEL:STEP " & (($sDir == "UP") ? "0.1" : "-0.1"))
		Case $btn_VertPos
			_viReq("VERTICAL:POSITION:STEP " & (($sDir == "UP") ? "0.1" : "-0.1"))
		Case $btn_VertScale
			_viReq("VERTICAL:SCALE:" & (($sDir == "UP") ? "INCREASE" : "DECREASE"))
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_MOUSEWHEEL


; ==============================================================================
; RUNTIME MAIN EVENT LOOP
; ==============================================================================
While 1
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			Exit
		Case $btn_KnobA
			_viReq("DISplay:NAVigation:KNOBA:PUSH")
		Case $btn_KnobB
			_viReq("DISplay:NAVigation:KNOBB:PUSH")
		Case $btn_HorizPos
			_viReq("HORIZONTAL:POSITION:RESET")
		Case $btn_TrigLevel
			_viReq("TRIGGER:A:LEVEL:SETTOTHIFTY")
		Case $btn_VertPos
			_viReq("VERTICAL:POSITION:RESET")
		Case $btn_Clear
			_viReq("CLEAR")
		Case $btn_Default
			_viReq("FACTORY")
		Case $btn_AutoSet
			_viReq("AUTOSET EXECUTE")
		Case $btn_Screen
			_viReq("SAVE:IMAGe 'F:\\screen_capture.png'")
		Case $btn_Zoom
			_viReq("ZOOM:STATE TOGGLE")
		Case $btn_HorizM
			_viReq("HORIZONTAL:MODE TOGGLE")
		Case $btn_TrigSlope
			_viReq("TRIGGER:A:EDGE:SLOPE TOGGLE")
		Case $btn_TrigMode
			_viReq("TRIGGER:A:MODE TOGGLE")
		Case $btn_ForceTrig
			_viReq("TRIGGER FORCE")
		Case $btn_Math
			_viReq("DISPLAY:MATH:STATE TOGGLE")
		Case $btn_Ref
			_viReq("DISPLAY:REF:STATE TOGGLE")
		Case $aChButtons[0] To $aChButtons[7]
			Local $iChIdx = $nMsg - $aChButtons[0]
			$aChStates[$iChIdx] = Not $aChStates[$iChIdx]
			If $aChStates[$iChIdx] Then
				GUICtrlSetBkColor($aChLeds[$iChIdx], $aChColors[$iChIdx])
				_viReq("DISPLAY:GLOBAL:CH" & ($iChIdx + 1) & ":STATE ON")
			Else
				GUICtrlSetBkColor($aChLeds[$iChIdx], 0x111111)
				_viReq("DISPLAY:GLOBAL:CH" & ($iChIdx + 1) & ":STATE OFF")
			EndIf
		Case $btn_RunStop
			$bIsRunning = Not $bIsRunning
			If $bIsRunning Then
				GUICtrlSetBkColor($lbl_LedRunState, 0x00FF00)
				_viReq("ACQUIRE:STATE RUN")
			Else
				GUICtrlSetBkColor($lbl_LedRunState, 0xFF0000)
				_viReq("ACQUIRE:STATE STOP")
			EndIf
		Case $btn_Single
			GUICtrlSetBkColor($lbl_LedRunState, 0xFF8000)
			_viReq("ACQUIRE:STOPAFTER SEQUENCE; ACQUIRE:STATE RUN")
			$bIsRunning = False
	EndSwitch
WEnd

