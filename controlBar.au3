
#include-once

#include "tabChamber.au3"
#include "tabDCpowerSupply.au3"


#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <WindowsConstants.au3>
#include <WinAPISys.au3>



Global $g_cb_hD[4], $g_cb_hM[4][4], $g_cb_hDup, $g_cb_hDdn      ; DC PS controls
Global $g_cb_sD ; $g_cb_bD[4], $g_cb_sD                         ;
Global $g_cb_hTemp, $g_cb_hTset, $g_cb_hTen, $g_cb_hTeta        ; chamber controls
Global $g_cb_fTemp, $g_cb_fTset, $g_cb_bTen                     ;
Global $g_cb_hEn                                                ; global on/off button
Global $g_cb_iReadTimer, $g_cb_iRefreshInterval = 750           ;
Global $g_cb_hMon                                               ; checkbox to enable or disable monitoring of the devices
Global $g_cb_iEtaTimer = '', $g_cb_fEtaPrevTemp, _              ; calculating eta to reach target temperature
		$g_cb_fEtaPrevVelocity
Global $g_cb_togglePeriod = 2000                                ; time between toggles when cycling the power
Global $g_cb_Tovershoot = 4                                     ; minimum number of degrees delta to get the chamber to turn power up to at least 50% or so
Global $g_cb_ToverPeriod = 10000                                ; length of time after requesting to overshoot our temperature target before we request the real target

Global $g_oMainCanvas, $g_hMainGui; , $g_cb_iH ;, $g_cb_iY


Func CreateControlBar($iX, $iY, $iW, $iH)
	Local $i, $cMenu

	Local $iWbtn = 25                                                                                                       ; on/off button width
	Local $iWbtn2 = 40                                                                                                      ; up/down button width
	Local $iWbtn3 = 60                                                                                                      ; dc on/off buttons width
	Local $iWt = 45                                                                                                         ; width of temperature or eta field
	Local $iWs1 = 2                                                                                                         ; space between buttons and fields
	Local $iWs2 = 20                                                                                                        ; space between groups
	Local $lbl1, $lbl2, $lbl3, $i, $n

	Local $x = $iX + 15

	$iY -= $iH    ; initial $iY is passed as the height of the overall gui area to place the control bar.  recalculate the Y top left corner for it
	;$g_cb_iY = $iY

	$g_cb_hMon = GUICtrlCreateCheckbox("Mon", $x, $iY + 1, 40, 17, BitOR($BS_RIGHTBUTTON, $BS_RIGHT))
	$x += 60

	; chamber controls
	$lbl1 = GUICtrlCreateLabel("T", $x, $iY + 3, 10, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	$x += 10
	$g_cb_hTemp = GUICtrlCreateLabel("--- C", $x, $iY + 3, $iWt, $iH, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))              ; chamber temperature
	$x += $iWt + $iWs1

	$lbl2 = GUICtrlCreateLabel("SP", $x, $iY + 3, 20, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	$x += 20
	$g_cb_hTset = GUICtrlCreateButton("--- C", $x, $iY, $iWt, $iH, $BS_RIGHT)                                               ; chamber setpoint
	GUICtrlSetOnEvent(-1, "__cbSetTC")
	$x += $iWt + $iWs1
	$cMenu = GUICtrlCreateContextMenu($g_cb_hTset)                                                                          ; context menu (right click) menu
	GUICtrlCreateMenuItem("70 C", $cMenu)
	GUICtrlSetOnEvent(-1, "__cbTCset70")
	GUICtrlCreateMenuItem("25 C", $cMenu)
	GUICtrlSetOnEvent(-1, "__cbTCset25")
	GUICtrlCreateMenuItem("-5 C", $cMenu)
	GUICtrlSetOnEvent(-1, "__cbTCsetN5")
	GUICtrlCreateMenuItem("-40 C", $cMenu)
	GUICtrlSetOnEvent(-1, "__cbTCsetN40")

	$lbl3 = GUICtrlCreateLabel("ETA", $x, $iY + 3, 28, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	$x += 28
	$g_cb_hTeta = GUICtrlCreateLabel("--:--", $x, $iY + 3, $iWt, $iH, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))              ; eta to reach temperature
	$x += $iWt + 8

	$g_cb_hTen = GUICtrlCreateButton("Off", $x, $iY, $iWbtn, $iH)                                                           ; chamber enable button
	GUICtrlSetOnEvent(-1, "__cbTCen")
	$x += $iWbtn + $iWs2

	; power supply controls
	$g_cb_hDup = GUICtrlCreateButton("Up", $x, $iY, $iWbtn2, $iH)                                                           ; dc supply up sequence
	GUICtrlSetOnEvent(-1, "dcTab_pwrupClick")
	$x += $iWbtn2 + $iWs1
	$g_cb_hDdn = GUICtrlCreateButton("Down", $x, $iY, $iWbtn2, $iH)                                                         ; dc supply down sequence
	GUICtrlSetOnEvent(-1, "dcTab_pwrdnClick")
	$x += $iWbtn2 + $iWs1

	For $i = 0 To 3
		$g_cb_hD[$i] = GUICtrlCreateButton("Off", $x, $iY, $iWbtn3, $iH)                                                    ; dc channel 1 on/off
		GUICtrlSetOnEvent(-1, "__cbDCtoggle")
		$x += $iWbtn3 + $iWs1
		$cMenu = GUICtrlCreateContextMenu($g_cb_hD[$i])                                                                     ; context menu (right click) menu for each power button
		$g_cb_hM[$i][0] = $cMenu
		$g_cb_hM[$i][1] = GUICtrlCreateMenuItem("Cycle", $cMenu)
		GUICtrlSetOnEvent(-1, "__cbDCcycle")
		$g_cb_hM[$i][2] = GUICtrlCreateMenuItem("On", $cMenu)
		GUICtrlSetOnEvent(-1, "__cbDCon")
		$g_cb_hM[$i][3] = GUICtrlCreateMenuItem("Off", $cMenu)
		GUICtrlSetOnEvent(-1, "__cbDCoff")
	Next
	$x += $iWs2



	; all on/off button
	$g_cb_hEn = GUICtrlCreateButton("Off", $x, $iY, $iWbtn, $iH)                                                            ; chamber and all DC power rails on/off button.  off: dc down followed by all ch off, and chamber off.  on: dc up, chamber on
	GUICtrlSetOnEvent(-1, "__cbEn")
	$x += $iWbtn

	; add controls to aCtrls so they get scaled with ctrl+mousewheel
	Local $a[] = [$g_cb_hMon, $lbl1, $g_cb_hTemp, $lbl2, $g_cb_hTset, $lbl3, $g_cb_hTeta, $g_cb_hTen, $g_cb_hDup, $g_cb_hDdn, $g_cb_hD[0], $g_cb_hD[1], $g_cb_hD[2], $g_cb_hD[3], $g_cb_hEn]
	Local $aCtrls[0]
	If $g_oMainCanvas.Exists('aCBCtrls') Then $aCtrls = $g_oMainCanvas.Item('aCBCtrls')
	Local $i, $n = UBound($a) - 1, $m = UBound($aCtrls)
	ReDim $aCtrls[$m + $n + 1]
	Local $mydock = $GUI_DOCKALL ; BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE) ; BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKBOTTOM)
	For $i = 0 To $n
		GUICtrlSetResizing($a[$i], $mydock)
		$aCtrls[$m + $i] = GUICtrlGetHandle($a[$i])
	Next
	;??? $g_oMainCanvas.Item('aCBCtrls') = $aCtrls
	$g_oMainCanvas.Item('aCBCtrls') = $aCtrls

EndFunc   ;==>CreateControlBar

Func ControlBar_Init()
	Local $i                                                                                                                ; copy labels from DC PS to buttons on control bar
	For $i = 0 To 3
		GUICtrlSetData($g_cb_hD[$i], GUICtrlRead($g_dc_lbl[$i]))
	Next
	__Canvas_ZoomCatalog($g_oMainCanvas, 'aCBCtrls')
	$g_cb_iReadTimer = TimerInit()                                                                                          ; Reset background clock
	LoopRegister("__cbLoop")
EndFunc   ;==>ControlBar_Init





;



; gui event handlers
;



Func __cbTCset70()
	__cbTCset(70)
EndFunc   ;==>__cbTCset70
Func __cbTCset25()
	__cbTCset(25)
EndFunc   ;==>__cbTCset25
Func __cbTCsetN5()
	__cbTCset(-5)
EndFunc   ;==>__cbTCsetN5
Func __cbTCsetN40()
	__cbTCset(-40)
EndFunc   ;==>__cbTCsetN40

Func __cbTCset($fSP)
	Local $fTemp = Number(StringTrimRight(GUICtrlRead($g_cb_hTemp), 2))
	If Abs($fSP - $fTemp) < 3 Then                                      ; if we are within 3 degrees then we need to first overshoot our request so the chamber works towards more than a 3 degree delta, next after a minute or so we set the real temperature
		__F4Tsetpoint($g_tc_oDev, $fTemp + ($fSP > $fTemp ? 1 : -1) * $g_cb_Tovershoot)
		__F4TreadBg($g_tc_oDev, $g_iF4Tsetpoint, "g_cb_fTset")
		__F4TreadBg($g_tc_oDev, $g_iF4Ttemperature, "g_cb_fTemp")
		__viCmd($g_tc_oDev, "sleep " & $g_cb_ToverPeriod)
	EndIf
	__F4TreadBg($g_tc_oDev, $g_iF4Tsetpoint, "g_cb_fTset")
	__F4TreadBg($g_tc_oDev, $g_iF4Ttemperature, "g_cb_fTemp")
	__F4Tsetpoint($g_tc_oDev, $fSP)
	__cbTetaReset()
EndFunc   ;==>__cbTCset


Func __cbSetTC()        ; user clicked button - set thermal chamber temperature setpoint
	Local $fSP = Round(Number(GUICtrlRead($g_cb_hTset)), 1)
	$fSP = StringStripWS(InputBox("Chamber Temperature", "SetPoint", $fSP, "", 200, 120), 3)
	If StringInStr(StringLower(StringRight($fSP, 1)), "cf") Then $fSP = StringStripWS(StringTrimRight($fSP, 1), 3)
	If ($fSP = "") Or (Not StringIsFloat($fSP) And Not StringIsInt($fSP)) Then Return
	$fSP = Round(Number($fSP), 1)
	;__ConsolePrintVars("__cbSetTC, ", "fSP", $fSP)
	__cbTCset($fSP)
EndFunc   ;==>__cbSetTC



Func __cbTCen()
	If $g_tc_bCommValid Then tcTab_ToggleOutputState($g_cb_hTen)
EndFunc   ;==>__cbTCen



Func __cbDCcycle()                                                  ; toggle twice
	Local $j = __cbDCh()
	Local $cBtn = $g_cb_hD[$j - 1]
	Local $bState = dcTab_GuiGetOnState($j, $cBtn)                  ; grab state from gui button
	__dcps_SetStateBg($g_dc_oDev, $j, Not $bState)                  ; send visa command to set new output state
	__viCmd($g_dc_oDev, "sleep " & $g_cb_togglePeriod)              ; delay period inbetween toggles
	__dcps_SetStateBg($g_dc_oDev, $j, $bState)                      ; send visa command to set new output state
	dcTab_GuiSetOnState($j, Not $bState, True, $cBtn, False)        ; update gui button
EndFunc   ;==>__cbDCcycle
Func __cbDCtoggle()                                                 ; Toggle once
	Local $j = __cbDCh()
	Local $cBtn = $g_cb_hD[$j - 1]
	__cbDCset($j, Not dcTab_GuiGetOnState($j, $cBtn))               ; get current state, invert it, send it to __cbDCset
EndFunc   ;==>__cbDCtoggle
Func __cbDCon()                                                     ; Turn on
	__cbDCset(__cbDCh(), True)                                      ;
EndFunc   ;==>__cbDCon
Func __cbDCoff()                                                    ; Turn off
	__cbDCset(__cbDCh(), False)                                     ;
EndFunc   ;==>__cbDCoff

Func __cbDCset($j, $bState)                                         ; send visa command and set button state
	Local $cBtn = $g_cb_hD[$j - 1]
	__dcps_SetStateBg($g_dc_oDev, $j, $bState)                      ; send visa command to set new output state
	dcTab_GuiSetOnState($j, $bState, True, $cBtn, False)            ; update gui button
EndFunc   ;==>__cbDCset

Func __cbDCh()                                                      ; get button index from @GUI_CtrlId
	Local $j = 0
	Switch @GUI_CtrlId
		Case $g_cb_hD[0], $g_cb_hM[0][0], $g_cb_hM[0][1], $g_cb_hM[0][2], $g_cb_hM[0][3]
			$j = 1
		Case $g_cb_hD[1], $g_cb_hM[1][0], $g_cb_hM[1][1], $g_cb_hM[1][2], $g_cb_hM[1][3]
			$j = 2
		Case $g_cb_hD[2], $g_cb_hM[2][0], $g_cb_hM[2][1], $g_cb_hM[2][2], $g_cb_hM[2][3]
			$j = 3
		Case $g_cb_hD[3], $g_cb_hM[3][0], $g_cb_hM[3][1], $g_cb_hM[3][2], $g_cb_hM[3][3]
			$j = 4
	EndSwitch
	Return $j
EndFunc   ;==>__cbDCh




Func __cbEn()
	If StringLower(GUICtrlRead($g_cb_hEn)) = "on" Then
		GUICtrlSetData($g_cb_hEn, "Off")
		GUICtrlSetBkColor($g_cb_hEn, $COLOR_GRAY2)
		dcTab_pwrdnClick()
		__F4Tenable(False)
		__dcps_emo()
	Else
		GUICtrlSetData($g_cb_hEn, "On")
		GUICtrlSetBkColor($g_cb_hEn, $COLOR_YELLOW)
		dcTab_pwrupClick()
		__F4Tenable(True)
		__cbTetaReset()
	EndIf
EndFunc   ;==>__cbEn




; background loop
;


Func __cbLoop()
	If TimerDiff($g_cb_iReadTimer) < $g_cb_iRefreshInterval Then Return
	$g_cb_iReadTimer = TimerInit()                                                                                          ; Reset background clock
	If Not __GuiCheckbox($g_cb_hMon) Then Return

	Local $i, $bFlag

	If $g_cb_fTset <> '' Then
		GUICtrlSetData($g_cb_hTset, StringFormat("%.1f C", __F4TtoC($g_tc_oDev, __F4TreadBgProcReply($g_tc_oDev, $g_iF4Tsetpoint, $g_cb_fTset))))
		$g_cb_fTset = ''
	EndIf
	If $g_cb_fTemp <> '' Then
		$g_cb_fTemp = __F4TtoC($g_tc_oDev, __F4TreadBgProcReply($g_tc_oDev, $g_iF4Ttemperature, $g_cb_fTemp))
		GUICtrlSetData($g_cb_hTemp, StringFormat("%.1f C", $g_cb_fTemp))
		__cbTeta($g_cb_fTemp)
		$g_cb_fTemp = ''
	EndIf
	If $g_cb_bTen <> '' Then
		tcTab_GuiSetOutputState(__F4TreadBgProcReply($g_tc_oDev, $g_iF4Tenable, $g_cb_bTen), $g_cb_hTen)
		$g_cb_bTen = ''
	EndIf

	If $g_cb_sD <> '' Then
		Local $aRead = StringSplit($g_cb_sD, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				dcTab_GuiSetOnState($i, Int($aRead[$i]) <> 0, False, $g_cb_hD, False)
			Next
		EndIf
		$g_cb_sD = ''
	EndIf

	$bFlag = __GuiToggleButtonGetOnState($g_cb_hTen)        ; check on state of main on/off button
	For $i = 0 To 3
		$bFlag = $bFlag Or __GuiToggleButtonGetOnState($g_cb_hD[$i])
	Next
	__GuiToggleButtonSetOnState($g_cb_hEn, $bFlag, True, 0xFFFF00, $COLOR_BLACK, 0xFDFDFD, $COLOR_BLACK, True)


	If __viIsInstrument($g_tc_oDev) And __viIsIdle($g_tc_oDev) Then                                                         ; if TC comm idle then send requests for data
		__F4TreadBg($g_tc_oDev, $g_iF4Tsetpoint, "g_cb_fTset")
		__F4TreadBg($g_tc_oDev, $g_iF4Ttemperature, "g_cb_fTemp")
		__F4TreadBg($g_tc_oDev, $g_iF4Tenable, "g_cb_bTen")
	EndIf
	If __viIsInstrument($g_dc_oDev) And __viIsIdle($g_dc_oDev) Then                                                         ; if DC comm idle then send requests for data
		__viReq($g_dc_oDev, "$g_cb_sD=:OUTPut:STATe? (@1:4)")
	EndIf

EndFunc   ;==>__cbLoop





; --------------------------------------
; ETA functions

Func __cbTetaReset()    ; reset/restart eta calculus
	$g_cb_fEtaTimer = ''
EndFunc   ;==>__cbTetaReset

Func __cbTeta($fTemp)   ; estimate ETA to reach chamber temperature
	If Not IsInt($g_cb_iEtaTimer) Then
		$g_cb_fEtaPrevTemp = $fTemp
		$g_cb_iEtaTimer = TimerInit()
		$g_cb_fEtaPrevVelocity = 0
		Return
	EndIf
	Local $fTarget = Number(StringTrimRight(GUICtrlRead($g_cb_hTset), 2))

	If Abs($fTemp - $fTarget) < 0.5 Then
		If GUICtrlRead($g_cb_hTeta) <> "ok" Then GUICtrlSetData($g_cb_hTeta, "ok")
		Return
	EndIf
	If Abs($fTemp - $g_cb_fEtaPrevTemp) < 0.3 Then Return

	Local $iTimeDiff = TimerDiff($g_cb_iEtaTimer)
	$g_cb_iEtaTimer = TimerInit()

	Local $fFudge = 0.75
	Local $fVelocity = ($fTemp - $g_cb_fEtaPrevTemp) / $iTimeDiff * 1000 * $fFudge      ; delta T per second
	$g_cb_fEtaPrevTemp = $fTemp

	;__ConsolePrintVars("__cbTeta, ", "fTarget", $fTarget, "prevTemp", $g_cb_fEtaPrevTemp, "fTemp", $fTemp)
	;__ConsolePrintVars("__cbTeta, ", "iTimeDiff", $iTimeDiff, "prevVel", $g_cb_fEtaPrevVelocity, "fVel", $fVelocity)

	Local $fAlpha = 0.15
	If $g_cb_fEtaPrevVelocity <> 0 Then $fVelocity = $fAlpha * $fVelocity + (1 - $fAlpha) * $g_cb_fEtaPrevVelocity
	$g_cb_fEtaPrevVelocity = $fVelocity
	Local $iSec = Abs(Int(($fTarget - $fTemp) / $fVelocity))
	Local $iMin = Int($iSec / 60)

	;__ConsolePrintVars("__cbTeta, ", "iTimeDiff", $iTimeDiff, "prevVel", $g_cb_fEtaPrevVelocity, "fVel", $fVelocity, "iEta", $iSec)

	$iSec = Mod($iSec, 60)
	GUICtrlSetData($g_cb_hTeta, ($iMin > 0) ? StringFormat("%i:%02i", $iMin, $iSec) : $iSec)

EndFunc   ;==>__cbTeta




; --------------------------------------
; config file

Global $cb_ConfigSection = "cb"
Global $g_configFile

Func cb_ConfigWrite()
	__IniWriteGuiCheckbox($g_cb_hMon, "monitor", $cb_ConfigSection)
EndFunc   ;==>cb_ConfigWrite

Func cb_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	__IniReadGuiCheckbox($g_cb_hMon, "monitor", $cb_ConfigSection)
EndFunc   ;==>cb_ConfigRead



; --------------------------------------
; --------------------------------------
; --------------------------------------
; --------------------------------------
; --------------------------------------
