#include-once

#AutoIt3Wrapper_Icon=temperatureChamber2.ico
#AutoIt3Wrapper_UseX64=Y
#AutoIt3Wrapper_Change2CUI=N



;Opt("GUIOnEventMode", 1)
Global $SEP = Opt("GUIDataSeparatorChar")


#include <ProgressConstants.au3>
#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <GuiScrollBars.au3>
#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>
#include <FileConstants.au3>
#include <WinAPI.au3>
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>
#include <WinAPIFiles.au3>

;#include <Array.au3>
;#include <Visa.au3>
;#include "visadll.au3" ; VISA function calls that work With VXI - 11 And Raw Socket
;#include "modbustcp.au3" ; ModBus functions For working With VISA devices, including F4T thermal chamber
#include "windowresize.au3" ; window resize handlers With scroll bars



; Icon characters
Global Const $ICON_CFG = ChrW(0x2699)
Global Const $ICON_SCREENSHOT = ChrW(0xD83D) & ChrW(0xDCF7)
Global Const $ICON_STILL_CAMERA = $ICON_SCREENSHOT
Global Const $ICON_REFRESH = ChrW(0x21BB)
Global Const $ICON_POWERBTN = ChrW(0x23FB)
Global Const $ICON_DEGREE = ChrW(176) ; ChrW(0x00B0)
Global Const $ICON_DEGREEC = $ICON_DEGREE & "C" ; ChrW(0x2103)
Global Const $ICON_DEGREEF = $ICON_DEGREE & "F" ; ChrW(0x2104)
Global Const $ICON_GLASS = ChrW(0xD83D) & ChrW(0xDD0D)
Global Const $ICON_MENU1 = ChrW(0x2630)

Global Const $COLOR_NEUTRAL = 0xFDFDFD
Global Const $COLOR_GRAY = 0xFDFDFD
Global Const $COLOR_RED = 0xFF0000
Global Const $COLOR_GREEN = 0x00FF00
Global Const $COLOR_BLUE = 0x0000FF
Global Const $COLOR_YELLOW = 0xFFFF00
Global Const $COLOR_PURPLE = 0xFF00FF
Global Const $COLOR_BLACK = 0x000000
Global Const $COLOR_WHITE = 0xFFFFFF




;			__FileNameAutoIncrement
; task:		check if file exists, and append and/or increment _### number at the end of the file name to find a new file that does not exist
; in:		$sFilePath = path and file name of target save file
; out:		path/file name updated to next file name that does not exist
Func __FileNameAutoIncrement(byref $sFilePath)
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
	While FileExists($sR) and (Number($sNumStr) <> 0)									; stop when file does not exist or number rolled over
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





