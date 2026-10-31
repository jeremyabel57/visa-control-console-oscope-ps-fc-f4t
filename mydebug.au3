#include-once

;#include <Array.au3>
;#include "datatypes.au3"




;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
; debug output to string or console



Func __ConsolePrintVars($sPrefix, _
		$n0 = '', $v0 = '', $n1 = '', $v1 = '', $n2 = '', $v2 = '', $n3 = '', $v3 = '', $n4 = '', $v4 = '', _
		$n5 = '', $v5 = '', $n6 = '', $v6 = '', $n7 = '', $v7 = '', $n8 = '', $v8 = '', $n9 = '', $v9 = '', _
		$n10 = '', $v10 = '', $n11 = '', $v11 = '', $n12 = '', $v12 = '', $n13 = '', $v13 = '', $n14 = '', $v14 = '', _
		$n15 = '', $v15 = '', $n16 = '', $v16 = '', $n17 = '', $v17 = '', $n18 = '', $v18 = '', $n19 = '', $v19 = '' _
		)
	ConsoleWrite(__sPrintVars($sPrefix, $n0, $v0, $n1, $v1, $n2, $v2, $n3, $v3, $n4, $v4, $n5, $v5, $n6, $v6, $n7, $v7, $n8, $v8, $n9, $v9, _
			$n10, $v10, $n11, $v11, $n12, $v12, $n13, $v13, $n14, $v14, $n15, $v15, $n16, $v16, $n17, $v17, $n18, $v18, $n19, $v19))
EndFunc   ;==>__ConsolePrintVars

Func __sPrintVars($sPrefix, _
		$n0 = '', $v0 = '', $n1 = '', $v1 = '', $n2 = '', $v2 = '', $n3 = '', $v3 = '', $n4 = '', $v4 = '', _
		$n5 = '', $v5 = '', $n6 = '', $v6 = '', $n7 = '', $v7 = '', $n8 = '', $v8 = '', $n9 = '', $v9 = '', _
		$n10 = '', $v10 = '', $n11 = '', $v11 = '', $n12 = '', $v12 = '', $n13 = '', $v13 = '', $n14 = '', $v14 = '', _
		$n15 = '', $v15 = '', $n16 = '', $v16 = '', $n17 = '', $v17 = '', $n18 = '', $v18 = '', $n19 = '', $v19 = '' _
		)
	Local $vVal, $sName, $s = '', $i, $n = Int((@NumParams - 2) / 2)
	Local $sSep = StringRight($sPrefix, 2)
	$sPrefix = StringTrimRight($sPrefix, 2)
	If $sPrefix <> "" Then $sPrefix &= " "
	If $sSep = @CRLF Then $sSep &= $sPrefix
	If $sSep = "" Then $sSep = ", "
	$s &= $sPrefix
	For $i = 0 To $n
		$sName = Eval("n" & $i)
		If $sName = "" Then ContinueLoop
		If StringLeft($sName, 1) = "$" Then $sName = StringTrimLeft($sName, 1)
		$vVal = Eval("v" & $i)
		If $i > 0 Then $s &= $sSep
		$s &= __sPrintVar($vVal, ", ", $sName, False)
	Next
	$s &= @CRLF
	Return $s
EndFunc   ;==>__sPrintVars




Func __ConsolePrintVar($vVar, $sSep = ", ", $sName = "", $bEOL = True)
	ConsoleWrite(__sPrintVar($vVar, $sSep, $sName, $bEOL))
EndFunc   ;==>__ConsolePrintVar

Func __sPrintVar($vVar, $sSep = ", ", $sName = "", $bEOL = False)
	Local $sSepRow = @CRLF
	Local $s = ''
	If $sName <> "" Then $s &= $sName & " = "
	$s &= "(" & VarGetType($vVar)
	If IsArray($vVar) Then
		Local $x, $nr = UBound($vVar)
		$s &= "[" & $nr & "]"
		If UBound($vVar, 0) > 1 Then        ; 2D array
			Local $y, $nc = UBound($vVar, 2)
			$s &= "[" & $nc & "]) "
			$s &= ("[")
			If $nr > 0 And $nc > 0 Then
				$s &= " "
				$nr -= 1
				$nc -= 1
				For $y = 0 To $nr
					If $y > 0 Then $s &= $sSepRow
					$s &= "[ "
					For $x = 0 To $nc
						If $x > 0 Then $s &= $sSep
						$s &= __sPrintVar($vVar[$y][$x])
					Next
					$s &= " ]"
				Next
			EndIf
			$s &= " ]"

		Else                                ; 1D array
			$s &= ") "
			$nr -= 1
			$s &= "["
			If $nr >= 0 Then
				$s &= " "
				For $x = 0 To $nr
					If $x Then $s &= $sSep
					$s &= __sPrintVar($vVar[$x])
				Next
			EndIf
			$s &= " ]"
		EndIf

	ElseIf __dbgIsDictionary($vVar) Then    ; dictionary
		$s &= "[" & $vVar.Count & "]) "
		Local $bF = True
		Local $sKey
		$s &= "( "
		For $sKey In $vVar
			Local $sVal = $vVar.Item($sKey)
			If $bF Then
				$bF = False
			Else
				$s &= $sSep
			EndIf
			$s &= $sKey & "=" & __sPrintVar($sVal)
		Next
		$s &= " )"

	ElseIf IsMap($vVar) Then                ; map
		$s &= "[" & UBound($vVar) & "]) "
		Local $aKeys = MapKeys($vVar)
		Local $bF = True
		Local $sKey
		$s &= "[ "
		For $sKey In $aKeys
			Local $sVal = $vVar[$sKey]
			If $bF Then
				$bF = False
			Else
				$s &= $sSep
			EndIf
			$s &= $sKey & "=" & __sPrintVar($sVal)
		Next
		$s &= " ]"

	ElseIf StringIsInt($vVar) Or StringIsFloat($vVar) Or IsBool($vVar) Then
		$s &= ") " & $vVar                  ; number or boolean

	ElseIf IsBinary($vVar) Then             ; binary
		$s &= "[" & BinaryLen($vVar) & "]) '" & String($vVar) & "'"

	Else                                    ; string and others
		$s &= ") '" & $vVar & "'"
	EndIf

	If $sName <> "" And $bEOL Then $s &= @CRLF
	Return $s
EndFunc   ;==>__sPrintVar


Func __dbgIsDictionary($vVar)               ; confirm $vVar is a scripting dictionary or not
	If Not IsObj($vVar) Then Return False
	Return ObjName($vVar) = "Dictionary"
EndFunc   ;==>__dbgIsDictionary




;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
