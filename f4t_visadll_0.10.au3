



; ==============================================================================
; F4T temperature chamber SCPI/VISA functions
;

#include-once
#include "visascpi.au3"



#include <StringConstants.au3>
#include <AutoItConstants.au3>



; VISA commands for F4T temperature chamber
Global Const $F4T_VISASETPOINT = ":SOURce:CLOOp1:SPOINT"
Global Const $F4T_VISAIDN = "*IDN?"
Global Const $F4T_VISAPVALUE = ":SOURce:CLOOp1:PVALUE?"
Global Const $F4T_VISAOUTPUT1 = ":OUTPut1"
Global Const $F4T_VISAERRMSG = "ERROR"








;			__F4T_readData
; task:		read the current state data from the chamber
; in:		$ipAddr = ip address of chamber
;			$aData = array to store results (prepopulated with defaults if desired)
;			 [0] = previous process temperature reading
;			 [1] = previous setpoint temperature reading
;            [2] = gui temperature units for process temperature (1=C, 0=F)
;            [3] = gui temperature units for setpoint temperature (1=C, 0=F)
;            [4] = placeholder for chamber enable state
;            [5] = placeholder for process temperature in C
;            [6] = placeholder for setpoint temperature in C
;			 [7] = placeholder for process temperature in gui selected units
;			 [8] = placeholder for setpoint temperature in gui selected units
; out:		$aData array populated
;			 [0] = previous process temperature reading
;			 [1] = previous setpoint temperature reading
;            [2] = gui temperature units for process temperature (1=C, 0=F)
;            [3] = gui temperature units for setpoint temperature (1=C, 0=F)
;            [4] = chamber enable state
;            [5] = process temperature in C
;            [6] = setpoint temperature in C
;			 [7] = process temperature in gui selected units
;			 [8] = setpoint temperature in gui selected units
Func __F4T_readDataVisa($ipAddr, ByRef $aData)
	Local $viSession="raw:" & $ipAddr
	Local $sR

	if not __viBegin($viSession) then return SetError(-1,0,0)

	$sR = __viReq($viSession, $F4T_VISAPVALUE)         ; process temperature
	If (Not ($sR == "")) And (Not StringInStr($sR, $F4T_VISAERRMSG)) And (Not @error) Then
		$sR = Number($sR)
		$aData[5] = $sR
		If Not $aData[2] Then $sR = __F4T_CtoF($sR)
		$aData[7] = StringFormat("%.1f", $sR)
	EndIf

	$sR = __viReq($viSession, $F4T_VISASETPOINT & "?")        ; temperature setpoint
	If (Not ($sR == "")) And (Not StringInStr($sR, $F4T_VISAERRMSG)) And (Not @error) Then
		$sR = Number($sR)
		$aData[6] = $sR
		If Not $aData[3] Then $sR = __F4T_CtoF($sR)
		$aData[8] = StringFormat("%.1f", $sR)
	EndIf

	$sR = __viReq($viSession, $F4T_VISAOUTPUT1 & "?")                ; is chamber heater and chiller enabled
	If (Not ($sR == "")) And (Not StringInStr($sR, $F4T_VISAERRMSG)) And (Not @error) Then
		$sR = Number($sR)
		$aData[4] = $sR
	EndIf

	$sR = __viReq($viSession, $VISAERR)                        ; check for and clear error messages
	If $sR <> 0 Then MsgBox($MB_OK, "Chamber Error message", "Error: " & $sR, 5)

	__viEnd($viSession)
EndFunc   ;==>__F4T_readDataVisa






; out:		float32 temperature, -1000 = error
Func __viF4TreadTemperature($ipAddr=GetIP())
	Local $viSession = "raw:" & $ipAddr
	if not __viBegin($viSession) then return SetError(-1, 0, -1000)
	$fTemp = __viReq($viSession, $F4T_VISAPVALUE)
	If ($fTemp == "") Or (StringInStr($fTemp, $F4T_VISAERRMSG)) Then
		$fTemp = -1000                                                                          ; bad read
	Else
		$fTemp = Number(StringFormat("%.2f", Number($fTemp) + 0.005))                           ; truncate to hundredths
	EndIf
	__viEnd($viSession)
	Return $fTemp
EndFunc   ;==>__viF4TreadTemperature



; out:		float32 temperature, -1000 = error
Func __viF4TreadSetpoint($ipAddr=GetIP())
	Local $viSession = "raw:" & $ipAddr
	if not __viBegin($viSession) then return SetError(-1, 0, -1000)
	$fTemp = __viReq($viSession, $F4T_VISASETPOINT & "?")
	If ($fTemp == "") Or (StringInStr($fTemp, $F4T_VISAERRMSG)) Then
		$fTemp = -1000                                                                          ; bad read
	Else
		$fTemp = Number(StringFormat("%.2f", Number($fTemp) + 0.005))                           ; truncate to hundredths
	EndIf
	__viEnd($viSession)
	Return $fTemp
EndFunc   ;==>__viF4TreadSetpoint



; out:		none
Func __viF4TwriteSetpoint($ipAddr, $fTemp)
	__viF4TsetParameter($ipAddr, $F4T_VISASETPOINT & " " & $fTemp, $F4T_VISASETPOINT & "?", __viF4TwriteSetpointCheck, $fTemp)
EndFunc   ;==>__viF4TwriteSetpoint
Func __viF4TwriteSetpointCheck($s1, $s2)
	$s1 = Round(Number($s1), 2)
	$s2 = Round(Number($s2), 2)
	Return (Abs($s1 - $s2) < 0.05)
EndFunc   ;==>__viF4TwriteSetpointCheck



; out:		1 = on, 0 = off, -1 = error
Func __viF4TreadEnable($ipAddr=GetIP())
	Local $viSession = "raw:" & $ipAddr
	if not __viBegin($viSession) then return -1
	Local $iEnable = __viReq($viSession, $F4T_VISAOUTPUT1 & "?")
	If ($iEnable == "") Or (StringInStr($iEnable, $F4T_VISAERRMSG)) Then
		$iEnable = -1                                                                             ; bad read
	Else
		$iEnable = Number(($iEnable = "AUT") Or ($iEnable = "MAN") Or ($iEnable = "ON") Or (Number($iEnable) = 1))
	EndIf
	__viEnd($viSession)
	Return $iEnable
EndFunc   ;==>__viF4TreadEnable



; in:		$iEnable = 1 to turn on, 0 to turn off
Func __viF4TwriteEnable($ipAddr, $iEnable)
	__viF4TsetParameter($ipAddr, $F4T_VISAOUTPUT1 & " " & ($iEnable ? "ON" : "OFF"), $F4T_VISAOUTPUT1 & "?", __viF4TwriteEnableCheck, $iEnable)
EndFunc   ;==>__viF4TwriteEnable
Func __viF4TwriteEnableCheck($s1, $s2)
	$s1 = StringUpper(StringStripWS($s1, 3))
	$s2 = StringUpper(StringStripWS($s2, 3))
	$s1 = (($s1 = "ON") Or ($s1 = "1")) ? 1 : 0
	$s2 = (($s2 = "ON") Or ($s2 = "1")) ? 1 : 0
	Return $s1 = $s2
EndFunc   ;==>__viF4TwriteEnableCheck




;				F4T Change Parameter
; task:			send command to change a parameter
;				read back the parameter and verify
;				retry as needed
; in:			$setParamCommand = VISA command to set the parameter
;				$readParamCommand = VISA command to read the parameter
;				$hCheckParamFunc = function that takes two parameter values and returns true if they match - telling us the visa device updated the parameter
;				$paramValue = target parameter value
;				$iTimeoutMS = timeout in ms
; out:			1 if successful or 0 and @error
Func __viF4TsetParameter($ipAddr, $setParamCommand, $readParamCommand, $hCheckParamFunc, $paramValue, $iTimeoutMS = 5000)

	Sleep(300)                                                ; give a moment for the chamber to finish any prior communication processing

	Local $viSession = "raw:" & $ipAddr
	if not __viBegin($viSession) then return Seterror(-1,0,0)

	ProgressOn("Changing setting on VISA device", "", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
	ProgressSet(0, "Waiting for VISA device to acknowledge change", $ipAddr & ": " & $setParamCommand)

	Local $hTimer = TimerInit()
	Local $sState = 0
	Local $iErr
	While True
		;ConsoleWrite("__viExecCommand($aSession, '" & $setParamCommand & "', -1)" & @CRLF)
		__viCmd($viSession, $setParamCommand)
		Sleep(200)
		$sState = __viReq($viSession, $readParamCommand)            ; read parameter state
		$iErr = @error
		If $sState = "" Or $iErr Then
			;ConsoleWrite("__viReOpen($aSession)" & @CRLF)                                                            ; debug
			Sleep(200)
			__viOpen($viSession)
			$iErr = @error
			Sleep(200)
			$sState = __viReq($viSession, $readParamCommand)            ; read parameter state
			;ConsoleWrite("__viExecCommand($aSession, '" & $readParamCommand & "') = '" & $sState & "', $iErr=" & $iErr & ", @error=" & @error & @CRLF)            ; debug
		EndIf

		If $hCheckParamFunc($paramValue, $sState) Then ExitLoop
		If TimerDiff($hTimer) > $iTimeoutMS Then
			;ConsoleWrite("Timeout waiting for VISA device to respond" & @CRLF)
			ExitLoop
		EndIf
		Sleep(50)
		ProgressSet(Int(100 * TimerDiff($hTimer) / $iTimeoutMS))
	WEnd
	ProgressOff()

	__viEnd($viSession)
	return 1
EndFunc   ;==>__viF4TsetParameter
