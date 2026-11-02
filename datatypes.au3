#include-once




; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; data type boolean tests
;



Func __IsDictionary($vVar)                                                      ; confirm $vVar is a scripting dictionary or not
	If Not IsObj($vVar) Then Return False
	Return ObjName($vVar) = "Dictionary"
EndFunc   ;==>__IsDictionary
Func __IsScriptingDictionary($vVar)
	Return __IsDictionary($vVar)
EndFunc   ;==>__IsScriptingDictionary




; Function Name:    __viIsDllHandleValid
; Description:      Queries kernel32.dll directly to check if a DllOpen handle is live and active.
; Parameter(s):     $hDll - The handle returned from DllOpen() to test
; Return Value(s):  True  - The handle is open and valid.
;                   False - The handle is dead, closed, or corrupted.
Func __IsDllHandleValid($hDll)
	If $hDll = "" Or $hDll = True Or $hDll = False Then Return False            ; sanity checks
	If Number($hDll) = 0 Then Return False
	Local $aRet = DllCall("kernel32.dll", "dword", "GetModuleFileNameW", _      ; Call GetModuleFileNameW. It returns the path string length on success, or 0 on failure.
			"handle", $hDll, _                                                  ;    We provide a tiny 2-character buffer because we only care about the success/failure return status code.
			"wstr", "", _
			"dword", 2)
	If @error Then Return False                                                 ; The DLL call itself failed entirely
	Return ($aRet[0] > 0)                                                       ; If the return value is greater than 0, the handle is valid!
EndFunc   ;==>__IsDllHandleValid



Func __IsFileHandle($hFile)
	If Not IsInt($hFile) And Not IsPtr($hFile) Then Return False                ; 1. Quick structural check: Handles must be valid integers or pointers
	FileGetPos($hFile)                                                          ; 2. Functional check: Attempt to read its position
	If @error Then Return False                                                 ; If the handle is fake or has been closed, @error will be set to non-zero
	Return True
EndFunc   ;==>__IsFileHandle



Func __IsTCPsocket($hSocket)
	If Not IsInt($hSocket) And Not IsPtr($hSocket) Then Return False            ; 1. Check if the variable data type is a basic integer/pointer format above 0
	If Int($hSocket) <= 0 Then Return False
	__SocketToIP($hSocket)                                                      ; 2. Test the handle against a network function to see if it is still live/recognized
	If @error Then Return False                                                 ; If the socket handle is closed, corrupted, or fake, @error will be set to non-zero
	Return True
EndFunc   ;==>__IsTCPsocket



; Function:     __SocketToIP
; Description:  Queries Windows Winsock API to fetch the remote IP Address of an active socket handle
; Returns:      String (IP Address) on Success, 0 on Failure
Func __SocketToIP($hSocket)
	Local $tSockAddr = DllStructCreate("short;ushort;uint;char[8]")
	Local $iSockAddrSize = DllStructGetSize($tSockAddr)
	Local $aRet = DllCall("Ws2_32.dll", "int", "getpeername", "uint_ptr", $hSocket, "struct*", $tSockAddr, "int*", $iSockAddrSize)
	If Not @error And $aRet[0] = 0 Then
		$aRet = DllCall("Ws2_32.dll", "str", "inet_ntoa", "int", DllStructGetData($tSockAddr, 3))
		If Not @error Then Return $aRet[0]
	EndIf
	Return 0
EndFunc   ;==>__SocketToIP




; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; temperature conversions
;


Func __TemperatureFtoC($iF)     ; convert deg F to deg C
	Return ($iF - 32) * 5 / 9
EndFunc   ;==>__TemperatureFtoC



Func __TemperatureCtoF($iC)     ; convert deg F to deg C
	Return ($iC * 9 / 5) + 32
EndFunc   ;==>__TemperatureCtoF




; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; AssignEx and EvalEx
;



;			AssignEx
; task:		same as Assign, but allow for subscripts
; in:		$sVar = name of variable (without the leading $)
;			$vVal = value/data to assign to variable
; out:		1 if successful
;			0 if failed
; note:		byref $vVal to hopefully save memory with big payloads
;			$sVar can be variable[subscript] or variable[row][col]
;			if sVar is an array, map, or dictionary then the subscript is used
Func AssignEx($sVar, ByRef $vVal, $oDev)
	Local $vVar
	Local $i = StringInStr($sVar, "[")
	If $i <= 0 Then $i = StringInStr($sVar, "(")
	If $i <= 0 Then Return Assign($sVar, $vVal, 2)

	Local $sIdx = StringTrimRight(StringTrimLeft($sVar, $i), 1)
	If StringInStr("""'", StringLeft($sIdx, 1)) Then $sIdx = StringTrimLeft($sIdx, 1)
	If StringInStr("""'", StringRight($sIdx, 1)) Then $sIdx = StringTrimRight($sIdx, 1)
	$sVar = StringLeft($sVar, $i - 1)
	$vVar = Eval($sVar)
	If IsArray($vVar) Then
		$i = StringInStr($sIdx, "]")
		If $i > 0 Then                                                  ; if 2D array
			Local $iCol = Int(StringTrimLeft($sIdx, $i + 1))
			$sIdx = Int(StringLeft($sIdx, $i - 1))
			If UBound($vVar, 0) < 2 Then Return 0
			If $iCol < 0 Or UBound($vVar, 2) <= $iCol Then Return 0
			If $sIdx < 0 Or UBound($vVar, 1) <= $sIdx Then Return 0
			$vVar[$sIdx][$iCol] = $vVal
		Else                                                            ; else 1D array
			$sIdx = Int($sIdx)
			If $sIdx < 0 Or UBound($vVar) <= $sIdx Then Return 0        ; ignore out of bounds subscript
			$vVar[$sIdx] = $vVal
		EndIf
	ElseIf IsMap($vVar) Then                                            ; if map
		$vVar[String($sIdx)] = $vVal
	ElseIf __IsDictionary($vVar) Then                                   ; if dictionary
		$vVar.Item(String($sIdx)) = $vVal
		Return 1
	EndIf
	Return Assign($sVar, $vVar, 2)                                      ; assign value back to variable
EndFunc   ;==>AssignEx



;			EvalEx
; task:		same as Eval, but allow for subscripts
; in:		$sVar = name of variable (without the leading $)
; out:		value of the variable or subscript of the variable
;			returns empty string and @error=1 if the variable does not exist or the subscript is out of range
; note:		allow for subscripts in the variable name being assigned
;			$sVar can be variable[subscript] or variable[row][col]
;			if sVar is an array, map, or dictionary then the subscript is used
Func EvalEx($sVar, $oDev)
	Local $i = StringInStr($sVar, "[")
	If $i <= 0 Then $i = StringInStr($sVar, "(")
	If $i <= 0 Then Return Eval($sVar)
	Local $sIdx = StringTrimRight(StringTrimLeft($sVar, $i), 1)
	If StringInStr("""'", StringLeft($sIdx, 1)) Then $sIdx = StringTrimLeft($sIdx, 1)
	If StringInStr("""'", StringRight($sIdx, 1)) Then $sIdx = StringTrimRight($sIdx, 1)
	$sVar = StringLeft($sVar, $i - 1)
	$vVar = Eval($sVar)
	If IsArray($vVar) Then
		$i = StringInStr($sIdx, "]")
		If $i > 0 Then                                                  ; if 2D array
			Local $iCol = Int(StringTrimLeft($sIdx, $i + 1))
			$sIdx = Int(StringLeft($sIdx, $i - 1))
			If UBound($vVar, 0) < 2 Then Return SetError(1, 0, '')
			If $iCol < 0 Or UBound($vVar, 2) <= $iCol Then Return SetError(1, 0, '')
			If $sIdx < 0 Or UBound($vVar, 1) <= $sIdx Then Return SetError(1, 0, '')
			Return $vVar[$sIdx][$iCol]
		Else                                                            ; else 1D array
			$sIdx = Int($sIdx)
			If $sIdx < 0 Or UBound($vVar) <= $sIdx Then Return SetError(1, 0, '')
			Return $vVar[$sIdx]
		EndIf
	ElseIf IsMap($vVar) Then                                            ; if map
		$sIdx = String($sIdx)
		If MapExists($vVar, $sIdx) Then Return $vVar[$sIdx]
		Return SetError(1, 0, '')
	ElseIf __IsDictionary($vVar) Then                                   ; if dictionary
		$sIdx = String($sIdx)
		If $vVar.Exists($sIdx) Then Return $vVar.Item($sIdx)
		Return SetError(1, 0, '')
	EndIf
	Return $vVar
EndFunc   ;==>EvalEx







; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; Assign/Eval storing variables in a dictionary
;



Global $g_vars = ObjCreate("Scripting.Dictionary")



;			AssignDict
; task:		store variable in a dictionary instead of a global variable
; in:		$sVar = name of variable (without the leading $)
;			$vVal = value/data to assign to variable
; out:		$vVal
;			if error then @error=1 and return=0
; note:		byref $vVal to hopefully save memory with big payloads
Func AssignDict($sVar, ByRef $vVal, $oDict = $g_vars)
	If StringLeft($sVar, 1) = "$" Then $sVar = StringTrimLeft($sVar, 1)
	If Not __IsDictionary($oDict) Then Return SetError(1, 0, 0)
	$oDict.Item(String($sVar)) = $vVal
	Return $vVal
EndFunc   ;==>AssignDict



;			EvalDict
; task:		retrieve variable from dictionary instead of global variable
; in:		$sVar = name of variable (without the leading $)
; out:		value of the variable or subscript of the variable
;			returns empty string and @error=1
Func EvalDict($sVar, $oDict = $g_vars)
	If StringLeft($sVar, 1) = "$" Then $sVar = StringTrimLeft($sVar, 1)
	If Not __IsDictionary($oDict) Then Return SetError(1, 0, '')
	$sVar = String($sVar)
	If $oDict.Exists($sVar) Then Return $oDict.Item($sVar)
	Return SetError(1, 0, '')
EndFunc   ;==>EvalDict






; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
;


; Function to convert any integer to a binary string
Func _Bits($iVal, $iBits = 8)
	Local $sBin = ""
	For $i = $iBits - 1 To 0 Step -1
		$sBin &= BitAND(BitShift($iVal, $i), 1)
	Next
	Return $sBin
EndFunc   ;==>_Bits





; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
;




;		convert number fN to a prety print string including its order of magnitude/exponent prefix
Func __NumEgr($f, $p = 2)
	$f = Number($f)
	Local $a = ["Q", 30, "R", 27, "Y", 24, "Z", 21, "E", 18, "P", 15, "T", 12, "G", 9, "M", 6, "k", 3, "", 0, "m", -3, "u", -6, "n", -9, "p", -12, "f", -15, "a", -18, "z", -21, "y", -24, "r", -27, "q", -30]
	Local $i, $n = ubound($a) - 1, $e
	$g = Abs($f)
	For $i = 0 To $n Step 2
		$e = 10 ^ $a[$i + 1]
		If $g >= $e Then ExitLoop
	Next
	Return StringFormat("%." & $p & "f " & $a[$i], $f / $e)
EndFunc   ;==>__NumMetricPrefix




; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
; ---------------------------------------
;


