#include-once


#include "visascpi.au3"


;Global Const $DCPS_CH_ALL = 0






; task:			Set the on/off state of a DC Power supply channel
; in:			$ch = channel 1-4
;				$b = 1 for on, 0 for off
Func __dcps_SetState(ByRef $viSession, $ch, $b)
	__viCmd($viSession, ":OUTP " & (($b = 0) ? "OFF" : "ON") & ", (@" & $ch & ")")   ; send command, do not wait for response
	Sleep(100)
EndFunc   ;==>__dcps_SetState

Func __dcps_GetState(ByRef $viSession, $ch, $iTimeoutMS = 1000)
	Return __viReq($viSession, ":OUTP:STAT? (@" & $ch & ")", $iTimeoutMS, $VI_NORETRY)
EndFunc   ;==>__dcps_GetState

; task:			turn all power output channels off
Func __dcps_emo()
	__viCmd("" & GetIP(), ":OUTP OFF, (@1:4)")
EndFunc   ;==>__dcps_emo




; task:			set the output voltage of a channel
; in:			ch = channel 1-4
Func __dcps_SetVoltage($viSession, $iCh, $fVoltage)
	__viCmd($viSession, ":VOLT " & $fVoltage & ", (@" & $iCh & ")")              ; set voltage
	Sleep(100)
EndFunc   ;==>__dcps_SetVoltage

;Func __dcps_GetVoltageSetpoint($viSession, $iCh, $iTimeoutMS = 1000)
;	Return __viReq($viSession, ":VOLT? (@" & $iCh & ")", $iTimeoutMS, $VI_NORETRY)
;EndFunc   ;==>__dcps_GetVoltageSetpoint



; task:			set the max output current of a channel
; in:			ch = channel 1-4
Func __dcps_SetCurrent($viSession, $iCh, $fCurrent)
	__viCmd($viSession, ":CURR " & $fCurrent & ", (@" & $iCh & ")")                 ; set current
	Sleep(100)
EndFunc   ;==>__dcps_SetCurrent

;Func __dcps_GetCurrentSetpoint($viSession, $iCh, $iTimeoutMS = 1000)
;	Return __viReq($viSession, ":CURR? (@" & $iCh & ")", $iTimeoutMS, $VI_NORETRY)
;EndFunc   ;==>__dcps_GetCurrentSetpoint



;			send request for a given channel
; in:		$ipAddr = IP address of device
;			$sReq = request prefix (without the "(@ch)" channel number)
;			$iCh = 1-4 or 0 for all
; out:		response from device
Func __dcps_viChRequest($ipAddr, $sReq, $iCh = 0)
	Local $viSession = $ipAddr
	$iCh = Number($iCh)
	If ($iCh < 1) Or (4 < $iCh) Then $iCh = "1:4"
	If Not __viBegin($viSession) Then Return SetError(-1, 0, -1)
	;__viCmd($viSession, $VI_CLS)
	Sleep(10)
	Local $sRet = __viReq($viSession, $sReq & " (@" & $iCh & ")", 1000, $VI_NORETRY)
	Local $iErr = @error
	Sleep(50)
	;__viReq($viSession, $VI_REQ_ERR)
	__viEnd($viSession)
	If $iErr Then Return SetError($iErr, 0, $sRet)
	Return $sRet
EndFunc   ;==>__dcps_viChRequest




; task:		grab screenshot and save it to file
; in:		$vSession = ip address of DC power supply, or existing visa session handle
;			$sFile = path and name of destination file
Func __dcps_SaveScreenShot($viSession, $sFile = $g_screenShotFile, $iTimeoutMS = 20000)
	Local $sCmds = [[":HCOPy:SDUMp:DATA:FORMat PNG", $VI_NOWAIT], _
			[":SYST:ERR?", 1000], _
			["*OPC?", 20000], _
			[":HCOPy:SDUMp:DATA?", $VI_NOWAIT]]
	__viSaveScreenShot($viSession, $sFile, $sCmds, $iTimeoutMS)

	;MsgBox(64, "Success", "Fixed! Screenshot saved to: " & $sFullPath)
	$g_screenShotFile = $sFile
	ConfigWrite()
EndFunc   ;==>__dcps_SaveScreenShot



