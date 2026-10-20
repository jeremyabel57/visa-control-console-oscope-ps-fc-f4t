#include-once

Global $SEP = Opt("GUIDataSeparatorChar")

Opt("GUIOnEventMode", 1) 						; Enable GUI OnEvent Mode globally


#include <ColorConstants.au3>


; Icon characters
Global Const $ICON_CFG = ChrW(0x2699)
Global Const $ICON_SCREENSHOT = ChrW(0xD83D) & ChrW(0xDCF7)
Global Const $ICON_STILL_CAMERA = $ICON_SCREENSHOT
Global Const $ICON_REFRESH = ChrW(0x27F3) ; ChrW(0x21BB)
Global Const $ICON_POWERBTN = ChrW(0x23FB)
Global Const $ICON_DEGREE = ChrW(176) ; ChrW(0x00B0)
Global Const $ICON_DEGREEC = $ICON_DEGREE & "C" ; ChrW(0x2103)
Global Const $ICON_DEGREEF = $ICON_DEGREE & "F" ; ChrW(0x2104)
Global Const $ICON_SEARCH = ChrW(0x2315)
Global Const $ICON_SEARCH2 = ChrW(0xD83D) & ChrW(0xDD0D) & ChrW(0xFE0E) ; ChrW(0xD83D) & ChrW(0xDD0D)
Global Const $ICON_GLASS = ChrW(0xD83D) & ChrW(0xDD0D)
Global Const $ICON_MENU1 = ChrW(0x2630)
Global Const $ICON_NET = ChrW(0xD83D) & ChrW(0xDDA7)
Global Const $ICON_TABS = ChrW(0xD83D) & ChrW(0xDDC2) ; ChrW(0x29C9) ; ChrW(0x2EB2)
Global Const $ICON_BOOK = ChrW(0xD83D) & ChrW(0xDD6E)
Global Const $ICON_FLOPPY = ChrW(0xD83D) & ChrW(0xDCBE) ; ChrW32(0x1F4BE)
Global Const $ICON_FOLDER = ChrW(0xD83D) & ChrW(0xDCC1) ; ChrW32(0x1F4C1)
Global Const $ICON_SAVE = $ICON_FLOPPY
Global Const $ICON_OPEN = $ICON_FOLDER

Global Const $COLOR_NEUTRAL = 0xFDFDFD
Global Const $COLOR_GRAY2 = 0xFDFDFD
;Global Const $COLOR_RED = 0xFF0000
Global Const $COLOR_GREEN2 = 0x00FF00
;Global Const $COLOR_BLUE = 0x0000FF
;Global Const $COLOR_YELLOW = 0xFFFF00
Global Const $COLOR_PURPLE2 = 0xFF00FF
;Global Const $COLOR_BLACK = 0x000000
;Global Const $COLOR_WHITE = 0xFFFFFF




; ===================================================================================================
; Function:    ChrW32
; Description: Converts a 32-bit Unicode Code Point into a valid UTF-16 Surrogate Pair string
; Parameter:   $iCodePoint - The 32-bit integer or hex value (e.g., 0x1F4BE)
; ===================================================================================================
Func ChrW32($iCodePoint)
	; Characters inside the Basic Multilingual Plane (0x0000 to 0xFFFF) fit inside a single ChrW
	If $iCodePoint <= 0xFFFF Then Return ChrW($iCodePoint)

	; 1. Shift the code point down into the surrogate working plane
	Local $iBase = $iCodePoint - 0x10000

	; 2. Apply bitwise shifts or standard division/modulo operators
	Local $iHighSurrogate = Int($iBase / 0x400) + 0xD800
	Local $iLowSurrogate  = Mod($iBase, 0x400) + 0xDC00

	; 3. Concatenate the two 16-bit segments together into a single string stream
	Return ChrW($iHighSurrogate) & ChrW($iLowSurrogate)
EndFunc   ;==>ChrW32


