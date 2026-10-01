; functions for passing scripts as visa commands to devices

#include-once

Global $g_visa_script_debug = 0
;$g_visa_script_debug = 1
;$g_visa_script_debug = 2


;#include "visadll.au3"
#include "general.au3"

Global $g_logfile = _PathFull("log.txt")


Func _EvaluateTextExpressions($sText)
	; Regex pattern to find matches inside curly braces: {(.*?)}
	; It uses lazy matching (.*?) so it stops at the very first closing brace.
	Local $sPattern = "{(.*?)}"

	; Run a loop to find all occurrences
	While 1
		; Check if there is an expression left in the text
		Local $aMatch = StringRegExp($sText, $sPattern, 1) ; Return 1st match array
		If @error Then ExitLoop ; No more matches found, exit the loop

		Local $sExpression = $aMatch[0] ; Extract the raw expression string (e.g., "55.50 + 12.30")


		; Evaluate the expression dynamically
		Local $vResult = Execute($sExpression)

		If $g_visa_script_debug Then ConsoleWrite("_EvaluateTextExpressions: expr='" & $sExpression & "'  result='" & $vResult & "'" & @CRLF)

		; If Execute fails or returns an error, handle it gracefully
		If @error Then $vResult = "[ERROR: Invalid Expression, error=" & @error & "]"

		; Explicitly format boolean results so they don't just output as 1 or 0
		;If IsBool($vResult) Then
		;    If $vResult Then
		;        $vResult = "True"
		;    Else
		;        $vResult = "False"
		;    EndIf
		;EndIf

		; Replace ONLY the first exact match instance found in the text
		; We construct the literal placeholder string to target it accurately
		Local $sPlaceholder = "{" & $sExpression & "}"
		$sText = StringReplace($sText, $sPlaceholder, $vResult, 1) ; The '1' restricts it to the first occurrence
	WEnd

	Return $sText
EndFunc   ;==>_EvaluateTextExpressions



;			use @scriptdir to fill in and make a fully qualified path file name
Func __FullyQualifiedPath($sFile)
	Local $ssDrive, $ssDir, $ssName, $ssExt, $ssFolder                            ; get fully qualified file path name
	_PathSplit(@ScriptFullPath, $ssDrive, $ssDir, $ssName, $ssExt)
	Local $sfDrive, $sfDir, $sfName, $sfExt, $sfFolder
	_PathSplit($sFile, $sfDrive, $sfDir, $sfName, $sfExt)
	If $sfDir = "" Then
		$sfDir = $ssDir
		$sfDrive = $ssDrive
	EndIf
	Return _PathMake($sfDrive, $sfDir, $sfName, $sfExt)
EndFunc   ;==>__FullyQualifiedPath




Func __viScript(ByRef $viSession, $sFile)
	;Local $intervalDelay = 1
	#forcedef $g_SaveScreenCmds

	$sFile = __FullyQualifiedPath($sFile)
	If $g_visa_script_debug Then ConsoleWrite("__viScript(" & $viSession & ", " & $sFile & ")" & @CRLF)        ; debug
	If Not FileExists($sFile) Then Return SetError(1, 0, -1)         ; script file not found
	Local $hFile = FileOpen($sFile, $FO_READ)
	If $hFile < 0 Then Return SetError(2, 0, -1)                     ; could not open script file
	Local $sLine, $sLineLower, $sCmd, $sArg, $sR, $iPos

	;$intervalDelay = Number(StringStripWS(FileReadLine($hFile), 3))
	;If $intervalDelay <= 0 Then $intervalDelay = 50

	__viBegin($viSession)
	While 1
		$sLine = FileReadLine($hFile)
		If @error Then ExitLoop
		If StringLeft($sLine, 1) = "#" Then ContinueLoop            ; skip comment lines
		If $sLine = "" Then
			;Sleep($intervalDelay)
			ContinueLoop                                            ; skip blank lines
		EndIf
		$sLineLower = StringLower($sLine)                           ; $sCmd = first word in lower case
		$iPos = StringInStr($sLineLower, " ")
		$sArg = StringStripWS(StringMid($sLine, $iPos + 1), 3)      ; $sArg = text after first word
		$sCmd = StringLeft($sLineLower, $iPos - 1)
		$iPos = StringInStr($sArg, " ")
		$sArg2 = StringStripWS(StringMid($sArg, $iPos + 1), 3)      ; $sArg2 = text after second word
		$sArg1 = StringStripWS(StringLeft($sArg, $iPos - 1), 3)		; $sArg1 = second word only
		$sArg = _EvaluateTextExpressions($sArg)
		$sArg1 = _EvaluateTextExpressions($sArg1)
		$sArg2 = _EvaluateTextExpressions($sArg2)

		If $sCmd = "read" Then                    ; if line is a read request, then read response from previous visa command
			If StringLeft($sArg, 1) = "$" Then $sArg = StringTrimLeft($sArg, 1)
			$sR = __viRead($viSession, -1, 1000)
			If $g_visa_script_debug Then ConsoleWrite("__viScript(" & $viSession[0] & ", ...): read: " & $sArg & "='" & $sR & "'" & @CRLF)
			Assign($sArg, $sR, 2)                                              ; save the response into global variable specified by the script

		ElseIf $sCmd = "sleep" Then
			Sleep(Number($sArg))

		ElseIf $sCmd = "cd" Or $sCmd = "chdir" Then
			FileChangeDir($sArg)

			;ElseIf $sCmd = "savescreen" Then
			;	__viSaveScreenShot($viSession, _PathFull($sArg), $g_SaveScreenCmds)

		ElseIf $sCmd = "readtofile" Then
			__viReadToFile($viSession, _PathFull($sArg))

		elseif $sCmd = "writefromfile" Then
			__viWriteFromFile($viSession, $sArg1, $sArg2)

		ElseIf $sCmd = "logfile" Then
			$g_logfile = _PathFull($sArg)

		ElseIf $sCmd = "log" Then
			Local $hFile = FileOpen($g_logfile, $FO_APPEND)
			If $hFile > 0 Then
				FileWrite($hFile, $sArg & @CRLF)
				FileClose($hFile)
			EndIf

		Else                                                            ; else send command
			If $sCmd = "write" Or $sCmd = "cmd" Then $sLine = StringMid($sLine, $iPos + 1)              ; strip optional command word
			$sLine = _EvaluateTextExpressions($sLine)                    ; do expression substitution
			If $g_visa_script_debug Then ConsoleWrite("__viScript(" & $viSession[0] & ", ...): sCmd='" & $sLine & "'" & @CRLF)
			__viCmd($viSession, $sLine)                                   ; send command to visa device
			If $g_visa_script_debug > 1 Then MsgBox(0, "visa script", $sLine)
			;Sleep($intervalDelay)
		EndIf
	WEnd
	FileClose($hFile)
	__viEnd($viSession)
EndFunc   ;==>__viScript


