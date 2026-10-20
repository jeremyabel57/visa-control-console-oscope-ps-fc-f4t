#include-once





#include <File.au3>
#include <FileConstants.au3>



;			__FileNameAutoIncrement
; task:		check if file exists, and append and/or increment _### number at the end of the file name to find a new file that does not exist
; in:		$sFilePath = path and file name of target save file
; out:		path/file name updated to next file name that does not exist
Func __FileNameAutoIncrement(ByRef $sFilePath)
	$sFilePath = _PathFull($sFilePath)
	If Not FileExists($sFilePath) Then Return $sFilePath        ; if file does not already exist, then we are good, no autoincrement needed

	Local $sDrive, $sDir, $sName, $sExt
	_PathSplit($sFilePath, $sDrive, $sDir, $sName, $sExt)
	Local $sFolder = $sDrive & $sDir
	Local $sBaseName = $sDrive & $sDir & $sName

	; Regex pattern explanation: (.*)_(\d+)$
	; Group 1: everything up to the underscore
	; Group 2: the digits at the end
	Local $sPattern = "(.*)_(\d+)$"
	Local $iNumLen, $sNumStr, $iNewNum

	If StringRegExp($sBaseName, $sPattern) Then
		$sNumStr = StringRegExpReplace($sBaseName, $sPattern, "$2")                     ; Capture the current number string
		$iNumLen = StringLen($sNumStr)                                                  ; Preserve the original padding length (e.g., 3 for 005)
		$sBaseName = StringRegExpReplace($sBaseName, $sPattern, "$1")                   ; strip number from basename
	Else
		$sNumStr = "001"                                                                ; if no number found, then start one
		$iNumLen = 3
	EndIf

	Local $sR = $sBaseName & "_" & $sNumStr & $sExt
	While FileExists($sR) And (Number($sNumStr) <> 0)                                    ; stop when file does not exist or number rolled over
		$iNewNum = Int($sNumStr) + 1                                                    ; Increment the number
		$sNumStr = StringFormat("%0" & $iNumLen & "d", $iNewNum)                        ; Reformat the number with leading zeros matching the original string length
		If Number($sNumStr) = 0 Then                                                    ; sNumStr = 0 means it rolled over - not enough digits, increase digits
			$iNumLen += 1
			$sNumStr = StringFormat("%0" & $iNumLen & "d", $iNewNum)                    ; Reformat the number with leading zeros matching the original string length
		EndIf
		$sR = $sBaseName & "_" & $sNumStr & $sExt
	WEnd
	$sFilePath = $sR
	Return $sR
EndFunc   ;==>__FileNameAutoIncrement






; ====================================================================================================
; Function Name:    __IsFullPathSpecified
; Description:      Evaluates if a path string contains a valid, absolute drive and folder structure.
; Parameter(s):     $sPath - The path string to evaluate.
; Return Value(s):  True  - It is a complete path (e.g., "C:\Folder\file.txt") -> Skip the dialog.
;                   False - It is a placeholder or filename only -> Show the dialog.
; ====================================================================================================
Func __IsFullPathSpecified($sPath)
	If $sPath == "" Or $sPath == "..." Then Return False                        ; 1. Filter out empty strings or default GUI placeholders
	Local $sDrive, $sDir, $sName, $sExt                                         ; 2. Deconstruct the path string components
	_PathSplit($sPath, $sDrive, $sDir, $sName, $sExt)
	If $sDrive <> "" And $sDir <> "" And $sDir <> "\" Then Return True          ; 3. If there is a root drive (e.g., "C:") and a folder path (e.g., "\temp\"), it is an absolute path
	Return False
EndFunc   ;==>__IsFullPathSpecified

