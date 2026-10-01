#include-once


; visa commands for Frequency counter
;Global Const $VI_IDN = "*IDN?"                                             ; request identity string
Global Const $FC_VI_INIT = "INITiate:IMMediate"                             ; start the measurements/data collection
Global Const $FC_VI_RESET = "*RST"                                          ; reset settings
Global Const $FC_VI_CLS = "*CLS"                                            ; clear current measurements
Global Const $FC_VI_ABORT = "ABORt"                                         ; abort current measurement/data collection
Global Const $FC_VI_CALC_CLEAR = "CALCulate:AVERage:CLEar"                  ; clear measurement statistics and restart from sample #1
Global Const $FC_VI_CALC_COUNT = "CALCulate:AVERage:COUNt:CURRent?"         ; get the current sample count
Global Const $FC_VI_CALC_ADEV = "CALCulate:AVERage:ADEViation?"             ; get the current Allan Deviation value
Global Const $FC_VI_CALC_ALL = "CALCulate:AVERage:ALL?"                     ; get the current measurement stats: mean, stddev, min, max
Global Const $FC_VI_READ1 = "DATA:LAST?"                                    ; get the last frequency reading
Global Const $FC_VI_COUNT = "DATA:POINts?"									; get the current number of samples measured
;Global Const $FC_VI_READ1 = "R? 1"                                          ; get the last frequency reading


#include "visascpi.au3"
#include "general.au3"

#include <MsgBoxConstants.au3>
#include <WinAPIFiles.au3>



Func __fc_ReadCount($ipAddr = GetIP())                                        ; get the current realtime sample count
	Local $iC = __viReq("" & $ipAddr, $FC_VI_COUNT)
	If @error Then Return SetError(@error, @extended, Number($iC))
	Return Number($iC)
EndFunc   ;==>__fc_ReadCount



Func __fc_Initialize($ipAddr = GetIP())
	Local $aCmds = [ _
			$FC_VI_ABORT, _                     ; abort any prior running functions
			$VI_RST, _                          ; reset settings
			$VI_CLS, _                          ; clear status
			"CONFigure:FREQuency (@1)", _       ; Establish base frequency measurement on Ch 1
			$VI_CLS, _                          ; clear status
			"INPut1:COUPling AC", _             ; Set coupling to AC (or DC depending on source)
			"INPut1:IMPedance 50", _            ; Set input impedance to 50 Ohms (or 1M Ohms)
			"INPut1:LEVel:AUTO OFF", _          ; Turn off auto-leveling to prevent measurement hiccups
			"INPut1:LEVel 0.0", _               ; Set an absolute trigger level (e.g., 0 Volts)
			"INPut1:NREJect OFF", _             ; turn off noise reject filter
			"SENSe:FREQuency:MODE RCON", _      ; CRITICAL: Set to Raw Continuous (pi-counting) mode for Allan Deviation
			"SENSe:FREQuency:GATE:TIME 0.1", _  ; Set your gate time / Tau interval (e.g., 100 ms)
			"SAMPle:COUNt 1000000", _           ; Set total samples per trigger batch (e.g., 1000 Samples)
			"TRIGger:COUNt 1", _                ; In continuous mode, Trigger Count must be exactly 1
			"TRIGger:DELay 0", _                ; set trigger delay to 0
			"CALCulate:STATe ON", _             ; Turn on the calculation subsystem
			"CALCulate:AVERage:STATe ON", _     ; Turn on data statistics (Mean, StdDev, Min, Max, Pk-Pk)
			$FC_VI_CALC_CLEAR, _                ; clear data statistics
			$FC_VI_INIT]                        ; start data collection
	Local $viSession = $ipAddr
	Local $i
	If Not __viBegin($viSession) Then Return SetError(-1, 0, 0)
	For $i = 0 To UBound($aCmds) - 1
		__viReq($viSession, $aCmds[$i], $VI_NORETRY)
		Sleep(1)
	Next
	__viEnd($viSession)
EndFunc   ;==>__fc_Initialize




Func __fc_ResetStats($ipAddr = GetIP())
	Local $aCmds = [ _
			$FC_VI_ABORT, _                     ; abort any prior running functions
			$FC_VI_CALC_CLEAR, _                ; clear data statistics
			$FC_VI_INIT]                        ; start data collection
	Local $viSession = $ipAddr
	If Not __viBegin($viSession) Then Return SetError(-1, 0, 0)
	Local $i
	For $i = 0 To UBound($aCmds) - 1
		__viReq($viSession, $aCmds[$i], $VI_NORETRY)
		Sleep(1)
	Next
	__viEnd($viSession)
EndFunc   ;==>__fc_ResetStats



; in:		$hField = gui element to put the measurement into
;			$sReq = request visa command to get data
Func __fc_GuiRead($hField, $sReq)
	Local $fR = __viReq("" & GetIP(), $sReq)
	If @error Then Return SetError(@error, @extended, -1)
	GUICtrlSetData($hField, Number($fR, $NUMBER_DOUBLE))
EndFunc   ;==>__fc_GuiRead



Func GetIP()
	#forcedef $hIpAddr
	Return "raw:" & GUICtrlRead($hIpAddr)
EndFunc   ;==>GetIP


Func SetID($sId)
	#forcedef $hDevID
	GUICtrlSetData($hDevID, $sId)
	_GUICtrlEdit_SetSel($hDevID, 0, 0)
EndFunc   ;==>SetID


Func GetID()
	#forcedef $hDevID, $hIpAddr
	$g_bCommValid = 0
	GUICtrlSetData($hDevID, "Checking...")
	Local $sId = __viGetID(GetIP())
	SetID($sId)
	$g_bCommValid = Not ($sId == "")
	Return $sId
EndFunc   ;==>GetID



Func FellOffline()
	$g_bCommValid = 0
	SetID("")
EndFunc   ;==>FellOffline




Func ScanNetwork()
	#forcedef $hIpAddr
	Local $aRet = __viScanSubnetFilter(__viScanSubnet("192.168.0.0"), "Frequency Counter")
	GUICtrlSetData($hIpAddr, $aRet[0], $aRet[1])
EndFunc   ;==>ScanNetwork





; task:		Take a screen shot of the Frequency Counter and save it to file
#forcedef $hScreenShot
Func __fc_ScreenShot($UX = 1, $ipAddr = GetIP(), $sFile = GUICtrlRead($hScreenShot))
	GUICtrlSetData($hScreenShot, __FileNameAutoIncrement($sFile))
	Local $aCmds = [["HCOPy:SDUMp:DATA:FORMat PNG", $VI_NOWAIT], _
			["HCOPy:SDUMp:DATA?", $VI_NOWAIT]]
	Local $sR = __viSaveScreenShot(GetIP(), $sFile, $aCmds, 15000, $UX)
	if $sR and $UX Then MsgBox($MB_ICONINFORMATION, "Success", "Screenshot successfully saved to: " & @CRLF & $sFile)
	Return $sR
EndFunc   ;==>__fc_ScreenShot




#forcedef $hCaptureData
Func __fc_SaveData($UX = 1, $sFile = GUICtrlRead($hCaptureData))
	#forcedef $hFreq, $hMEan, $hStdDev, $hMin, $hMax, $hAllanDev, $hCount
	;GuiCtrlSetData($hCaptureData,__FileNameAutoIncrement($sFile))
	Local Const $sTitle = "Frequency Counter Data File"
	Local $hFile = FileOpen($sFile, 1)         ; 1=append
	If $hFile < 0 Then
		If $UX Then MsgBox($MB_OK, $sTitle, "Communication Error." & @CRLF & "error=" & @error)
		Return SetError($hFile, 0, -1)
	EndIf
	FileWriteLine($hFile, "")
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "Frequency", GUICtrlRead($hFreq)))
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "Mean", GUICtrlRead($hMean)))
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "StdDev", GUICtrlRead($hStdDev)))
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "Min", GUICtrlRead($hMin)))
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "Max", GUICtrlRead($hMax)))
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "Allan Deviation", GUICtrlRead($hAllanDev)))
	FileWriteLine($hFile, StringFormat("%16s: %37.18f", "Sample Count", GUICtrlRead($hCount)))
	FileClose($hFile)
	If $UX Then MsgBox($MB_OK, $sTitle, "Current readings/statistics saved to" & @CRLF & @CRLF & $sFile, 5)
	Return 1
EndFunc   ;==>__fc_SaveData

