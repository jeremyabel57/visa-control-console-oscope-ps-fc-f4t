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
#include "visascpi.au3"



Global $g_chamber_hIpAddr, $g_chamber_hDevID
Global $g_chamber_bCommValid = 0                                    ; IP address and/or communications are valid
Global $g_chamber_bInTarget = 0                                     ; true if we are within 0.5 degree of setpoint temperature
Global $g_chamber_iReadIndex = -1, $g_chamber_iReadTimer
Global $g_chamber_hT, $g_chamber_hTunits, $g_chamber_hPowerBtn, _
		$g_chamber_hSP, $g_chamber_hSPunits, $g_chamber_hTnote      ;





; VISA commands for F4T touchscreen Test Equity Themperature Chamber
Global Const $F4T_VISASETPOINT = ":SOURce:CLOOp1:SPOINT"
Global Const $F4T_VISAIDN = "*IDN?"
Global Const $F4T_VISAPVALUE = ":SOURce:CLOOp1:PVALUE?"
Global Const $F4T_VISAOUTPUT1 = ":OUTPut1"
Global Const $F4T_VISAERRMSG = "ERROR"



; F4T touchscreen Test Equity Thermal Chamber
; DataMap 1 (float32)
Global Const $F4T_REG_SETPOINT1 = 2782      ; Static Temperature Setpoint (SP)
Global Const $F4T_REG_TEMP1 = 27586         ; Actual Chamber Temperature (PV)
Global Const $F4T_REG_ENABLE1 = 16594       ; (int16) Control Mode (63 = On, 62 = Off)
;Global Const $F4T_REG_HEAT1 = 2812          ; current heat power output 0.0 - 100.0%
;Global Const $F4T_REG_COOL1 = 2814          ; current cooling power output 0.0 - 100.0%
;Global Const $F4T_REG_ALARM1R = 2732        ; (int16) alarm
;Global Const $F4T_REG_ALARM1W = 2768        ; (int16) clear alarm
; DataMap 2 (legacy)
Global Const $F4T_REG_SETPOINT2 = 300       ; setpoint, 16 bit signed int = temperature * 10
Global Const $F4T_REG_TEMP2 = 100           ; process temperature, 16 bit signed int = temperature * 10
Global Const $F4T_REG_ENABLE2 = 2000        ; output on/off control (1=on, 0=off)
;Global Const $F4T_REG_POWER2 = 106          ; heat/cool power, 16 bit signed int = +/-1000 = percentage*10.  negative = cool, positive=heat
;Global Const $F4T_REG_ALARM2R = 1200        ; read alarm code register
;Global Const $F4T_REG_ALARM2W = 1201        ; clear alarm code register






; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; initialization functions



Func chamberTab_init()
	chamberTab_ConfigRead()                                         ; read config file and update settings
	$g_chamber_iReadIndex = TimerInit()
	;??? LoopRegister("chamberTab_Loop")
EndFunc   ;==>chamberTab_init



Func chamberTab_Loop()

	; 2. Non-blocking Background Hardware Polling
	If (Not ($g_chamber_bCommValid = 0)) And TimerDiff($g_chamber_iReadTimer) >= 900 Then
		$g_chamber_iReadIndex = Mod($g_chamber_iReadIndex + 1, 3)
		Local $fRead, $fReadC, $fPrev
		;MsgBox(0, "hi", "iReadIndex=" & $g_chamber_iReadIndex & @CRLF)

		Switch $g_chamber_iReadIndex
			Case 0
				;*		MsgBox(0, "hi", "hi")
				;ConsoleWrite("iReadIndex: __F4T_GetTepmerature().  valid=" & $g_chamber_bCommValid & @CRLF)
				;??? $fReadC = Number(__F4T_GetTemperature())                        ; read temperature
				;ConsoleWrite("iReadIndex: __F4T_GetTepmerature().  valid=" & $g_chamber_bCommValid & ",  fReadC=" & $fReadC & @CRLF)
				If $fReadC > -1000 Then
					$fRead = $fReadC
					If Not chamberTab_GuiGetUnits($g_chamber_hTunits) Then $fRead = __TemperatureCtoF($fReadC)
					$fRead = StringFormat("%.1f", $fRead)
					$fPrev = Number(GUICtrlRead($g_chamber_hT))
					If $fPrev <> $fRead Then GUICtrlSetData($g_chamber_hT, $fRead)        ; if number changed then update GUI
					; notify user when we reach temperature
					If (GUICtrlRead($g_chamber_hTnote) = $GUI_CHECKED) Then
						Local $g_chamber_bInTargetNow = (Abs($fPrev - $fRead) <= 0.5) ? 1 : 0
						If Not ($g_chamber_bInTargetNow = $g_chamber_bInTarget) Then
							If $g_chamber_bInTargetNow Then
								Local $sT = $fRead & " " & (chamberTab_GuiGetUnits($g_chamber_hTunits) ? $ICON_DEGREEC : $ICON_DEGREEF)
								Local $sS = StringFormat("%.1f", Number(GUICtrlRead($g_chamber_hSP))) & " " & (chamberTab_GuiGetUnits($g_chamber_hSPunits) ? $ICON_DEGREEC : $ICON_DEGREEF)
								MsgBox($MB_OK, "Chamber " & GUICtrlRead($g_chamber_hIpAddr), "Setpoint temperature reached" & @CRLF & _
										"Temperature = " & $sT & @CRLF & _
										"Set Point = " & $sS & @CRLF)
							EndIf
							$g_chamber_bInTarget = $g_chamber_bInTargetNow
						EndIf
					EndIf

				EndIf
			Case 1
				;??? $fReadC = Number(__F4T_GetSetpoint())                            ; read setpoint
				If $fReadC > -1000 Then
					$fRead = $fReadC
					If Not chamberTab_GuiGetUnits($g_chamber_hSPunits) Then $fRead = __TemperatureCtoF($fReadC)
					$fRead = StringFormat("%.1f", $fRead)
					$fPrev = Number(GUICtrlRead($g_chamber_hSP))
					If $fPrev <> $fRead Then GUICtrlSetData($g_chamber_hSP, $fRead)        ; if number changed then update GUI
				EndIf
			Case 2
				;??? chamberTab_UpdateOutputState(__F4T_GetEnable())                            ; read the output state and update GUI
		EndSwitch



		$g_chamber_iReadTimer = TimerInit() ; Reset background clock
	EndIf

EndFunc   ;==>chamberTab_Loop






Func chamberTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	$g_chamber_iTabIdx = $iTabIdx

	Local $y = 5

	GUICtrlCreateLabel("IP Address:", 10, $y + 3, 55, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_chamber_hIpAddr = GUICtrlCreateCombo("", 65, $y, 105, 22)
	GUICtrlSetData($g_chamber_hIpAddr, "|192.168.0.25", "192.168.0.25")
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "chamberTab_IpAddrChange")
	GUICtrlCreateButton($ICON_SEARCH, 170, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 14)
	GUICtrlSetOnEvent(-1, "chamberTab_ScanNetwork")
	GUICtrlSetTip(-1, "Scan subnet 192.168.0.0 for possible VISA devices")

	$y = $y + 25
	GUICtrlCreateLabel("Device:", 10, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_chamber_hDevID = GUICtrlCreateInput("", 50, $y, 120, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateButton($ICON_REFRESH, 170, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "chamberTab_IpAddrChange")
	GUICtrlSetTip(-1, "Reconnect to Chamber")
	GUICtrlSetFont(-1, 18, 600)

	$y = $y + 45
	GUICtrlCreateLabel("Temperature:", 15, $y + 3, 80, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_chamber_hT = GUICtrlCreateInput("----", 95, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	$g_chamber_hTunits = GUICtrlCreateLabel($ICON_DEGREEC, 150, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "chamberTab_ToggleTunits")
	$g_chamber_hTnote = GUICtrlCreateCheckbox("", 176, $y, 20, 20)
	GUICtrlSetState(-1, 0)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$y = $y + 27
	GUICtrlCreateLabel("Set Point:", 45, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_chamber_hSP = GUICtrlCreateInput("----", 95, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	$g_chamber_hSPunits = GUICtrlCreateLabel($ICON_DEGREEC, 150, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "chamberTab_ToggleSetPointUnits")
	GUICtrlCreateButton($ICON_CFG, 170, $y - 3, 25, 25, BitOR($GUI_SS_DEFAULT_INPUT, $BS_DEFPUSHBUTTON))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "chamberTab_ChangeSetPoint")
	GUICtrlSetFont(-1, 11, 600)


	$g_chamber_hPowerBtn = GUICtrlCreateButton($ICON_POWERBTN, 10, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "chamberTab_PowerBtnClick")
	GUICtrlSetTip(-1, "Toggle Chamber Compressor/output on/off." & @CRLF & "Click here then wait one second to confirm it took effect.")

	Local $a[] = [200, 140]
	Return $a
EndFunc   ;==>chamberTab_GuiCreate




; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------


; ---------------- Read Data from chamber functions


Func chamberTab_GetIP()
	Return "raw:" & __viGetIP($g_chamber_hIpAddr)
EndFunc   ;==>chamberTab_GetIP


Func chamberTab_GetID()                             ; read ID from VISA device
	Local $sId = __viGUIGetID($g_chamber_hDevID, $g_chamber_hIpAddr, "raw:")
	$g_chamber_bCommValid = Not ($sId = "")
	Return $sId
EndFunc   ;==>chamberTab_GetID


Func chamberTab_FellOffline()
	$g_chamber_bCommValid = 0
	GUICtrlSetData($g_chamber_hT, "")
	GUICtrlSetData($g_chamber_hSP, "")
	chamberTab_UpdateOutputState(0)
	GUICtrlSetData($g_chamber_hDevID, "")                                   ; show user that we have lost communications
EndFunc   ;==>chamberTab_FellOffline







; -----------------  GUI event handler functions



Func chamberTab_GuiGetUnits($hLbl)            ; return true if unit label is C or false if F
	Return (GUICtrlRead($hLbl) = $ICON_DEGREEC) + 0            ; return 1 or 0 instead of True / False
EndFunc   ;==>chamberTab_GuiGetUnits



Func chamberTab_GuiSetUnits($hLbl, $bUnits = 1)    ; update the GUI units field with deg C or deg F
	GUICtrlSetData($hLbl, (($bUnits + 0) <> 0) ? $ICON_DEGREEC : $ICON_DEGREEF)
EndFunc   ;==>chamberTab_GuiSetUnits



Func chamberTab_ToggleTunits()                                                            ; switch between C and F
	chamberTab_GuiSetUnits($g_chamber_hTunits, 1 - chamberTab_GuiGetUnits($g_chamber_hTunits))
EndFunc   ;==>chamberTab_ToggleTunits



Func chamberTab_IpAddrChange()                            ; user updated IP address
	GUICtrlSetData($g_chamber_hT, "---")
	GUICtrlSetData($g_chamber_hSP, "---")
	chamberTab_UpdateOutputState(0)
	chamberTab_GetID()                                    ; check if VISA device responds to IP address
	If $g_chamber_bCommValid Then chamberTab_ConfigWrite()          ; if ok then save config
EndFunc   ;==>chamberTab_IpAddrChange



Func chamberTab_ToggleSetPointUnits()                                                    ; switch between C and F
	chamberTab_GuiSetUnits($g_chamber_hSPunits, 1 - chamberTab_GuiGetUnits($g_chamber_hSPunits))
EndFunc   ;==>chamberTab_ToggleSetPointUnits



Func chamberTab_UpdateSetPoint($nSP)                    ; update the displayed setpoint in the gui
	If Not ($nSP == "") And (Not StringInStr($nSP, $F4T_VISAERRMSG)) Then
		If Not chamberTab_GuiGetUnits($g_chamber_hSPunits) Then $nSP = __TemperatureCtoF($nSP)
		$nSP = StringFormat("%.1f", $nSP)
	EndIf
	GUICtrlSetData($g_chamber_hSP, $nSP)
EndFunc   ;==>chamberTab_UpdateSetPoint



Func chamberTab_ChangeSetPoint()
	Local $iSP = Round(Number(GUICtrlRead($g_chamber_hSP)), 2)
	$iSP = InputBox("Set temperature set point", "SetPoint", $iSP, "", 200, 120)
	If ($iSP = "") Or (Not StringIsFloat($iSP) And Not StringIsInt($iSP)) Then Return
	If Not chamberTab_GuiGetUnits($g_chamber_hSPunits) Then $iSP = __TemperatureFtoC($iSP)
	$iSP = StringFormat("%.1f", $iSP)

	;	Local $aSession[$_MBsize]
	;	$aSession[$_MBipAddr] = GUICtrlRead($g_chamber_hIpAddr)
	;	__F4T_writeSetpoint($aSession, $iSP)
	;	__mbClose($aSession)
EndFunc   ;==>chamberTab_ChangeSetPoint


Func chamberTab_GetOutputState($s = "")                        ; get the current output/power state of the VISA device
	Return (($s = "AUT") Or ($s = "MAN") Or ($s = "ON") Or (Number($s) = 1)) + 0
EndFunc   ;==>chamberTab_GetOutputState



Func chamberTab_UpdateOutputState($sState)
	$sState = chamberTab_GetOutputState(StringUpper(StringLeft(StringStripWS($sState, 3), 3)))
	GUICtrlSetBkColor($g_chamber_hPowerBtn, $sState ? 0xFFFF00 : 0xFDFDFD)
	GUICtrlSetData($g_chamber_hPowerBtn, $sState ? "On" : "Off")
EndFunc   ;==>chamberTab_UpdateOutputState



Func chamberTab_GetGuiOutputState()
	Return (GUICtrlRead($g_chamber_hPowerBtn) = "On") + 0
EndFunc   ;==>chamberTab_GetGuiOutputState



Func chamberTab_PowerBtnClick()
	Local $bState = 1 - chamberTab_GetGuiOutputState()
	;	Local $aSession[$_MBsize]
	;	$aSession[$_MBipAddr] = GUICtrlRead($g_chamber_hIpAddr)
	;	__F4T_writeEnable($aSession, $bState)
	;	__mbClose($aSession)
	chamberTab_UpdateOutputState($bState)
EndFunc   ;==>chamberTab_PowerBtnClick



Func chamberTab_ScanNetwork()
	__viScanSubnet("192.168.0.0", $g_chamber_hIpAddr, "Thermal Chamber")
EndFunc   ;==>chamberTab_ScanNetwork







; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; ---------------------- config file functions



Global $chamberTab_ConfigSection = "Chamber"
Global $g_configFile



Func chamberTab_ConfigWrite()
	__viSaveIP($g_chamber_hIpAddr, $chamberTab_ConfigSection)
	IniWrite($g_configFile, $chamberTab_ConfigSection, "TemperatureUnits", chamberTab_GuiGetUnits($g_chamber_hTunits))
	IniWrite($g_configFile, $chamberTab_ConfigSection, "SetPoint", GUICtrlRead($g_chamber_hSP))                          ; temperature set point
	IniWrite($g_configFile, $chamberTab_ConfigSection, "SetPointUnits", chamberTab_GuiGetUnits($g_chamber_hSPunits))
	IniWrite($g_configFile, $chamberTab_ConfigSection, "Tnotify", (GUICtrlRead($g_chamber_hTnote) = $GUI_CHECKED) + 0)   ; notify checkbox
EndFunc   ;==>chamberTab_ConfigWrite



Func chamberTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	Local $j, $s
	__viLoadIP($g_chamber_hIpAddr, $chamberTab_ConfigSection)
	GUICtrlSetData($g_chamber_hSP, IniRead($g_configFile, $chamberTab_ConfigSection, "SetPoint", GUICtrlRead($g_chamber_hSP)))       ; temperature set point
	GUICtrlSetState($g_chamber_hTnote, _
			Number(IniRead($g_configFile, $chamberTab_ConfigSection, "Tnotify", (GUICtrlRead($g_chamber_hTnote) = $GUI_CHECKED))) _
			 ? $GUI_CHECKED : $GUI_UNCHECKED)                                                                           ; notify checkbox
	chamberTab_GuiSetUnits($g_chamber_hTunits, _
			IniRead($g_configFile, $chamberTab_ConfigSection, "TemperatureUnits", chamberTab_GuiGetUnits($g_chamber_hTunits)))       ; temperature units
	chamberTab_GuiSetUnits($g_chamber_hSPunits, _
			IniRead($g_configFile, $chamberTab_ConfigSection, "SetPointUnits", chamberTab_GuiGetUnits($g_chamber_hSPunits)))         ; setpoint units
	chamberTab_GetID()
EndFunc   ;==>chamberTab_ConfigRead








#cs
;--------------------------------------------
; Test Equity F4T thermal chamber modbus functions
;





Func __F4T_GetTemperature($mbSession = GUICtrlRead($hIpAddr))
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1000)
	Local $sR = __F4T_readTemp($mbSession)                         ; process temperature
	Local $iErr = @error
	__mbF4Tend($mbSession)
	If $iErr Then Return SetError($iErr, 0, -1000)
	If $sR = "" Then Return SetError(-1, 0, -1000)
	Return Number($sR)
EndFunc   ;==>__F4T_GetTemperature



Func __F4T_GetSetpoint($mbSession = GUICtrlRead($hIpAddr))
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1000)
	Local $sR = __F4T_readSetpoint($mbSession)                         ; setpoint temperature
	Local $iErr = @error
	__mbF4Tend($mbSession)
	If $iErr Then Return SetError($iErr, 0, -1000)
	If $sR = "" Then Return SetError(-1, 0, -1000)
	Return Number($sR)
EndFunc   ;==>__F4T_GetSetpoint



Func __F4T_GetEnable($mbSession = GUICtrlRead($hIpAddr))
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1000)
	Local $sR = __F4T_readEnable($mbSession)                         ; is the chamber temperature regulation enabled/engaged/on?
	Local $iErr = @error
	__mbF4Tend($mbSession)
	If $iErr Then Return SetError($iErr, 0, -1000)
	If $sR = "" Then Return SetError(-1, 0, -1000)
	Return Number($sR)
EndFunc   ;==>__F4T_GetEnable




;			__F4T_readEnable
; task:		read the output control (0=off, 1=on)
; in:		$mbSession = modbus session handle
; out:		0=off, 1=on
Func __F4T_readEnable(ByRef $mbSession)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Local $r = __mbReadInt16($mbSession, $F4T_REG_ENABLE1)
		Return (Int($r) = 63) ? 1 : 0 ; Returns 1 if value is (63)
	Else
		Return __mbReadInt16($mbSession, $F4T_REG_ENABLE2)
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_readEnable



;			__F4T_writeEnable
; task:		set the output control (0=off, 1=on)
; in:		$mbSession = modbus session handle
; 			$iValue = 0=off, 1=on
Func __F4T_writeEnable(ByRef $mbSession, $iValue)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbWriteInt16($mbSession, $F4T_REG_ENABLE1, (Number($iValue) = 0) ? 62 : 63)
	Else
		Return __mbWriteInt16($mbSession, $F4T_REG_ENABLE2, (Number($iValue) = 0) ? 0 : 1)
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_writeEnable





;			__F4T_readSetpoint
; task:		read the setpoint temperature of the chamber
; in:		$mbSession = modbus session handle
; out:		chamber temperature in C
Func __F4T_readSetpoint(ByRef $mbSession)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbReadFloat32($mbSession, $F4T_REG_SETPOINT1)
	Else
		Return __mbReadInt16($mbSession, $F4T_REG_SETPOINT2) / 10
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_readSetpoint



;			__F4T_writeSetpoint
; task:		change the setpoint temperature of the chamber
; in:		$mbSession = modbus session handle
;			$nValue = new temperature setpoint
; out:		chamber temperature in C
Func __F4T_writeSetpoint(ByRef $mbSession, $nValue)
	;_ArrayDisplay($aSession)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbWriteVerify($mbSession, $F4T_REG_SETPOINT1, $nValue, "32f")
	Else
		Return __mbWriteVerify($mbSession, $F4T_REG_SETPOINT2, Int($nValue * 10), "16i")
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_writeSetpoint





; -----------------------------





;			__F4T_readTemp
; task:		read the current temperature of the chamber
; in:		$mbSession = modbus session handle
; out:		chamber temperature in C
Func __F4T_readTemp(ByRef $mbSession, $iTimeoutMS = 2000)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbReadFloat32($mbSession, $F4T_REG_TEMP1)
	Else
		Return __mbReadInt16($mbSession, $F4T_REG_TEMP2) / 10
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_readTemp



;			__F4T_read
; task:		read a register from F4T chamber
;			if dataMap=1 then read 32 bit float
;			else read 16 bit int and divide by 10
; in:		$mbSession = session handle
;			$iRegAddr = register address
; out:		floating point number read from register
Func __F4T_read(ByRef $mbSession, $iRegAddr, $iTimeoutMS = 2000)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbReadFloat32($mbSession, $iRegAddr, $iTimeoutMS)
	Else
		Return __mbReadInt16($mbSession, $iRegAddr, $iTimeoutMS) / 10
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_read



;			__F4T_write
; task:		write a register in the F4T chamber
;			if dataMap=1 then  32 bit float
;			else times 10 and store as 16 bit int
; in:		$mbSession = session handle
;			$iRegAddr = register address
;			$nValue = floating point number to write
; out:		0 if successful, or @error
Func __F4T_write(ByRef $mbSession, $iRegAddr, $nValue, $iTimeoutMS = 2000)
	If Not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbWriteFloat32($mbSession, $iRegAddr, $nValue)
	Else
		Return __mbWriteInt16($mbSession, $iRegAddr, Int(10 * $nValue))
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>__F4T_write



;			__mbF4Tbegin
Func __mbF4Tbegin(ByRef $mbSession)
	$g_bCommValid = 1
	If IsArray($mbSession) Then Return __mbF4TconfirmOpen($mbSession)    ; if $mbSession is an array, then assume it is an existing session handle
	If __mbF4Topen($mbSession, 1) Then Return 1
	__mbFellOffline()
	Return SetError(-1, 0, 0)
EndFunc   ;==>__mbF4Tbegin



;			__mbF4Tend
Func __mbF4Tend(ByRef $mbSession)
	__mbEnd($mbSession)
EndFunc   ;==>__mbF4Tend



;			Determine which DataMap setting the F4T chamber has
; task:		read16 register 100 and look for a return of 0x8300 to signal that datamap is 1 instead of 2
;			if error or no response then assume dataMap 1
; in:		$aSession = session handle
; out:		DataMap:  1 (new) or 2 (legacy F4T)
Func __mbF4TDetermineDataMap(ByRef $mbSession)
	If Not __mbF4TconfirmOpen($mbSession) Then Return SetError(1, 0, -1)
	Local $t = __mbReadReg16($mbSession, 100)
	$mbSession[$_MBdataMap] = ((Int($t / 0x100) = 0x83) Or (@error) Or ($t = 0)) ? 1 : 2
	Return $mbSession[$_MBdataMap]
EndFunc   ;==>__mbF4TDetermineDataMap



;			Determine which modbus word order setting the F4T chamber has
; task:		read16 register 14092 or 6734.  1331 = low-high, 1330 = high-low
; in:		$mbSession = session handle
; out:		word order 0 = low-high, 1 = high-low
Func __mbF4TDetermineWordOrder(ByRef $mbSession)
	If Not __mbF4TconfirmOpen($mbSession) Then Return SetError(-1, 0, -1)
	Local $iR = __mbReadReg16($mbSession, 14092)
	Local $iWordOrder = 0
	If $iR = 1331 Then
		$iWordOrder = 0
	ElseIf $iR = 1330 Then
		$iWordOrder = 1
	Else
		$iR = __mbReadReg16($mbSession, 6734)
		If $iR = 1331 Then
			$iWordOrder = 0
		ElseIf $iR = 1330 Then
			$iWordOrder = 1
		EndIf
	EndIf
	$mbSession[$_MBwordOrder] = $iWordOrder
	Return $iWordOrder
EndFunc   ;==>__mbF4TDetermineWordOrder



;			__mbF4Topen
; task:		start a TCP socket session with the F4T chamber using modbus
; in:		$mbSession = session handle or IP address
Func __mbF4Topen(ByRef $mbSession, $bClose = 0)
	If Not __mbOpen($mbSession, $bClose) Then Return SetError(-1, @error, 0)
	__mbF4TDetermineDataMap($mbSession)
	__mbF4TDetermineWordOrder($mbSession)
	Return 1
EndFunc   ;==>__mbF4Topen



;			__mbF4TconfirmOpen
; task:		confirm if $aSession is connected/open
; in:		$mbSession = visa session handle
; out:		1 if it is open
;			0 if it is not open and we could not reopen it - error
Func __mbF4TconfirmOpen(ByRef $mbSession)                                   ; check if session is open, reopen if no
	If Number($mbSession[$_MBstate]) = 1 Then Return 1                      ; if session is already open then return
	__mbSessionSanityCheck($mbSession)
	If Not __mbOpen($mbSession) Then Return 0
	__mbF4TDetermineDataMap($mbSession)                                     ; determine the DataMap setting
	__mbF4TDetermineWordOrder($mbSession)                                   ; determine the Word Order setting
	Return 1
EndFunc   ;==>__mbF4TconfirmOpen


#ce





