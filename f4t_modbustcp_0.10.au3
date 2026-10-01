


#include-once
#include "modbustcp.au3"




;--------------------------------------------
; Test Equity F4T thermal chamber modbus functions
;



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

#forcedef $hIpAddr




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



#comments-start
;			__F4T_readPower
; task:		read the heat/cooling power output of the chamber
; in:		$mbSession = modbus session handle
; out:		-0 - -100.0% for cooling,  +0 - +100.0% for heating
Func __F4T_readPower(ByRef $mbSession)
	If not __mbF4Tbegin($mbSession) Then Return SetError(1, 0, -1)
	If $mbSession[$_MBdataMap] = 1 Then
		Return __mbReadFloat32($mbSession, $F4T_REG_HEAT1) - __mbReadFloat32($mbSession, $F4T_REG_COOL1)
	Else
		Return __mbReadInt16($mbSession, $F4T_REG_POWER2) / 10
	EndIf
	__mbF4Tend($mbSession)
EndFunc   ;==>_F4T_readPower
#comments-end



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




Func __F4T_FtoC($iF)                        ; convert deg F to deg C
	Return ($iF - 32) * 5 / 9
EndFunc   ;==>__F4T_FtoC



Func __F4T_CtoF($iC)                        ; convert deg F to deg C
	Return ($iC * 9 / 5) + 32
EndFunc   ;==>__F4T_CtoF



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

