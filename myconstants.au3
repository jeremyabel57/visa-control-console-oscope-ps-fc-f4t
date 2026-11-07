#include-once

Global $SEP = Opt("GUIDataSeparatorChar")

Opt("GUIOnEventMode", 1)                         ; Enable GUI OnEvent Mode globally


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
Global Const $ICON_FOLDER1 = ChrW(0xD83D) & ChrW(0xDCC1) ; ChrW32(0x1F4C1)
Global Const $ICON_FOLDER2 = ChrW32(0x1F4C2)
Global Const $ICON_SAVE = $ICON_FLOPPY
Global Const $ICON_OPEN = $ICON_FOLDER2
Global Const $ICON_CHECK = ChrW(0x2713)
Global Const $ICON_INFO1 = ChrW(0x2139)
Global Const $ICON_INFO2 = ChrW32(0x1F6C8)

Global Const $ICON_NWARROW1 = ChrW(0x2196)      ; direction arrows
Global Const $ICON_NWARROW2 = ChrW32(0x1F874)
Global Const $ICON_NEARROW1 = ChrW(0x2197)
Global Const $ICON_NEARROW2 = ChrW32(0x1F875)
Global Const $ICON_SEARROW1 = ChrW(0x2198)
Global Const $ICON_SEARROW2 = ChrW32(0x1F876)
Global Const $ICON_SWARROW1 = ChrW(0x2199)
Global Const $ICON_SWARROW2 = ChrW32(0x1F877)

Global Const $ICON_NARROW1 = ChrW(0x2191)
Global Const $ICON_NARROW2 = ChrW32(0x1F851)
Global Const $ICON_WARROW1 = ChrW(0x2192)
Global Const $ICON_WARROW2 = ChrW32(0x1F850)
Global Const $ICON_EARROW1 = ChrW(0x2194)
Global Const $ICON_EARROW2 = ChrW32(0x1F852)
Global Const $ICON_SARROW1 = ChrW(0x2195)
Global Const $ICON_SARROW2 = ChrW32(0x1F853)

Global Const $ICON_PLAY = ChrW(0x25B6)
Global Const $ICON_PAUSE = ChrW(0x23F8)
Global Const $ICON_STOP = ChrW(0x23F9)
Global Const $ICON_NEXT = ChrW(0x23ED)
Global Const $ICON_PREV = ChrW(0x23EE)


Global Const $COLOR_NEUTRAL = 0xFDFDFD
Global Const $COLOR_GRAY2 = 0xFDFDFD
;Global Const $COLOR_RED = 0xFF0000
Global Const $COLOR_GREEN2 = 0x00FF00
;Global Const $COLOR_BLUE = 0x0000FF
;Global Const $COLOR_YELLOW = 0xFFFF00
Global Const $COLOR_PURPLE2 = 0xFF00FF
;Global Const $COLOR_BLACK = 0x000000
;Global Const $COLOR_WHITE = 0xFFFFFF
;Global Const $COLOR_AZURE = 0x0080FF




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
	Local $iLowSurrogate = Mod($iBase, 0x400) + 0xDC00

	; 3. Concatenate the two 16-bit segments together into a single string stream
	Return ChrW($iHighSurrogate) & ChrW($iLowSurrogate)
EndFunc   ;==>ChrW32


