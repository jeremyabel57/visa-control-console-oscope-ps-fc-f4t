
#include-once

#include "tab_Chamber.au3"
#include "tab_DC_Power_Supply.au3"


#include <AutoItConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <WindowsConstants.au3>
#include <WinAPISys.au3>



Global $g_cb_hD[4], $g_cb_hDup, $g_cb_hDdn                      ; DC PS controls
Global $g_cb_sD ; $g_cb_bD[4], $g_cb_sD                         ;
Global $g_cb_hTemp, $g_cb_hTset, $g_cb_hTen, $g_cb_hTeta        ; chamber controls
Global $g_cb_fTemp, $g_cb_fTset, $g_cb_bTen                     ;
Global $g_cb_hEn                                                ; global on/off button
Global $g_cb_iReadTimer, $g_cb_iRefreshInterval = 250           ;
Global $g_cb_hMon                                               ; checkbox to enable or disable monitoring of the devices
Global $g_cb_iEtaTimer = '', $g_cb_fEtaPrevTemp, _              ; calculating eta to reach target temperature
		$g_cb_fEtaPrevVelocity

Global $g_oMainCanvas



Func CreateControlBar($iX, $iY, $iW, $iH)

	Local $iWbtn = 25                                                                                                       ; on/off button width
	Local $iWbtn2 = 40                                                                                                      ; up/down button width
	Local $iWbtn3 = 60                                                                                                      ; dc on/off buttons width
	Local $iWt = 45                                                                                                         ; width of temperature or eta field
	Local $iWs1 = 2                                                                                                         ; space between buttons and fields
	Local $iWs2 = 20                                                                                                        ; space between groups
	Local $lbl1, $lbl2, $lbl3, $i, $n

	Local $x = $iX + 15

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
	$g_cb_hD[0] = GUICtrlCreateButton("Off", $x, $iY, $iWbtn3, $iH)                                                         ; dc channel 1 on/off
	GUICtrlSetOnEvent(-1, "__cbDCd")
	$x += $iWbtn3 + $iWs1
	$g_cb_hD[1] = GUICtrlCreateButton("Off", $x, $iY, $iWbtn3, $iH)                                                         ; dc channel 2 on/off
	GUICtrlSetOnEvent(-1, "__cbDCd")
	$x += $iWbtn3 + $iWs1
	$g_cb_hD[2] = GUICtrlCreateButton("Off", $x, $iY, $iWbtn3, $iH)                                                         ; dc channel 3 on/off
	GUICtrlSetOnEvent(-1, "__cbDCd")
	$x += $iWbtn3 + $iWs1
	$g_cb_hD[3] = GUICtrlCreateButton("Off", $x, $iY, $iWbtn3, $iH)                                                         ; dc channel 4 on/off
	GUICtrlSetOnEvent(-1, "__cbDCd")
	$x += $iWbtn3 + $iWs2

	; all on/off button
	$g_cb_hEn = GUICtrlCreateButton("Off", $x, $iY, $iWbtn, $iH)                                                            ; chamber and all DC power rails on/off button.  off: dc down followed by all ch off, and chamber off.  on: dc up, chamber on
	GUICtrlSetOnEvent(-1, "__cbEn")
	$x += $iWbtn

	; add controls to aCtrls so they get scaled with ctrl+mousewheel
	Local $a[] = [$g_cb_hMon, $lbl1, $g_cb_hTemp, $lbl2, $g_cb_hTset, $lbl3, $g_cb_hTeta, $g_cb_hTen, $g_cb_hDup, $g_cb_hDdn, $g_cb_hD[0], $g_cb_hD[1], $g_cb_hD[2], $g_cb_hD[3], $g_cb_hEn]
	Local $aCtrls[0]
	If $g_oMainCanvas.Exists('aCtrls') Then $aCtrls = $g_oMainCanvas.Item('aCtrls')
	Local $i, $n = UBound($a) - 1, $m = UBound($aCtrls)
	ReDim $aCtrls[$m + $n + 1]
	Local $mydock = BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE)
	For $i = 0 To $n
		GUICtrlSetResizing($a[$i], $mydock)
		$aCtrls[$m + $i] = $a[$i]
	Next
	$g_oMainCanvas.Item('aCtrls') = $aCtrls

EndFunc   ;==>CreateControlBar

Func ControlBar_Init()
	;_GUIRegisterMsg($WM_COMMAND, "__cb_WM_COMMAND") ; no longer needed
	Local $i                                                                                                                ; copy labels from DC PS to buttons on control bar
	For $i = 0 To 3
		GUICtrlSetData($g_cb_hD[$i], GUICtrlRead($g_dc_lbl[$i]))
	Next
	$g_cb_iReadTimer = TimerInit()                                                                                          ; Reset background clock
	LoopRegister("__cbLoop")
EndFunc   ;==>ControlBar_Init


;



; next: work on debug tab.  key to main visa queue only.
; for each device, pull their queue from the global variables directly (g_dc_oDev, g_fc_oDev...).  update each one to use global variable for the oDev object.
; make a function that returns the oDev pointer for a given item "tc/fc/dc/sc" and makes sure it is connected or at least attempted to connect.  if not connecting then
; possibly look at the aDevs array for its IP and try again.

; next: on startup see if you can skip many of the getID routines.  __viGetID - also do a ping to see if the IP address is offline before spending timeout with visa IDN command
;


; gui event handlers
;


Func __cbTCen()
	If $g_tc_bCommValid Then tcTab_ToggleOutputState($g_cb_hTen)
EndFunc   ;==>__cbTCen


Func __cbDCd()
	Local $j
	Switch @GUI_CtrlId
		Case $g_cb_hD[0]
			$j = 1
		Case $g_cb_hD[1]
			$j = 2
		Case $g_cb_hD[2]
			$j = 3
		Case $g_cb_hD[3]
			$j = 4
	EndSwitch
	Local $bState = dcTab_GuiGetOnState($j, @GUI_CtrlId)            ; grab state from gui button
	$bState = Not $bState                                           ; toggle state
	__dcps_SetStateBg($g_dc_oDev, $j, $bState)                      ; send visa command to set new output state
	dcTab_GuiSetOnState($j, $bState, True, @GUI_CtrlId, False)      ; update gui button
EndFunc   ;==>__cbDCd


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
		Local $i, $aRead = StringSplit($g_cb_sD, ",")
		If $aRead[0] >= 4 Then
			For $i = 1 To 4
				dcTab_GuiSetOnState($i, Int($aRead[$i]) <> 0, False, $g_cb_hD, False)
			Next
		EndIf
		$g_cb_sD = ''
	EndIf


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
; gui functions


#cs
Func __cb_WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)                        ; hook for when temperature setpoint field gets focus (clicked on)
	If $hWnd <> $g_hMainGui Then Return
	Local $nNotifyCode = BitShift($wParam, 16)                              ; Get the notification code
	Local $nID = BitAND($wParam, 0xFFFF)                                    ; Get the Control ID
	If $nID = $g_cb_hTset And $nNotifyCode = $EN_SETFOCUS Then __cbSetTC()  ; if the Tset/SP field gets focus (user clicked on it) then ask what temperature they want
	Return $GUI_RUNDEFMSG                                                   ; Pass control back to AutoIt's internal systems
EndFunc   ;==>__cb_WM_COMMAND
#ce



Func __cbSetTC()        ; set thermal chamber temperature setpoint
	Local $fSP = Round(Number(GUICtrlRead($g_cb_hTset)), 1)
	$fSP = StringStripWS(InputBox("Chamber Temperature", "SetPoint", $fSP, "", 200, 120), 3)
	If StringInStr(StringLower(StringRight($fSP, 1)), "cf") Then $fSP = StringStripWS(StringTrimRight($fSP, 1), 3)
	If ($fSP = "") Or (Not StringIsFloat($fSP) And Not StringIsInt($fSP)) Then Return
	$fSP = Round(Number($fSP), 1)
	;__ConsolePrintVars("__cbSetTC, ", "fSP", $fSP)
	__F4Tsetpoint($fSP)
	__cbTetaReset()
EndFunc   ;==>__cbSetTC



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


