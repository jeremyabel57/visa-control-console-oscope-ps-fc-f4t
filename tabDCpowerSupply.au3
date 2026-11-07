#include-once



#include "filemisc.au3"
#include "myconstants.au3"
#include "mydebug.au3"
#include "visascpi.au3"
#include "winmgmt.au3"


#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <ButtonConstants.au3>


Global $g_dc_togglePeriod = 2000                    ; 2 seconds between toggles when cycling a power button


Global Const $DCPS_CH_ALL = 0

Global $g_dc_iReadTimer, $g_dc_iReadIndex, _
		$g_dc_iRefreshInterval = 450                ; update interval for loop

Global $g_dc_bCommValid = False                     ; IP address and/or communications are valid
Global $g_dc_screenShotFile = ""
Global $g_hMainGui, $g_dc_iTabIdx, $g_dc_hIpAddr, $g_dc_hDevID, _
		$g_dc_cSeqForm, $g_dc_seqVisible, _
		$g_dc_sRead, $g_dc_oDev = '', $g_dc_hSeqForm, $g_dc_hAssertCheck

Global $g_dc_measV[4]                               ; read voltage
Global $g_dc_measI[4]                               ; read current
Global $g_dc_measP[4]                               ; read power = v*i
Global $g_dc_setV[4]                                ; set voltage (device setpoint)
Global $g_dc_planV[4]                               ; set voltage (gui setpoint)
Global $g_dc_planVb[4]                              ; set voltage button
Global $g_dc_setI[4]                                ; set current (device setpoint)
Global $g_dc_planI[4]                               ; set current (gui setpoint)
Global $g_dc_planIb[4]                              ; set current button
Global $g_dc_on[4], $g_dc_onM[4][4]                 ; on/off button
Global $g_dc_lbl[4]                                 ; output channel label
Global $g_dc_pcolor[4] = [$COLOR_YELLOW, $COLOR_GREEN, $COLOR_BLUE, $COLOR_PURPLE]
;Global $g_dc_bState = ObjCreate("Scripting.Dictionary")

Global $g_dc_upSeqCh[4] = [4, 2, 3, 1]              ; default sequence
Global $g_dc_upSeqTm[4] = [0.5, 0.5, 0.5, 0.5]
Global $g_dc_dnSeqCh[4] = [1, 3, 2, 4]
Global $g_dc_dnSeqTm[4] = [0.5, 0.5, 0.5, 0.5]
Global $g_dc_cSeqUp[4]                              ; gui controls
Global $g_dc_cSeqUpdly[4]
Global $g_dc_cSeqDn[4]
Global $g_dc_cSeqDndly[4]

Global $g_dc_bPicDownloading = False
Global $g_dc_bPicData = ''
Global $g_dc_iScreen, $g_dc_hScreen
Global $g_dc_hMonitorCheck

; feedback variables that the visa scripts can update to refresh the gui in realtime
Global $g_dc_fbstate[5], $g_dc_fbmeasv[5], $g_dc_fbmeasi[5], $g_dc_fbsetv[5], $g_dc_fbseti[5]

Global Const $g_dc_MEASVOLT = "$g_dc_fbmeasv[0]=:MEASure:VOLTage? (@1:4)"               ; read measured output voltage
Global Const $g_dc_MEASCURR = "$g_dc_fbmeasi[0]=:MEASure:CURRent? (@1:4)"               ; read measured output current
Global Const $g_dc_RVOLTSET = "$g_dc_fbsetv[0]=:VOLTage? (@1:4)"                        ; read output voltage setpoint
Global Const $g_dc_RCURRSET = "$g_dc_fbseti[0]=:CURRent? (@1:4)"                        ; read max output current setpoint
Global Const $g_dc_OUTPSTAT = "$g_dc_fbstate[0]=:OUTPut:STATe? (@1:4)"                  ; read output state (on or off)




;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; initialization functions


Func dcTab_init()
	dcTab_SeqGuiCreate()                                            ; create sequence settings window, not shown yet
	;$g_dc_bCommValid = True
	LoopRegister("dcTab_Loop")
	$g_dc_iReadTimer = TimerInit()
	$g_dc_iReadIndex = -1

	If $g_dc_oDev = '' Then $g_dc_oDev = dcTab_GetIP()              ; make sure visession is at least initialized

	Local $j, $l = ["12V MAIN", "12V CPLD", "3.3V AUX", "12V SABR"] ; set some defaults
	Local $v = [12, 12, 3.3, 12]
	Local $i = [5, 5, 2.5, 5]
	For $j = 0 To 3
		GUICtrlSetData($g_dc_lbl[$j], $l[$j])
		GUICtrlSetData($g_dc_planV[$j], $v[$j])
		GUICtrlSetData($g_dc_planI[$j], $i[$j])
	Next
EndFunc   ;==>dcTab_init



Func dcTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	$g_dc_iTabIdx = $iTabIdx

	Local $x = 5, $i, $cMenu
	Local $y = 3, $y2, $y3

	GUICtrlCreateLabel("IP Address:", $x + 9, $y + 9, 58, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_dc_hIpAddr = GUICtrlCreateCombo("192.168.0.16", $x + 65, $y + 6, 105, 22)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "dcTab_GetID")
	GUICtrlCreateButton($ICON_SEARCH, $x + 170, $y + 6, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 15, 600)
	GUICtrlSetTip(-1, "Scan Network for DC Power Supply")
	GUICtrlSetOnEvent(-1, "dcTab_ScanNetwork")

	GUICtrlCreateButton($ICON_REFRESH, $x + 190, $y + 6, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 16, 600)
	GUICtrlSetTip(-1, "Reconnect to DC Power Supply")
	GUICtrlSetOnEvent(-1, "dcTab_GetID")
	GUICtrlCreateLabel("Device:", $x + 213, $y + 9, 38, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_dc_hDevID = GUICtrlCreateInput("devid", $x + 251, $y + 6, 163, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	GUICtrlCreateButton("EMO Stop", $x + 421, $y + 3, 55, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetBkColor(-1, $COLOR_RED)
	GUICtrlSetColor(-1, $COLOR_WHITE)
	GUICtrlSetOnEvent(-1, "__dcps_emo")

	$y2 = $y + 62
	$y3 = $y2 + 18

	$g_dc_hMonitorCheck = GUICtrlCreateCheckbox("Mon", $x + 72, $y + 40, 38, 17, $BS_RIGHTBUTTON)

	GUICtrlCreateButton($ICON_SCREENSHOT, $x + 5, $y + 36, 25, 25) ; , BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $SS_CENTERIMAGE, $BS_VCENTER))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 14) ; , Default, 0, "Segoe UI Emoji")
	GUICtrlSetTip(-1, "Grab the screenshot of the DC Power supply and show it here")
	GUICtrlSetOnEvent(-1, "dcTab_PicRefresh")

	GUICtrlCreateButton($ICON_SAVE, $x + 30, $y + 36, 25, 25, BitOR($BS_BOTTOM, $BS_CENTER))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 14)
	GUICtrlSetTip(-1, "Save the screenshot to a file")
	GUICtrlSetOnEvent(-1, "dcTab_SaveScreenShot")

	$y3 = $y2 + 2
	GUICtrlCreateLabel("Measured:", $x + 1, $y3, 55, 17)
	GUICtrlSetFont(-1, Default, 600)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Voltage", $x + 65, $y3, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24
	GUICtrlCreateLabel("Current (mA)", $x + 41, $y3, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24
	GUICtrlCreateLabel("Power (mW)", $x + 41, $y3, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24
	GUICtrlCreateLabel("Set:", $x + 1, $y3, 40, 17)
	GUICtrlSetFont(-1, Default, 600)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Voltage", $x + 65, $y3, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24
	GUICtrlCreateLabel("Current (A)", $x + 41, $y3, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24
	GUICtrlCreateLabel("Plan:", $x + 1, $y3, 40, 17)
	GUICtrlSetFont(-1, Default, 600)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Voltage", $x + 65, $y3, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24
	$g_dc_hAssertCheck = GUICtrlCreateCheckbox("", $x + 4, $y3 - 1, 18, 15)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateButton($ICON_CHECK, $x + 22, $y3 - 4, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "dcTab_assertClick")

	GUICtrlCreateLabel("Current (A)", $x + 41, $y3, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y3 += 24


	For $i = 0 To 3
		$g_dc_lbl[$i] = GUICtrlCreateLabel("(" & ($i + 1) & ")", $x + 113 + 92 * $i, $y + 40, 85, 17, BitOR($SS_CENTER, $SS_CENTERIMAGE, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetBkColor($g_dc_lbl[$i], $g_dc_pcolor[$i])
		GUICtrlSetFont(-1, Default, 700)
		GUICtrlSetColor($g_dc_lbl[$i], ($i = 0) ? $COLOR_BLACK : $COLOR_WHITE)
		GUICtrlSetTip(-1, "Click here to change the name")
		GUICtrlSetOnEvent(-1, "dcTab_lblClick")
		$y3 = $y2

		$g_dc_measV[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 86, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$y3 += 24
		$g_dc_measI[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 86, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$y3 += 24
		$g_dc_measP[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 86, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$y3 += 24

		$g_dc_setV[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 86, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$y3 += 24
		$g_dc_setI[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 86, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$y3 += 24

		$g_dc_planV[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 70, 21, BitOR($GUI_SS_DEFAULT_INPUT, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dc_planVb[$i] = GUICtrlCreateButton($ICON_CHECK, $x + 182 + 92 * $i, $y3, 16, 20)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetTip(-1, "Set the voltage")
		GUICtrlSetOnEvent(-1, "dcTab_setvClick")
		$y3 += 24

		$g_dc_planI[$i] = GUICtrlCreateInput("--", $x + 113 + 92 * $i, $y3, 70, 21, BitOR($GUI_SS_DEFAULT_INPUT, $WS_TABSTOP, $ES_RIGHT))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dc_planIb[$i] = GUICtrlCreateButton($ICON_CHECK, $x + 182 + 92 * $i, $y3, 16, 20)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetTip(-1, "Set the max current")
		GUICtrlSetOnEvent(-1, "dcTab_setiClick")
		$y3 += 24

	Next
	$y2 = $y3 + 2    ; y2 += 146

	GUICtrlCreateButton("Up", $x + 1, $y2, 40, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Power up via the configured sequence")
	GUICtrlSetOnEvent(-1, "dcTab_pwrupClick")
	GUICtrlCreateButton("Down", $x + 41, $y2, 40, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Power down via the configured sequence")
	GUICtrlSetOnEvent(-1, "dcTab_pwrdnClick")
	GUICtrlCreateButton($ICON_CFG, $x + 81, $y2, 17, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Edit the power up/down sequence")
	GUICtrlSetOnEvent(-1, "dcTab_sequenceClick")

	For $i = 0 To 3
		$g_dc_on[$i] = GUICtrlCreateButton("Off", $x + 139 + 92 * $i, $y2, 33, 25)
		;GUICtrlSetColor($g_dc_on[$i], $COLOR_BLACK)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetOnEvent(-1, "dcTab_btnToggle")

		$cMenu = GUICtrlCreateContextMenu($g_dc_on[$i])                                                                     ; context menu (right click) menu for each power button
		$g_dc_onM[$i][0] = $cMenu
		$g_dc_onM[$i][1] = GUICtrlCreateMenuItem("Cycle", $cMenu)
		GUICtrlSetOnEvent(-1, "dcTab_btnCycle")
		$g_dc_onM[$i][2] = GUICtrlCreateMenuItem("On", $cMenu)
		GUICtrlSetOnEvent(-1, "dcTab_btnOn")
		$g_dc_onM[$i][3] = GUICtrlCreateMenuItem("Off", $cMenu)
		GUICtrlSetOnEvent(-1, "dcTab_btnOff")
	Next

	Local $issHeight = 240                          ; expected dimensions of screenshot
	Local $issWidth = 320
	$y = $y2 + 30
	$x = $x + 480
	$y2 = _Max(Int(($y - $issHeight) / 2), 3)

	$g_dc_hScreen = GUICtrlGetHandle(GUICtrlCreatePic("", $x, $y2, $issWidth, $issHeight))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y2 += $issHeight + 2
	$y = _Max($y, $y2)
	$x = $x + $issWidth + 5

	Local $a[] = [$x, $y]
	Return $a
EndFunc   ;==>dcTab_GuiCreate






; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; Sequence configuration window
;


Func dcTab_SeqGuiCreate()
	$g_dc_hSeqForm = GUICreate("Power Sequence", 262, 202, 192, 124, -1, -1, $g_hMainGui)    ; child of main window
	GUISetOnEvent($GUI_EVENT_CLOSE, "dcTab_seqClose")
	GUICtrlCreateLabel("Power up sequence", 24, 8, 99, 17)
	GUICtrlCreateLabel("Power down sequence", 144, 8, 113, 17)
	GUICtrlCreateLabel("channel", 27, 27, 42, 17)
	GUICtrlCreateLabel("delay (s)", 75, 27, 43, 17)
	GUICtrlCreateLabel("channel", 147, 27, 42, 17)
	GUICtrlCreateLabel("delay (s)", 195, 27, 43, 17)
	For $i = 0 To 3
		GUICtrlCreateLabel(($i + 1) & ".", 10, 52 + 30 * $i, 13, 17)
		$g_dc_cSeqUp[$i] = GUICtrlCreateCombo("", 24, 48 + 30 * $i, 40, 25, BitOR($CBS_DROPDOWN, $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
		GUICtrlSetData($g_dc_cSeqUp[$i], "")
		GUICtrlSetData($g_dc_cSeqUp[$i], "1|2|3|4")
		$g_dc_cSeqUpdly[$i] = GUICtrlCreateInput("0.5", 72, 48 + 30 * $i, 60, 21)
		$g_dc_cSeqDn[$i] = GUICtrlCreateCombo("1", 144, 48 + 30 * $i, 40, 25, BitOR($CBS_DROPDOWN, $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
		GUICtrlSetData($g_dc_cSeqDn[$i], "")
		GUICtrlSetData($g_dc_cSeqDn[$i], "1|2|3|4")
		$g_dc_cSeqDndly[$i] = GUICtrlCreateInput("0.5", 192, 48 + 30 * $i, 60, 21)
	Next
	GUICtrlCreateButton("OK", 40, 167, 65, 25)
	GUICtrlSetOnEvent(-1, "dcTab_seqOk")
	GUICtrlCreateButton("Cancel", 136, 167, 89, 25)
	GUICtrlSetOnEvent(-1, "dcTab_seqClose")
	GUISwitch($g_hMainGui)
EndFunc   ;==>dcTab_SeqGuiCreate



Func dcTab_sequenceClick()
	Local $j
	For $j = 0 To 3
		GUICtrlSetData($g_dc_cSeqUp[$j], "")
		GUICtrlSetData($g_dc_cSeqUp[$j], "1|2|3|4|0", $g_dc_upSeqCh[$j])
		GUICtrlSetData($g_dc_cSeqUpdly[$j], $g_dc_upSeqTm[$j])
		GUICtrlSetData($g_dc_cSeqDn[$j], "")
		GUICtrlSetData($g_dc_cSeqDn[$j], "1|2|3|4|0", $g_dc_dnSeqCh[$j])
		GUICtrlSetData($g_dc_cSeqDndly[$j], $g_dc_dnSeqTm[$j])
	Next
	GUISetState(@SW_SHOW, $g_dc_hSeqForm)     ; show the config dialog
	$g_dc_seqVisible = 1
EndFunc   ;==>dcTab_sequenceClick



Func dcTab_seqClose()
	$g_dc_seqVisible = 0
	GUISetState(@SW_HIDE, $g_dc_hSeqForm)
	WinActivate($g_hMainGui)
EndFunc   ;==>dcTab_seqClose



Func dcTab_seqOk()
	Local $j
	For $j = 0 To 3                                            ; read settings from dialog box and put into setting table
		$g_dc_upSeqCh[$j] = GUICtrlRead($g_dc_cSeqUp[$j])
		$g_dc_upSeqTm[$j] = Number(GUICtrlRead($g_dc_cSeqUpdly[$j]), $NUMBER_DOUBLE)
		$g_dc_dnSeqCh[$j] = GUICtrlRead($g_dc_cSeqDn[$j])
		$g_dc_dnSeqTm[$j] = Number(GUICtrlRead($g_dc_cSeqDndly[$j]), $NUMBER_DOUBLE)
	Next
	dcTab_seqClose()
EndFunc   ;==>dcTab_seqOk




; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------







; ---------------------------------------------------------------------------
; GUI Event Handler Functions



Func dcTab_GetID()
	;???
	;__viGUIGetIDbg($g_dc_hDevID, $g_dc_hIpAddr, $g_dc_oDev, "g_dc_bCommValid")
	Local $sId = __viGUIGetID($g_dc_hDevID, $g_dc_hIpAddr, $g_dc_oDev, "g_dc_bCommValid")
	;__viFlushErrors($g_dc_oDev)
	;Return $sId
EndFunc   ;==>dcTab_GetID



Func dcTab_GetIP()
	Return __viGUIGetIP($g_dc_hIpAddr)
EndFunc   ;==>dcTab_GetIP



Func dcTab_lblClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dc_lbl[0]
			$j = 1
		Case $g_dc_lbl[1]
			$j = 2
		Case $g_dc_lbl[2]
			$j = 3
		Case $g_dc_lbl[3]
			$j = 4
	EndSwitch
	Local $n = InputBox("Set Label" & $j, "Label", GUICtrlRead(@GUI_CtrlId), "", 200, 120)
	If $n <> "" Then GUICtrlSetData(@GUI_CtrlId, $n)
EndFunc   ;==>dcTab_lblClick




Func dcTab_btnCycle()                                                   ; toggle twice
	Local $j = dcTab_btnh()
	Local $cBtn = $g_dc_on[$j - 1]
	Local $bState = dcTab_GuiGetOnState($j, $cBtn)                      ; grab state from gui button
	__dcps_SetStateBg($g_dc_oDev, $j, Not $bState)                      ; send visa command to set new output state
	__viCmd($g_dc_oDev, "sleep " & $g_dc_togglePeriod)                  ; delay period inbetween toggles
	__dcps_SetStateBg($g_dc_oDev, $j, $bState)                          ; send visa command to set new output state
	dcTab_GuiSetOnState($j, Not $bState, True, $cBtn, False)            ; update gui button
EndFunc   ;==>dcTab_btnCycle
Func dcTab_btnToggle()                                                  ; Toggle once
	Local $j = dcTab_btnh()
	Local $cBtn = $g_dc_on[$j - 1]
	dcTab_btnSet($j, Not dcTab_GuiGetOnState($j, $cBtn))                ; get current state, invert it, send it to dcTab_btnset
EndFunc   ;==>dcTab_btnToggle
Func dcTab_btnOn()                                                      ; Turn on
	dcTab_btnSet(dcTab_btnh(), True)                                    ;
EndFunc   ;==>dcTab_btnOn
Func dcTab_btnOff()                                                     ; Turn off
	dcTab_btnSet(dcTab_btnh(), False)                                   ;
EndFunc   ;==>dcTab_btnOff

Func dcTab_btnSet($j, $bState)                                          ; send visa command and set button state
	Local $cBtn = $g_dc_on[$j - 1]
	__dcps_SetStateBg($g_dc_oDev, $j, $bState)                          ; send visa command to set new output state
	dcTab_GuiSetOnState($j, $bState, True, $cBtn, False)                ; update gui button
EndFunc   ;==>dcTab_btnSet

Func dcTab_btnh()                                                       ; get button index from @GUI_CtrlId
	Local $j = 0
	Switch @GUI_CtrlId
		Case $g_dc_on[0], $g_dc_onM[0][0], $g_dc_onM[0][1], $g_dc_onM[0][2], $g_dc_onM[0][3]
			$j = 1
		Case $g_dc_on[1], $g_dc_onM[1][0], $g_dc_onM[1][1], $g_dc_onM[1][2], $g_dc_onM[1][3]
			$j = 2
		Case $g_dc_on[2], $g_dc_onM[2][0], $g_dc_onM[2][1], $g_dc_onM[2][2], $g_dc_onM[2][3]
			$j = 3
		Case $g_dc_on[3], $g_dc_onM[3][0], $g_dc_onM[3][1], $g_dc_onM[3][2], $g_dc_onM[3][3]
			$j = 4
	EndSwitch
	Return $j
EndFunc   ;==>dcTab_btnh




Func dcTab_pwrupClick()
	For $j = 0 To 3
		If $g_dc_upSeqCh[$j] > 0 Then
			__dcps_SetStateBg($g_dc_oDev, $g_dc_upSeqCh[$j], 1)
			__viCmd($g_dc_oDev, "sleep 50")
			__viCmd($g_dc_oDev, $g_dc_OUTPSTAT)
			__viCmd($g_dc_oDev, "sleep " & ($g_dc_upSeqTm[$j] * 1000))
		EndIf
	Next
	;For $j = 0 To 3
	;	If $g_dc_upSeqCh[$j] > 0 Then
	;		dcTab_SetOnState($g_dc_upSeqCh[$j], 1)
	;		Sleep($g_dc_upSeqTm[$j] * 1000)
	;	EndIf
	;Next
EndFunc   ;==>dcTab_pwrupClick



Func dcTab_pwrdnClick()
	For $j = 0 To 3
		If $g_dc_dnSeqCh[$j] > 0 Then
			__dcps_SetStateBg($g_dc_oDev, $g_dc_dnSeqCh[$j], 0)
			__viCmd($g_dc_oDev, "sleep 50")
			__viCmd($g_dc_oDev, $g_dc_OUTPSTAT)
			__viCmd($g_dc_oDev, "sleep " & ($g_dc_dnSeqTm[$j] * 1000))
		EndIf
	Next
	;For $j = 0 To 3
	;	If $g_dc_dnSeqCh[$j] > 0 Then
	;		dcTab_SetOnState($g_dc_dnSeqCh[$j], 0)
	;		Sleep($g_dc_dnSeqTm[$j] * 1000)
	;	EndIf
	;Next
EndFunc   ;==>dcTab_pwrdnClick



; in:		$ch = channel 1-4
;Func dcTab_SetOnState($ch, $s)
;	If $ch < 1 Or 4 < $ch Then Return
;	$s = $s ? 1 : 0
;	__dcps_SetState($g_dc_oDev, $ch, $s)
;	dcTab_GuiSetOnState($ch, $s)
;EndFunc   ;==>dcTab_SetOnState



Func dcTab_setvClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dc_planVb[0]
			$j = 1
		Case $g_dc_planVb[1]
			$j = 2
		Case $g_dc_planVb[2]
			$j = 3
		Case $g_dc_planVb[3]
			$j = 4
	EndSwitch

	;Local $v = InputBox("Set output " & $j & " voltage", "Voltage", StringTrimRight(GUICtrlRead($g_dc_planV[$j-1]), 2), "", 200, 120)
	;If $v = "" Then Return
	;__dcps_SetVoltage($g_dc_oDev, $j, $v) ; set voltage
	;$g_dc_bCommValid = 1

	__dcps_SetVoltage($g_dc_oDev, $j, Number(StringStripWS(GUICtrlRead($g_dc_planV[$j - 1]), 3)))
	$g_dc_bCommValid = True
EndFunc   ;==>dcTab_setvClick



Func dcTab_setiClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dc_planIb[0]
			$j = 1
		Case $g_dc_planIb[1]
			$j = 2
		Case $g_dc_planIb[2]
			$j = 3
		Case $g_dc_planIb[3]
			$j = 4
	EndSwitch
	;Local $i = InputBox("Set output " & $j & " max current", "Max Current", StringTrimRight(GUICtrlRead($g_dc_planI[$j - 1]), 2), "", 200, 120)
	;If $i = "" Then Return
	;__dcps_SetCurrent($g_dc_oDev, $j, $i)    ; set max current
	;$g_bCommValid = 1
	__dcps_SetCurrent($g_dc_oDev, $j, Number(StringStripWS(GUICtrlRead($g_dc_planI[$j - 1]), 3)))
	$g_bCommValid = True
EndFunc   ;==>dcTab_setiClick


Func dcTab_assertClick()
	Local $j
	For $j = 1 To 4
		__dcps_SetVoltage($g_dc_oDev, $j, Number(StringStripWS(GUICtrlRead($g_dc_planV[$j - 1]), 3)))
		__dcps_SetCurrent($g_dc_oDev, $j, Number(StringStripWS(GUICtrlRead($g_dc_planI[$j - 1]), 3)))
	Next
EndFunc   ;==>dcTab_assertClick



#cs
Button truth table so to keep button from flickering under this scenario:
1. app ques request to get button state from device
2. user clicks button on gui
2a. this function called to set gui button state with R=true
2b. que request to change button state on device
3. app receives response from request #1 and then calls this function.
   This button state is the old as the next command in the que will change it, so we want to process it but not update the gui
4. sends request to get button state and when it comes back we update the gui
* also for any updates we do not want to update the GUI if nothing has changed

	now				next
S	new	now	prev	now	prev	updateGui	guiNeedUpdate
0	0	0	0		0	0		n			n
0	0	0	1		0	0		y			n, but doing deferred
0	0	1	0		0	1		n			deferring
0	0	1	1		0	1		y			y
0	1	0	0		1	0		y			y
0	1	0	1		1	0		n			deferring
0	1	1	0		1	1		y			n, but doing deferred
0	1	1	1		1	1		n			n
1	0	0	0		0	0		n			n
1	0	0	1		0	0		y			maybe
1	0	1	0		0	1		y			y
1	0	1	1		0	1		y			y
1	1	0	0		1	0		y			y
1	1	0	1		1	0		y			y
1	1	1	0		1	1		y			maybe
1	1	1	1		1	1		n			n


A	B	C	D	G		AB\CD  00 01 11 10
0	0	0	0	n		 00     0  1  1  0
0	0	0	1	y		 01     1  0  0  1
0	0	1	0	n		 11     1  1  0  1
0	0	1	1	y		 10     0  1  1  1
0	1	0	0	y
0	1	0	1	n
0	1	1	0	y		F = (B xor D) or (A and (not C) and D) or (A and (not B) and C)
0	1	1	1	n		F = (new xor prev) or (self and not now and prev) or (self and not new and now)
1	0	0	0	n		F = (not new and prev) or (new and not prev) or (self and not now and prev) or (self and not new and now)
1	0	0	1	y
1	0	1	0	y       B<>D and not A
1	0	1	1	y       A and (B<>C or C<>D)
1	1	0	0	y
1	1	0	1	y
1	1	1	0	y
1	1	1	1	n

#ce

Func dcTab_GuiSetOnState($ch, $bNew, $bSelf = True, $cBtn = $g_dc_on, $bText = True)  ; ch=1-4
	$ch -= 1
	If $ch < 0 Or 3 < $ch Then Return
	If IsArray($cBtn) Then $cBtn = $cBtn[$ch]

	Local $hBtn = GUICtrlGetHandle($cBtn)
	Local $iUdat = _WinAPI_GetProp($hBtn, "state")                                                              ; pull history from user property field in control
	Local $bPrev = BitAND($iUdat, 1)                                                                            ; previous state of button
	Local $bNow = BitShift(BitAND($iUdat, 2), 1)                                                                ; current state of button
	$bNew = Int(Int($bNew) <> 0)                                                                                ; new state of button
	_WinAPI_SetProp($hBtn, "state", _
			BitOR(BitShift($bNew, -1), $bNow, BitAND($iUdat, 0xFFFFFFFC)))                                      ; rotate now and prev bits and store back into the data field

	;$bNew = ($bNew <> 0)
	If Not ((Not $bNew And $bPrev) Or ($bNew And Not $bPrev) Or ($bSelf And Not $bNow And $bPrev) Or ($bSelf And Not $bNew And $bNow)) Then Return

	GUICtrlSetBkColor($cBtn, ($bNew ? $g_dc_pcolor[$ch] : $COLOR_GRAY2))
	GUICtrlSetColor($cBtn, ((Not $bNew Or ($ch = 0)) ? $COLOR_BLACK : $COLOR_WHITE))
	If $bText Then GUICtrlSetData($cBtn, ($bNew ? "On" : "Off"))
EndFunc   ;==>dcTab_GuiSetOnState

Func dcTab_GuiGetOnState($ch, $cBtn = $g_dc_on)           ; ch=1-4
	If IsArray($cBtn) Then $cBtn = $cBtn[$ch - 1]
	Return (BitAND(_WinAPI_GetProp(GUICtrlGetHandle($cBtn), "state"), 2) = 2)
EndFunc   ;==>dcTab_GuiGetOnState



Func dcTab_SaveScreenShot()
	Local $sFile = __FileNameAutoIncrement($g_dc_screenShotFile)
	Local $sDrive, $sDir, $sName, $sExt, $ssDrive, $ssDir, $ssName, $ssExt
	_PathSplit(@ScriptFullPath, $ssDrive, $ssDir, $ssName, $ssExt)
	_PathSplit($sFile, $sDrive, $sDir, $sName, $sExt)
	If $sName = '' Then $sName = "DCPS"
	If $sDir = '' Then $sDir = $ssDir
	If $sDrive = '' Then $sDrive = $ssDrive
	$sFile = FileSaveDialog("Save Screen Shot", $sDrive & $sDir, "(*.gif)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sName & $sExt, $g_hMainGui)
	If $sFile = "" Then Return

	Local $bData = __Canvas_GetCtrlPic($g_aCanvas[$g_dc_iTabIdx], $g_dc_iScreen, $g_dc_hScreen)
	If IsBinary($bData) Then                                                                ; if picture found then save it to file
		Local $hFile = FileOpen($sFile, BitOR($FO_BINARY, $FO_OVERWRITE))
		If $hFile > 0 Then
			FileWrite($hFile, $bData)
			FileClose($hFile)
			MsgBox($MB_ICONINFORMATION, "DC Power Supply", "Screenshot successfully saved to: " & @CRLF & @CRLF & $sFile, 5)
		Else
			MsgBox($MB_ICONERROR, "DC Power Supply", "Unable to save screen to file.  Error " & @error & @CRLF & @CRLF & $sFile)
		EndIf
	Else
		dcTab_PicRefresh()                                                                ; if no picture found then request one from the visa device
	EndIf
EndFunc   ;==>dcTab_SaveScreenShot




;---------- Capture screen shot functions
Func dcTab_screenShotClick()
	;------------  grab screenshot
	; ==============================================================================
	; Script:      Grab_N6705B_Screenshot_viOpen.au3
	; Description: Connects to an Agilent N6705B using raw visa32.dll functions
	;              (viOpenDefaultRM, viOpen, viReadToFile), triggers a screenshot,
	;              and streams it directly to a local file.
	; ==============================================================================

	; --- CONFIGURATION ---
	Local $sSavePath = $g_dc_screenShotFile
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($sSavePath, $sDrive, $sDir, $sFileName, $sExtension)
	$sSavePath = FileSaveDialog("Save Screen Shot", $sDrive & $sDir, "(*.gif;*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName & $sExtension, $g_hMainGui)
	If $sSavePath = "" Then Return

	Local $iRet = __dcps_SaveScreenShot($g_dc_oDev, $sSavePath)
	;MsgBox(0, "hi", "$iRet=" & $iRet & @CRLF & "error=" & @error & @CRLF)

EndFunc   ;==>dcTab_screenShotClick





; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; dc power supply visa functions



; task:			Set the on/off state of a DC Power supply channel
; in:			$ch = channel 1-4
;				$b = 1 for on, 0 for off
Func __dcps_SetState(ByRef $viSession, $ch, $b)
	__viCmdBl($viSession, ":OUTP " & ($b ? "ON" : "OFF") & ", (@" & $ch & ")")        ; send command, wait for command to be sent
EndFunc   ;==>__dcps_SetState
Func __dcps_SetStateBg(ByRef $viSession, $ch, $b)
	__viCmd($viSession, ":OUTP " & ($b ? "ON" : "OFF") & ", (@" & $ch & ")")          ; send command non-blocking / background
EndFunc   ;==>__dcps_SetStateBg

Func __dcps_GetState(ByRef $viSession, $ch, $iTimeoutMS = 1000)
	Return (__viReqBl($viSession, ":OUTP:STAT? (@" & $ch & ")", $iTimeoutMS) > 0)
EndFunc   ;==>__dcps_GetState

; task:			turn all power output channels off
Func __dcps_emo()
	Local $viSession = $g_dc_oDev
	If Not __viIsInstrument($viSession) Then $viSession = dcTab_GetIP()
	__viCmdBl($viSession, ":OUTP OFF, (@1:4)")
EndFunc   ;==>__dcps_emo




; task:			set the output voltage of a channel
; in:			ch = channel 1-4
Func __dcps_SetVoltage($viSession, $iCh, $fVoltage)
	__viCmd($viSession, ":VOLT " & $fVoltage & ", (@" & $iCh & ")")                 ; set voltage
EndFunc   ;==>__dcps_SetVoltage



; task:			set the max output current of a channel
; in:			ch = channel 1-4
Func __dcps_SetCurrent($viSession, $iCh, $fCurrent)
	__viCmd($viSession, ":CURR " & $fCurrent & ", (@" & $iCh & ")")                 ; set current
EndFunc   ;==>__dcps_SetCurrent



;			send request for a given channel
; in:		$ipAddr = IP address of device
;			$sReq = request prefix (without the "(@ch)" channel number)
;			$iCh = 1-4 or 0 for all
; out:		response from device
Func __dcps_viChRequest($viSession, $sReq, $iCh = 0)
	$iCh = Number($iCh)
	If ($iCh < 1) Or (4 < $iCh) Then $iCh = "1:4"
	Return __viReqBl($viSession, $sReq & " (@" & $iCh & ")", 1000)
EndFunc   ;==>__dcps_viChRequest




; task:		grab screenshot and save it to file
; in:		$vSession = ip address of DC power supply, or existing visa session handle
;			$sFile = path and name of destination file
Func __dcps_SaveScreenShot($viSession, $sFile = $g_dc_screenShotFile, $iTimeoutMS = 5000)
	Local $aCmds = [ _
			"flush", _
			"$=" & $VI_REQ_ERR, _
			"##:HCOPy:SDUMp:DATA?"]
	__viScript($viSession, $aCmds, $sFile, $iTimeoutMS)
	Return __viFlush($viSession)
EndFunc   ;==>__dcps_SaveScreenShot




Func dcTab_ScanNetwork()
	__viScanSubnet()
	;__viScanSubnet("192.168.0.0", $g_dc_hIpAddr, "DC Power Supply")
EndFunc   ;==>dcTab_ScanNetwork



Func dcTab_PicRefresh()             ; download latest screenshot from DCPS and show in the gui
	Local $aCmds = [ _
			"flush", _
			"$=" & $VI_REQ_ERR, _
			"$g_dc_bPicData:=HCOPy:SDUMp:DATA?"]
	__viGuiPicRefresh($g_dc_bPicDownloading, $g_dc_bPicData, $g_dc_oDev, $aCmds)
EndFunc   ;==>dcTab_PicRefresh




; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; background loop


Func dcTab_Loop()
	If TimerDiff($g_dc_iReadTimer) < $g_dc_iRefreshInterval Then Return
	$g_dc_iReadTimer = TimerInit()

	__viGuiPicLoop($g_dc_bPicDownloading, $g_dc_bPicData, $g_dc_iTabIdx, $g_dc_iScreen, $g_dc_hScreen)      ; check if any screen image was downloaded for the gui
	If GUICtrlRead($g_cTab) <> $g_dc_iTabIdx Then Return                                                    ; if we are not the visible tab then nothing more to do
	If GUICtrlRead($g_dc_hMonitorCheck) <> $GUI_CHECKED Then Return                                         ; if monitor checkbox is not checked then we do not monitor, return

	Local $i, $j, $k, $aRead ;, $prev1

	$j = $g_dc_fbstate[0]                                                                                   ; check variables for any data that came from the visa device
	If $j <> '' Then
		$aRead = StringSplit($j, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				$g_dc_fbstate[$i] = $aRead[$i]
			Next
		EndIf
		$g_dc_fbstate[0] = ''
	EndIf
	$j = $g_dc_fbmeasv[0]
	If $j <> '' Then
		$aRead = StringSplit($j, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				$g_dc_fbmeasv[$i] = $aRead[$i]
			Next
		EndIf
		$g_dc_fbmeasv[0] = ''
	EndIf
	$j = $g_dc_fbmeasi[0]
	If $j <> '' Then
		$aRead = StringSplit($j, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				$g_dc_fbmeasi[$i] = $aRead[$i]
			Next
		EndIf
		$g_dc_fbmeasi[0] = ''
	EndIf
	$j = $g_dc_fbsetv[0]
	If $j <> '' Then
		$aRead = StringSplit($j, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				$g_dc_fbsetv[$i] = $aRead[$i]
			Next
		EndIf
		$g_dc_fbsetv[0] = ''
	EndIf
	$j = $g_dc_fbseti[0]
	If $j <> '' Then
		$aRead = StringSplit($j, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				$g_dc_fbseti[$i] = $aRead[$i]
			Next
		EndIf
		$g_dc_fbseti[0] = ''
	EndIf


	For $i = 1 To 4
		$k = $i - 1
		$j = $g_dc_fbstate[$i]
		If $j <> '' Then
			$j = (Int($j) <> 0)
			dcTab_GuiSetOnState($i, $j, False)
			;$prev1 = Int(dcTab_GuiGetOnState($i))
			;If $prev1 = $g_dc_onh[$k] And $prev1 <> $j Then dcTab_GuiSetOnState($i, $j)
			;$g_dc_onh[$k] = $j
			$g_dc_fbstate[$i] = ''
		EndIf
		$j = $g_dc_fbmeasv[$i]
		If $j <> '' Then
			$j = Number($j, $NUMBER_DOUBLE)
			GUICtrlSetData($g_dc_measV[$k], StringFormat("%.3f", $j) & " V")
			$g_dc_fbmeasv[$i] = ''
		EndIf
		$j = $g_dc_fbmeasi[$i]
		If $j <> '' Then
			$j = Number($j, $NUMBER_DOUBLE)
			GUICtrlSetData($g_dc_measI[$k], StringFormat("%.1f", $j * 1000) & " mA")
			GUICtrlSetData($g_dc_measP[$k], StringFormat("%.1f", Number(StringTrimRight(GUICtrlRead($g_dc_measV[$k]), 2), $NUMBER_DOUBLE) * $j * 1000) & " mW")
			$g_dc_fbmeasi[$i] = ''
		EndIf
		$j = $g_dc_fbsetv[$i]
		If $j <> '' Then
			$j = Number($j, $NUMBER_DOUBLE)
			GUICtrlSetData($g_dc_setV[$k], StringFormat("%.3f", $j) & " V")
			$g_dc_fbsetv[$i] = ''
		EndIf
		$j = $g_dc_fbseti[$i]
		If $j <> '' Then
			$j = Number($j, $NUMBER_DOUBLE)
			GUICtrlSetData($g_dc_setI[$k], StringFormat("%.3f", $j) & " A")
			$g_dc_fbseti[$i] = ''
		EndIf
	Next


	If Not $g_dc_bCommValid Then Return                                     ; if communications are not running then return/exit here
	;If $g_dc_oDev = '' Then $g_dc_oDev = dcTab_GetIP()  	                 ; make sure visession is at least initialized
	If Not __viIsIdle($g_dc_oDev) Then Return                               ; if we still have commands in the queue then hold off adding more

	For $j = 0 To 1
		Local $aReq[] = [$g_dc_MEASVOLT, $g_dc_MEASCURR, $g_dc_RVOLTSET, $g_dc_RCURRSET, $g_dc_OUTPSTAT, "$=" & $VI_REQ_ERR]
		$g_dc_iReadIndex = Mod(Int($g_dc_iReadIndex) + 1, UBound($aReq))    ; rotate to the next item to read
		__viReq($g_dc_oDev, $aReq[$g_dc_iReadIndex])
		;__viCmd($g_dc_oDev, "sleep 50" )                                    ; give the device a chance to respond before flooding it with commands
	Next

EndFunc   ;==>dcTab_Loop








; ----------------------
; ----------------------
; ----------------------
; ----------------------
; ----------------------

; config file functions



Global $dcTab_ConfigSection = "DCPS"
Global $g_configFile

Func dcTab_ConfigWrite()
	__viSaveIP($g_dc_hIpAddr, $dcTab_ConfigSection)
	Local $j
	For $j = 0 To 3
		IniWrite($g_configFile, $dcTab_ConfigSection, "V" & ($j + 1), StringTrimRight(GUICtrlRead($g_dc_planV[$j]), 2))
		IniWrite($g_configFile, $dcTab_ConfigSection, "I" & ($j + 1), StringTrimRight(GUICtrlRead($g_dc_planI[$j]), 2))
		IniWrite($g_configFile, $dcTab_ConfigSection, "upseqch" & ($j + 1), $g_dc_upSeqCh[$j])
		IniWrite($g_configFile, $dcTab_ConfigSection, "upseqtm" & ($j + 1), $g_dc_upSeqTm[$j])
		IniWrite($g_configFile, $dcTab_ConfigSection, "dnseqch" & ($j + 1), $g_dc_dnSeqCh[$j])
		IniWrite($g_configFile, $dcTab_ConfigSection, "dnseqtm" & ($j + 1), $g_dc_dnSeqTm[$j])
		IniWrite($g_configFile, $dcTab_ConfigSection, "chlbl" & ($j + 1), GUICtrlRead($g_dc_lbl[$j]))
	Next
	IniWrite($g_configFile, $dcTab_ConfigSection, "screenShot", $g_dc_screenShotFile)                                       ; file name of the screenshot file
	__IniWriteGuiCheckbox($g_dc_hMonitorCheck, "monitor", $dcTab_ConfigSection)                                             ; monitor checkbox
	__IniWriteGuiCheckbox($g_dc_hAssertCheck, "assert", $dcTab_ConfigSection)                                               ; assert checkbox
EndFunc   ;==>dcTab_ConfigWrite



Func dcTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	Local $j
	__viLoadIP($g_dc_hIpAddr, $dcTab_ConfigSection)
	For $j = 0 To 3
		GUICtrlSetData($g_dc_planV[$j], IniRead($g_configFile, $dcTab_ConfigSection, "V" & ($j + 1), StringTrimRight(GUICtrlRead($g_dc_planV[$j]), 2)) & " V")
		GUICtrlSetData($g_dc_planI[$j], IniRead($g_configFile, $dcTab_ConfigSection, "I" & ($j + 1), StringTrimRight(GUICtrlRead($g_dc_planI[$j]), 2)) & " A")
		$g_dc_upSeqCh[$j] = IniRead($g_configFile, $dcTab_ConfigSection, "upseqch" & ($j + 1), $g_dc_upSeqCh[$j])
		$g_dc_upSeqTm[$j] = IniRead($g_configFile, $dcTab_ConfigSection, "upseqtm" & ($j + 1), $g_dc_upSeqTm[$j])
		$g_dc_dnSeqCh[$j] = IniRead($g_configFile, $dcTab_ConfigSection, "dnseqch" & ($j + 1), $g_dc_dnSeqCh[$j])
		$g_dc_dnSeqTm[$j] = IniRead($g_configFile, $dcTab_ConfigSection, "dnseqtm" & ($j + 1), $g_dc_dnSeqTm[$j])
		GUICtrlSetData($g_dc_lbl[$j], IniRead($g_configFile, $dcTab_ConfigSection, "chlbl" & ($j + 1), GUICtrlRead($g_dc_lbl[$j])))
	Next
	$g_dc_screenShotFile = IniRead($g_configFile, $dcTab_ConfigSection, "screenShot", $g_dc_screenShotFile)               ; screen shot file
	__IniReadGuiCheckbox($g_dc_hMonitorCheck, "monitor", $dcTab_ConfigSection)                                              ; monitor checkbox
	__IniReadGuiCheckbox($g_dc_hAssertCheck, "assert", $dcTab_ConfigSection)                                                ; assert checkbox
	dcTab_GetID()
	If __GuiCheckbox($g_dc_hAssertCheck) Then dcTab_ConfigAssert()
EndFunc   ;==>dcTab_ConfigRead



; task:			Assert config in the GUI onto the DC Power supply
;				if voltage and current settings are the same, then the channel is left alone
;				if voltage or current are updated, then the output state is turned off for safety
Func dcTab_ConfigAssert()
	Local $i, $cv, $nv, $aReadV, $aReadI
	__viCmd($g_dc_oDev, $VI_CLS)
	__viCmd($g_dc_oDev, "$=" & $VI_REQ_ERR)
	$aReadV = StringSplit(__dcps_viChRequest($g_dc_oDev, "VOLT?", $DCPS_CH_ALL), ",")
	If $aReadV[0] < 4 Then Return SetError(-1, 0, 0)
	$aReadI = StringSplit(__dcps_viChRequest($g_dc_oDev, "CURR?", $DCPS_CH_ALL), ",")
	If $aReadI[0] < 4 Then Return SetError(-1, 0, 0)

	For $i = 0 To 3
		; voltage setpoint
		$cv = StringFormat("%.3f", $aReadV[$i + 1])
		$nv = StringTrimRight(GUICtrlRead($g_dc_planV[$i]), 2)
		If Not ($cv = $nv) Then
			__dcps_SetState($g_dc_oDev, $i + 1, 0)                ; turn off the channel power output
			__dcps_SetVoltage($g_dc_oDev, $i + 1, Number($nv))    ; set the voltage
		EndIf

		; max current setpoint
		$cv = StringFormat("%.3f", $aReadI[$i + 1])
		$nv = StringTrimRight(GUICtrlRead($g_dc_planI[$i]), 2)
		If Not ($cv = $nv) Then
			__dcps_SetState($g_dc_oDev, $i + 1, 0)                ; turn off the channel power output
			__dcps_SetCurrent($g_dc_oDev, $i + 1, Number($nv))    ; set the max current
		EndIf
	Next

	dcTab_PicRefresh()
EndFunc   ;==>dcTab_ConfigAssert










; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

