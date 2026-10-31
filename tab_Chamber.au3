#include-once

; goal:
; gui input box for setting chamber control
; gui read only text field for real time temperature monitoring (poll every 1-2 seconds)
; set temperature button
; toggle power on/off



#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>


#include "misc.au3"
#include "datatypes.au3"
#include "filemisc.au3"
#include "visascpi.au3"
#include "winmgmt.au3"


Global $g_tc_RefreshInterval = 450

Global $g_tc_hIpAddr, $g_tc_hDevID, $g_tc_oDev
Global $g_tc_bCommValid = False                                 ; IP address and/or communications are valid
Global $g_tc_bInTarget = False                                  ; true if we are within 0.5 degree of setpoint temperature
Global $g_tc_iReadTimer, $g_tc_iTabIdx
Global $g_tc_hT, $g_tc_hTunits, $g_tc_hPowerBtn, _
		$g_tc_hSP, $g_tc_hSPunits, _
		$g_tc_hPlan, $g_tc_hPlanUnits, $g_tc_hTnote, _
		$g_tc_hHeatBar, $g_tc_hCoolBar





; VISA commands for F4T touchscreen Test Equity Themperature Chamber
;Global Const $F4T_VISASETPOINT = ":SOURce:CLOOp1:SPOINT"
;Global Const $F4T_VISAPVALUE = ":SOURce:CLOOp1:PVALUE?"
;Global Const $F4T_VISAOUTPUT1 = ":OUTPut1"
;Global Const $F4T_VISAERRMSG = "ERROR"





; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; initialization functions



Func tcTab_init()
	$g_tc_oDev = tcTab_GetIP()
	LoopRegister("tcTab_Loop")
	$g_tc_iReadTimer = TimerInit()
EndFunc   ;==>tcTab_init



Func tcTab_Loop()
	If TimerDiff($g_tc_iReadTimer) < $g_tc_RefreshInterval Then Return
	$g_tc_iReadTimer = TimerInit()                                                      ; Reset background clock

	If GUICtrlRead($g_cTab) <> $g_tc_iTabIdx Then Return
	If Not $g_tc_bCommValid Then Return

	Local $fRead, $fReadC, $fPrev

	$fReadC = __F4Tsetpoint($g_tc_oDev)                                                 ; read setpoint
	If $fReadC > -1000 Then
		$fRead = $fReadC
		If Not tcTab_GuiGetUnits($g_tc_hSPunits) Then $fRead = __TemperatureCtoF($fReadC)
		$fRead = StringFormat("%.1f", $fRead)
		$fPrev = Number(GUICtrlRead($g_tc_hSP))
		If $fPrev <> $fRead Then GUICtrlSetData($g_tc_hSP, $fRead)                     ; if number changed then update GUI
	EndIf

	tcTab_GuiSetOutputState(__F4Tenable($g_tc_oDev), True)                              ; read the output state and update GUI

	$fRead = __F4Theat($g_tc_oDev)                                                      ; get heat output power
	$fPrev = Number(GUICtrlRead($g_tc_hHeatBar))
	If $fRead <> $fPrev Then
		GUICtrlSetData($g_tc_hHeatBar, $fRead)
		GUICtrlSetTip($g_tc_hHeatBar, StringFormat("%i%%", $fRead))
	EndIf

	$fRead = __F4Tcool($g_tc_oDev)                                                      ; get cooling output power
	$fPrev = Number(GUICtrlRead($g_tc_hHeatBar))
	If $fRead <> $fPrev Then
		GUICtrlSetData($g_tc_hCoolBar, $fRead)
		GUICtrlSetTip($g_tc_hCoolBar, StringFormat("%i%%", $fRead))
	EndIf

	$fReadC = __F4Ttemperature($g_tc_oDev)                                              ; read temperature
	If $fReadC > -1000 Then
		$fRead = $fReadC
		If Not tcTab_GuiGetUnits($g_tc_hTunits) Then $fRead = __TemperatureCtoF($fReadC)
		$fRead = StringFormat("%.1f", $fRead)
		$fPrev = Number(GUICtrlRead($g_tc_hT))
		If $fPrev <> $fRead Then GUICtrlSetData($g_tc_hT, $fRead)                       ; if number changed then update GUI
		; notify user when we reach temperature
		If (GUICtrlRead($g_tc_hTnote) = $GUI_CHECKED) Then
			Local $g_tc_bInTargetNow = (Abs($fPrev - $fRead) <= 0.5)
			If Not ($g_tc_bInTargetNow = $g_tc_bInTarget) Then
				If $g_tc_bInTargetNow Then
					Local $sT = $fRead & " " & (tcTab_GuiGetUnits($g_tc_hTunits) ? $ICON_DEGREEC : $ICON_DEGREEF)
					Local $sS = StringFormat("%.1f", Number(GUICtrlRead($g_tc_hPlan))) & " " & (tcTab_GuiGetUnits($g_tc_hPlanUnits) ? $ICON_DEGREEC : $ICON_DEGREEF)
					MsgBox($MB_OK, "Chamber " & GUICtrlRead($g_tc_hIpAddr), "Temperature setpoint reached" & @CRLF & _
							"Temperature = " & $sT & @CRLF & _
							"Set Point = " & $sS & @CRLF)
				EndIf
				$g_tc_bInTarget = $g_tc_bInTargetNow
			EndIf
		EndIf
	EndIf

EndFunc   ;==>tcTab_Loop






Func tcTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	$g_tc_iTabIdx = $iTabIdx

	Local $x = 10
	Local $y = 5

	GUICtrlCreateLabel("IP Address:", $x, $y + 3, 55, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_tc_hIpAddr = GUICtrlCreateCombo("", $x + 55, $y, 105, 22)
	GUICtrlSetData($g_tc_hIpAddr, "|192.168.0.25", "192.168.0.25")
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_IpAddrChange")
	GUICtrlCreateButton($ICON_SEARCH, $x + 160, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 14, 600)
	GUICtrlSetOnEvent(-1, "tcTab_ScanNetwork")
	GUICtrlSetTip(-1, "Scan subnet 192.168.0.0 for possible VISA devices")
	$y += 25

	GUICtrlCreateLabel("Device:", $x, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_tc_hDevID = GUICtrlCreateInput("", $x + 40, $y, 120, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateButton($ICON_REFRESH, $x + 160, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_IpAddrChange")
	GUICtrlSetTip(-1, "Reconnect to Chamber")
	GUICtrlSetFont(-1, 18, 600)
	$y += 45

	GUICtrlCreateLabel("Temperature:", $x + 5, $y + 3, 80, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_tc_hT = GUICtrlCreateInput("----", $x + 85, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	$g_tc_hTunits = GUICtrlCreateLabel($ICON_DEGREEC, $x + 140, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_ToggleTunits")
	$g_tc_hTnote = GUICtrlCreateCheckbox("", $x + 166, $y, 20, 20)
	GUICtrlSetState(-1, 0)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y += 27

	GUICtrlCreateLabel("Setpoint:", $x + 35, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_tc_hSP = GUICtrlCreateInput("----", $x + 85, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	$g_tc_hSPunits = GUICtrlCreateLabel($ICON_DEGREEC, $x + 140, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_ToggleSetPointUnits")
	$y += 27

	GUICtrlCreateLabel("Plan:", $x + 35, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_tc_hPlan = GUICtrlCreateInput("----", $x + 85, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	$g_tc_hPlanUnits = GUICtrlCreateLabel($ICON_DEGREEC, $x + 140, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_TogglePlanUnits")

	GUICtrlCreateButton($ICON_CHECK, $x + 160, $y - 3, 25, 25, BitOR($GUI_SS_DEFAULT_INPUT, $BS_DEFPUSHBUTTON))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_SetTemperature")
	GUICtrlSetFont(-1, 11, 600)


	$g_tc_hPowerBtn = GUICtrlCreateButton("Off", $x, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "tcTab_OnToggleOutputState")
	GUICtrlSetTip(-1, "Toggle Chamber Compressor/output on/off." & @CRLF & "Click here then wait one second to confirm it took effect.")
	$y += 25


	; Create Heat Progress Bar (Solid Red, No Animation)
	$g_tc_hHeatBar = GUICtrlCreateProgress($x + 90, $y, 90, 12, $PBS_SMOOTH)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetData(-1, 0)
	DllCall("uxtheme.dll", "long", "SetWindowTheme", "hwnd", GUICtrlGetHandle($g_tc_hHeatBar), "wstr", "", "wstr", "")
	GUICtrlSetColor($g_tc_hHeatBar, 0xDF3A25)                                     ; Set to Solid Red
	GUICtrlSetBkColor($g_tc_hHeatBar, 0xEAEAEA)                                   ; Light Gray Background

	; Create Cool Progress Bar (Solid Blue, No Animation)
	$g_tc_hCoolBar = GUICtrlCreateProgress($x, $y, 90, 12, $PBS_SMOOTH)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetData(-1, 0)
	DllCall("uxtheme.dll", "long", "SetWindowTheme", "hwnd", GUICtrlGetHandle($g_tc_hCoolBar), "wstr", "", "wstr", "")
	GUICtrlSetColor($g_tc_hCoolBar, 0x2A75D3)                                     ; Set to Solid Blue
	GUICtrlSetBkColor($g_tc_hCoolBar, 0xEAEAEA)                                   ; Light Gray Background
	GUICtrlSetStyle($g_tc_hCoolBar, $PBS_SMOOTH, $WS_EX_LAYOUTRTL)
	$y += 15


	Local $a[] = [200, $y]
	Return $a
EndFunc   ;==>tcTab_GuiCreate






; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------


; ip address and connection


Func tcTab_GetIP()
	Return "raw:" & __viGUIGetIP($g_tc_hIpAddr)
EndFunc   ;==>tcTab_GetIP


Func tcTab_GetID()                                          ; read ID from VISA device
	_GUICtrlComboBox_SetEditSel($g_tc_hIpAddr, 0, 0)
	GUICtrlSetData($g_tc_hDevID, "Checking...")
	$g_tc_oDev = "raw:" & __viGUIGetIP($g_tc_hIpAddr)
	Local $sId = __F4TgetID($g_tc_oDev)
	__viGUISetID($g_tc_hDevID, ($sId = '') ? 'Not Found' : $sId)
	$g_tc_bCommValid = Not ($sId = "")
	Return $sId
EndFunc   ;==>tcTab_GetID


Func tcTab_FellOffline()
	$g_tc_bCommValid = False
	GUICtrlSetData($g_tc_hT, "")
	GUICtrlSetData($g_tc_hSP, "")
	tcTab_GuiSetOutputState(False, True)
	GUICtrlSetData($g_tc_hDevID, "")                        ; show user that we have lost communications
EndFunc   ;==>tcTab_FellOffline



; IP address

Func tcTab_IpAddrChange()                                   ; user updated IP address
	GUICtrlSetData($g_tc_hT, "---")
	GUICtrlSetData($g_tc_hSP, "---")
	tcTab_GuiSetOutputState(False, True)
	tcTab_GetID()                                           ; check if VISA device responds to IP address
	If $g_tc_bCommValid Then tcTab_ConfigWrite()            ; if ok then save config
EndFunc   ;==>tcTab_IpAddrChange

Func tcTab_ScanNetwork()
	__viScanSubnet()
	;__viScanSubnet("192.168.0.0", $g_tc_hIpAddr, "Thermal Chamber")
EndFunc   ;==>tcTab_ScanNetwork







; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; -----------------  GUI event handler functions




; Tempeature units

Func tcTab_GuiGetUnits($hLbl)                                                       ; return true if unit label is C or false if F
	Return (GUICtrlRead($hLbl) = $ICON_DEGREEC) + 0                                 ; return 1 or 0 instead of True / False
EndFunc   ;==>tcTab_GuiGetUnits

Func tcTab_GuiSetUnits($hLbl, $bUnits = 1)                                          ; update the GUI units field with deg C or deg F
	GUICtrlSetData($hLbl, (($bUnits + 0) <> 0) ? $ICON_DEGREEC : $ICON_DEGREEF)
EndFunc   ;==>tcTab_GuiSetUnits

Func tcTab_ToggleTunits()                                                           ; switch between C and F
	tcTab_GuiSetUnits($g_tc_hTunits, 1 - tcTab_GuiGetUnits($g_tc_hTunits))
EndFunc   ;==>tcTab_ToggleTunits

Func tcTab_TogglePlanUnits()                                                        ; switch between C and F
	tcTab_GuiSetUnits($g_tc_hPlanUnits, 1 - tcTab_GuiGetUnits($g_tc_hPlanUnits))
EndFunc   ;==>tcTab_TogglePlanUnits

Func tcTab_ToggleSetPointUnits()                                                    ; switch between C and F
	tcTab_GuiSetUnits($g_tc_hSPunits, 1 - tcTab_GuiGetUnits($g_tc_hSPunits))
EndFunc   ;==>tcTab_ToggleSetPointUnits




Func tcTab_SetTemperature()     ; temperature setpoint
	Local $fSP = Round(Number(GUICtrlRead($g_tc_hPlan)), 2)
	;$fSP = InputBox("Set Temperature", "SetPoint", $fSP, "", 200, 120)
	If ($fSP = "") Or (Not StringIsFloat($fSP) And Not StringIsInt($fSP)) Then Return
	If Not tcTab_GuiGetUnits($g_tc_hPlanUnits) Then $fSP = __TemperatureFtoC($fSP)
	$fSP = Number(StringFormat("%.1f", $fSP))
	__F4Tsetpoint($g_tc_oDev, $fSP)
EndFunc   ;==>tcTab_SetTemperature





; chamber output state - on/off

Func tcTab_GuiSetOutputState($bState, $bSelf = True, $cBtn = $g_tc_hPowerBtn)
	__GuiToggleButtonSetOnState($cBtn, $bState, $bSelf, 0xFFFF00, $COLOR_BLACK, 0xFDFDFD, $COLOR_BLACK, True)
	;GUICtrlSetBkColor($cBtn, $bState ? 0xFFFF00 : 0xFDFDFD)
	;GUICtrlSetData($cBtn, $bState ? "On" : "Off")
EndFunc   ;==>tcTab_GuiSetOutputState

Func tcTab_GuiGetOutputState($cBtn = $g_tc_hPowerBtn)
	Return (GUICtrlRead($cBtn) = "On")
EndFunc   ;==>tcTab_GuiGetOutputState

Func tcTab_OnToggleOutputState()
	tcTab_ToggleOutputState()
EndFunc   ;==>tcTab_OnToggleOutputState
Func tcTab_ToggleOutputState($cBtn = $g_tc_hPowerBtn)
	Local $bEn = Not tcTab_GuiGetOutputState($cBtn)
	__F4Tenable($g_tc_oDev, $bEn)
	tcTab_GuiSetOutputState($bEn, True, $cBtn)
EndFunc   ;==>tcTab_ToggleOutputState







; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; ---------------------- config file functions



Global $tcTab_ConfigSection = "Chamber"
Global $g_configFile



Func tcTab_ConfigWrite()
;__ConsolePrintVars("tcTab_ConfigWrite, ","hIpAddr",$g_tc_hIpAddr,"configSection",$tcTab_ConfigSection)

	__viSaveIP($g_tc_hIpAddr, $tcTab_ConfigSection)
	IniWrite($g_configFile, $tcTab_ConfigSection, "TemperatureUnits", tcTab_GuiGetUnits($g_tc_hTunits))
	IniWrite($g_configFile, $tcTab_ConfigSection, "SetPoint", GUICtrlRead($g_tc_hPlan))                               ; temperature set point
	IniWrite($g_configFile, $tcTab_ConfigSection, "SetPointUnits", tcTab_GuiGetUnits($g_tc_hPlanUnits))
	__IniWriteGuiCheckbox($g_tc_hTnote, "Tnotify", $tcTab_ConfigSection)                                            ; notify checkbox
EndFunc   ;==>tcTab_ConfigWrite



Func tcTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	Local $j, $s
	__viLoadIP($g_tc_hIpAddr, $tcTab_ConfigSection)
	GUICtrlSetData($g_tc_hPlan, IniRead($g_configFile, $tcTab_ConfigSection, "SetPoint", GUICtrlRead($g_tc_hPlan)))     ; temperature set point
	__IniReadGuiCheckbox($g_tc_hTnote, "Tnotify", $tcTab_ConfigSection)                                             ; notify checkbox
	tcTab_GuiSetUnits($g_tc_hTunits, _
			IniRead($g_configFile, $tcTab_ConfigSection, "TemperatureUnits", tcTab_GuiGetUnits($g_tc_hTunits)))     ; temperature units
	tcTab_GuiSetUnits($g_tc_hPlanUnits, _
			IniRead($g_configFile, $tcTab_ConfigSection, "SetPointUnits", tcTab_GuiGetUnits($g_tc_hPlanUnits)))       ; setpoint units
	tcTab_GetID()
EndFunc   ;==>tcTab_ConfigRead








