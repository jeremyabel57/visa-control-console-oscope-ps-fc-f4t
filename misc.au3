#include-once




Func __TemperatureFtoC($iF)     ; convert deg F to deg C
	Return ($iF - 32) * 5 / 9
EndFunc   ;==>__TemperatureFtoC



Func __TemperatureCtoF($iC)     ; convert deg F to deg C
	Return ($iC * 9 / 5) + 32
EndFunc   ;==>__TemperatureCtoF




Global $aVars[1][2] = [["", ""]]                                                                ; custom user variable list
Global $g_varsConfigSection = "Variables"
Global $g_configFile

Func Vars_ConfigRead()
	Local $i, $aList
	$aList = IniRead($g_configFile, $g_varsConfigSection, "vars", "")
	$aList = StringSplit($aList, "|", 3)
	Local $n = UBound($aList)
	If $n < 1 Then
		Local $a[1][2] = [["", ""]]
		$aVars = $a
		Return
	EndIf

	Local $a[$n][2]
	$n -= 1
	For $i = 0 To $n                                                                 ; read each variable
		$a[$i][0] = $aList[$i]
		$a[$i][1] = IniRead($g_configFile, $g_varsConfigSection, "v_" & $aList[$i], "")
	Next
	$aVars = $a
	Vars_Assert()
EndFunc   ;==>Vars_ConfigRead



Func Vars_Assert()
	Local $i, $n, $e = UBound($aVars, 1) - 1
	For $i = 0 To $e
		$n = $aVars[$i][0]
		If StringLeft($n, 1) = "$" Then $n = StringTrimLeft($n, 1)
		Assign($n, $aVars[$i][1], 1)               ; assign as a global variable, param3=1
	Next
EndFunc   ;==>Vars_Assert



Func Vars_ConfigWrite()
	Local $i, $list = ""
	If Not IsArray($aVars) Then Return                                      ; must be array - sanity check
	If UBound($aVars, 0) < 2 Then Return                                    ; must be 2D array
	If UBound($aVars, 2) < 2 Then Return                                    ; must have at least 2 columns
	Local $n = UBound($aVars, 1) - 1
	For $i = 0 To $n                                                        ; make list of variable names
		$list &= "|" & $aVars[$i][0]
		IniWrite($g_configFile, $g_varsConfigSection, _
				"v_" & $aVars[$i][0], $aVars[$i][1])                        ; write variable and value to ini file
	Next
	$list = StringTrimLeft($list, 1)                                        ; remove leading "|"
	IniWrite($g_configFile, $g_varsConfigSection, "vars", $list)            ; write list of variable names to the ini file
EndFunc   ;==>Vars_ConfigWrite
