#include-once

#include <Array.au3>


Func __viIsScriptingDictionary_($vVar)                                          ; confirm $vVar is a scripting dictionary or not
	If Not IsObj($vVar) Then Return False
	Return ObjName($vVar) = "Dictionary"
EndFunc   ;==>__viIsScriptingDictionary_




Func __ConsolePrintVar($sPrefix, _
		$n0 = '', $v0 = '', $n1 = '', $v1 = '', $n2 = '', $v2 = '', $n3 = '', $v3 = '', $n4 = '', $v4 = '', _
		$n5 = '', $v5 = '', $n6 = '', $v6 = '', $n7 = '', $v7 = '', $n8 = '', $v8 = '', $n9 = '', $v9 = '', _
		$n10 = '', $v10 = '', $n11 = '', $v11 = '', $n12 = '', $v12 = '', $n13 = '', $v13 = '', $n14 = '', $v14 = '', _
		$n15 = '', $v15 = '', $n16 = '', $v16 = '', $n17 = '', $v17 = '', $n18 = '', $v18 = '', $n19 = '', $v19 = '' _
		)
	Local $vVal, $sName, $i, $n = Int((@NumParams - 2) / 2)
	If $sPrefix <> "" Then $sPrefix &= " "
	For $i = 0 To $n
		$sName = Eval("n" & $i)
		If StringLeft($sName, 1) = "$" Then $sName = StringTrimLeft($sName, 1)
		$vVal = Eval("v" & $i)
		__ConsoleWriteVar($vVal, ", ", $sPrefix & $sName)
	Next
EndFunc   ;==>__ConsolePrintVar




Func __ConsoleWriteVar($vVar, $sSep = ", ", $sName = "", $bEOL = true)
	If $sName <> "" Then ConsoleWrite($sName & " = ")
	ConsoleWrite("(" & VarGetType($vVar) & ") ")
	If IsArray($vVar) Then
		__ConsoleWriteVarArray($vVar, $sSep)
	ElseIf __viIsScriptingDictionary_($vVar) Then
		__ConsoleWriteVarDictionary($vVar, $sSep,"",false)
	ElseIf IsMap($vVar) Then
		__ConsoleWriteVarMap($vVar, $sSep)
	ElseIf StringIsInt($vVar) Or StringIsFloat($vVar) Or IsBool($vVar) Then
		ConsoleWrite($vVar)
	ElseIf IsBinary($vVar) Then
		ConsoleWrite("'" & BinaryToString($vVar) & "'")
	Else
		ConsoleWrite("'" & $vVar & "'")
	EndIf
	If $sName <> "" and $bEOL Then ConsoleWrite(@CRLF)
EndFunc   ;==>__ConsoleWriteVar



Func __ConsoleWriteVarDictionary($oDict, $sSep = ", ", $sName = "", $bEOL=True)
	If Not __viIsScriptingDictionary_($oDict) Then Return
	If $sName <> "" Then ConsoleWrite($sName & " = ")
	Local $bF = True
	Local $sKey
	For $sKey In $oDict
		Local $sVal = $oDict.Item($sKey)
		If $bF Then
			ConsoleWrite("( ")
			$bF = False
		Else
			ConsoleWrite($sSep)
		EndIf
		__ConsoleWriteVar($sVal,$sSep,$sKey,false)
	Next
	ConsoleWrite(" )")
	If $sName <> "" and $bEOL Then ConsoleWrite(@CRLF)
EndFunc   ;==>__ConsoleWriteVarDictionary



Func __ConsoleWriteVarMap($mVar, $sSep = ", ", $sName = "", $bEOL=True)
	If Not IsMap($mVar) Then Return
	If $sName <> "" Then ConsoleWrite($sName & "=")
	Local $aKeys = MapKeys($mVar)
	Local $bF = True
	Local $sKey
	For $sKey In $aKeys
		Local $sVal = $mVar[$sKey]
		If $bF Then
			ConsoleWrite("[ ")
			$bF = False
		Else
			ConsoleWrite($sSep)
		EndIf
		__ConsoleWriteVar($sVal, $sSep, $sKey, false)
	Next
	ConsoleWrite(" ]")
	If $sName <> "" and $bEOL Then ConsoleWrite(@CRLF)
EndFunc   ;==>__ConsoleWriteVarMap



Func __ConsoleWriteVarArray($a, $sSep = ", ", $sName = "", $bEOL=True)
	If Not IsArray($a) Then Return
	If UBound($a, 0) > 1 Then Return __ConsoleWriteVarArray2D($a, @CRLF & "  ", ", ", $sName, true)
	Local $i, $n = UBound($a)
	If $sName <> "" Then ConsoleWrite($sName & "[" & $n & "] = ")
	ConsoleWrite("[ ")
	If $n > 0 Then
		$n -= 1
		For $i = 0 To $n
			If $i Then ConsoleWrite($sSep)
			__ConsoleWriteVar($a[$i], $sSep, "", false)
		Next
	EndIf
	ConsoleWrite(" ]")
	If $sName <> "" and $bEOL Then ConsoleWrite(@CRLF)
EndFunc   ;==>__ConsoleWriteVarArray


Func __ConsoleWriteVarArray2D($a, $sRsep = @CRLF & "  ", $sCsep = ", ", $sName = "", $bEOL=True)
	If Not IsArray($a) Then Return
	If UBound($a, 0) > 2 Then Return
	Local $x, $y, $r = UBound($a, 1), $c = UBound($a, 2)
	If $sName <> "" Then ConsoleWrite($sName & "[" & $c & "][" & $r & "] = " & @CRLF)
	ConsoleWrite("[ ")
	If $r > 0 And $c > 0 Then
		$r -= 1
		$c -= 1
		For $y = 0 To $r
			If $y > 0 Then ConsoleWrite($sRsep)
			ConsoleWrite("[ ")
			For $x = 0 To $c
				If $x > 0 Then ConsoleWrite($sCsep)
				__ConsoleWriteVar($a[$y][$x], $sCsep, "", false)
			Next
			ConsoleWrite(" ]")
		Next
	EndIf
	ConsoleWrite(" ]")
	If $sName <> "" and $bEOL Then ConsoleWrite(@CRLF)
EndFunc   ;==>__ConsoleWriteVarArray2D






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

