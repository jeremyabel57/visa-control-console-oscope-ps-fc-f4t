#include-once





#include <File.au3>
#include <FileConstants.au3>
#include <GUIConstants.au3>
#include <GuiComboBox.au3>
#include <GuiComboBoxEx.au3>


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
	While FileExists($sR) And (Int($sNumStr) <> 0)                                      ; stop when file does not exist or number rolled over
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




; -------------------------------
; -------------------------------
; -------------------------------
; -------------------------------
; ini file read/write data types



Global $g_configFile, $g_configSection


Func __IniReadGui($cCtrl, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)
	GUICtrlSetData($cCtrl, IniRead($configFile, $configSection, $sKey, GUICtrlRead($cCtrl)))
EndFunc   ;==>__IniReadGui


Func __IniWriteGui($cCtrl, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)
	IniWrite($configFile, $configSection, $sKey, GUICtrlRead($cCtrl))
EndFunc   ;==>__IniWriteGui


Func __IniReadGuiCheckbox($hCheckbox, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)
	__GuiCheckbox($hCheckbox, Int(IniRead($configFile, $configSection, $sKey, Int(__GuiCheckbox($hCheckbox)))))
	;GUICtrlSetState($hCheckbox, _
	;		Number(IniRead($configFile, $configSection, $sKey, Number(GUICtrlRead($hCheckbox) = $GUI_CHECKED))) ? _
	;		$GUI_CHECKED : $GUI_UNCHECKED)
EndFunc   ;==>__IniReadGuiCheckbox

Func __IniWriteGuiCheckbox($hCheckbox, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)
	IniWrite($configFile, $configSection, $sKey, Number(__GuiCheckbox($hCheckbox)))
EndFunc   ;==>__IniWriteGuiCheckbox


Func __GuiCheckbox($hCheckbox, $bState = False)
	If @NumParams <= 1 Then Return (GUICtrlRead($hCheckbox) = $GUI_CHECKED)
	GUICtrlSetState($hCheckbox, $bState ? $GUI_CHECKED : $GUI_UNCHECKED)
EndFunc   ;==>__GuiCheckbox


Func __IniReadGuiComboBox($hCombo, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)
	GUICtrlSetData($hCombo, _
			IniRead($configFile, $configSection, $sKey & "List", _GUICtrlComboBox_GetList($hCombo)), _
			IniRead($configFile, $configSection, $sKey, GUICtrlRead($hCombo)))
EndFunc   ;==>__IniReadGuiComboBox

Func __IniWriteGuiComboBox($hCombo, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)
	IniWrite($configFile, $configSection, $sKey & "List", _GUICtrlComboBox_GetList($hCombo))
	IniWrite($configFile, $configSection, $sKey, GUICtrlRead($hCombo))
EndFunc   ;==>__IniWriteGuiComboBox



Func __IniReadArray($a, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)                  ; read array from ini file, return it
	Local $nr, $nc, $ir, $ic
	$nr = Int(IniRead($configFile, $configSection, $sKey & "r", 0))
	$nc = Int(IniRead($configFile, $configSection, $sKey & "c", 0))
	If $nc <= 0 Or $nr <= 0 Then                ; 1D array
		If $nr <= 0 Then $nr = $nc
		If $nr <= 0 Then $nr = Int(IniRead($configFile, $configSection, $sKey & "n", 0))
		If $nr <= 0 Then Return $a              ; no data found, return default
		Dim $a[$nr]
		$nr -= 1
		For $ir = 0 To $nr
			$a[$ir] = IniRead($configFile, $configSection, $sKey & $ir, '')
		Next
		Return $a
	EndIf
	If $nr <= 0 Then Return $a                  ; if no rows found then return default
	Dim $a[$nr][$nc]                            ; 2D array
	$nc -= 1
	$nr -= 1
	For $ir = 0 To $nr
		For $ic = 0 To $nc
			$a[$ir][$ic] = IniRead($configFile, $configSection, $sKey & $ir & "." & $ic, '')
		Next
	Next
	Return $a
EndFunc   ;==>__IniReadArray



Func __IniWriteArray($a, $sKey, $configSection = $g_configSection, $configFile = $g_configFile)        ; write array to ini file
	If Not IsArray($a) Then Return False
	If UBound($a, 0) < 1 Then Return False
	Local $nr, $nc, $ir, $ic
	$nr = UBound($a, 1)
	If $nr <= 0 Then Return False
	If UBound($a, 0) = 1 Then                   ; 1D array
		IniWrite($configFile, $configSection, $sKey & "n", $nr)
		$nr -= 1
		For $ir = 0 To $nr
			IniWrite($configFile, $configSection, $sKey & $ir, $a[$ir])
		Next
		Return True
	EndIf
	$nc = UBound($a, 2)                         ; 2D array
	If $nc <= 0 Then Return False
	IniWrite($configFile, $configSection, $sKey & "r", $nr)
	IniWrite($configFile, $configSection, $sKey & "c", $nc)
	$nr -= 1
	$nc -= 1
	For $ir = 0 To $nr
		For $ic = 0 To $nc
			IniWrite($configFile, $configSection, $sKey & $ir & "." & $ic, $a[$ir][$ic])
		Next
	Next
	Return True
EndFunc   ;==>__IniWriteArray






; ????????????????????????????????????


; save measurement to excel.  need to split this function into multiple functions - open, read, write, close(with save)

#include <Excel.au3>
#include <MsgBoxConstants.au3>

Func _CloudExcelWrite($vSheet, $iRow, $iCol, $vValue)
	; Clean URL direct file location string path
	Local Const $sUrl = "https://sharepoint.com...."

	; 1. Fire up a hidden background instance of Excel engine
	Local $oExcel = _Excel_Open(False)
	If @error Then Return SetError(1, @error, False)

	; 2. Call the native Workbooks.Open engine to handle the HTTP endpoint structure
	Local $oWorkbook = $oExcel.Application.Workbooks.Open($sUrl)
	If @error Then
		_Excel_Close($oExcel)
		Return SetError(2, @error, False)
	EndIf

	; 3. Convert numbers to a true coordinate string (e.g., column 3 -> "C")
	Local $sCellCoord = _Excel_ColumnToLetter($iCol) & $iRow

	; 4. Write data down to the targeted matrix cell
	_Excel_RangeWrite($oWorkbook, $vSheet, $vValue, $sCellCoord)
	If @error Then
		$oExcel.Application.Workbooks($oWorkbook.Name).Close(False) ; close without saving if it fails
		_Excel_Close($oExcel)
		Return SetError(3, @error, False)
	EndIf

	; 5. Save the stream back to the SharePoint server and exit cleanly
	$oWorkbook.Save()
	$oExcel.Application.Workbooks($oWorkbook.Name).Close()
	_Excel_Close($oExcel)
	Return True
EndFunc   ;==>_CloudExcelWrite


