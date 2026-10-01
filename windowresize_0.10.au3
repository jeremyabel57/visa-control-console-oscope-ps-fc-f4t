#include-once



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
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>
#include <WinAPI.au3>



Global $CANVAS_W			; width of the canvas of the main gui
Global $CANVAS_H			; height of the canvas of the main gui

; --- Windows Message Handlers ---



; Handle Window Resizing (Dynamically adjusts scroll thumb sizes and bounds)
Func WM_SIZE($hWnd, $Msg, $wParam, $lParam)
	#forceref $Msg, $wParam, $lParam, $CANVAS_H, $CANVAS_W
	Local $tSCROLLINFO = DllStructCreate($tagSCROLLINFO)
	DllStructSetData($tSCROLLINFO, "cbSize", DllStructGetSize($tSCROLLINFO))

	; CRITICAL: Tell Windows we are resetting BOTH the tracking page size AND the absolute range limit
	DllStructSetData($tSCROLLINFO, "fMask", BitOR($SIF_PAGE, $SIF_RANGE))
	DllStructSetData($tSCROLLINFO, "nMin", 0)

	; --- Adjust Vertical Scrollbar ---
	DllStructSetData($tSCROLLINFO, "nMax", $CANVAS_H)
	DllStructSetData($tSCROLLINFO, "nPage", _WinAPI_GetClientHeight($hWnd))
	_GUIScrollBars_SetScrollInfo($hWnd, $SB_VERT, $tSCROLLINFO)

	; --- Adjust Horizontal Scrollbar ---
	DllStructSetData($tSCROLLINFO, "nMax", $CANVAS_W)
	DllStructSetData($tSCROLLINFO, "nPage", _WinAPI_GetClientWidth($hWnd))
	_GUIScrollBars_SetScrollInfo($hWnd, $SB_HORZ, $tSCROLLINFO)

	Return 0
EndFunc   ;==>WM_SIZE



; Handle Vertical Scrollbar Actions
Func WM_VSCROLL($hWnd, $Msg, $wParam, $lParam)
	#forceref $Msg, $lParam
	Local $nScrollCode = BitAND($wParam, 0x0000FFFF)
	Local $nPos = BitShift($wParam, 16)
	_GUIScrollBars_ScrollWindow($hWnd, 0, _CalculateScrollDelta($hWnd, $SB_VERT, $nScrollCode, $nPos))
	Return 0
EndFunc   ;==>WM_VSCROLL



; Handle Horizontal Scrollbar Actions
Func WM_HSCROLL($hWnd, $Msg, $wParam, $lParam)
	#forceref $Msg, $lParam
	Local $nScrollCode = BitAND($wParam, 0x0000FFFF)
	Local $nPos = BitShift($wParam, 16)
	_GUIScrollBars_ScrollWindow($hWnd, _CalculateScrollDelta($hWnd, $SB_HORZ, $nScrollCode, $nPos), 0)
	Return 0
EndFunc   ;==>WM_HSCROLL



; Handle Mouse Wheel Events (For vertical scrolling)
Func WM_MOUSEWHEEL($hWnd, $Msg, $wParam, $lParam)
	#forceref $Msg, $lParam
	Local $iDelta = BitShift($wParam, 16) ; Positive = up, Negative = down
	Local $nScrollCode = 0 ; $SB_LINEUP
	If $iDelta < 0 Then $nScrollCode = 1 ; $SB_LINEDOWN

	; Execute scroll jump multiple times for smooth speed matching typical OS configurations
	For $i = 1 To 3
		_GUIScrollBars_ScrollWindow($hWnd, 0, _CalculateScrollDelta($hWnd, $SB_VERT, $nScrollCode, 0))
	Next
	Return 0
EndFunc   ;==>WM_MOUSEWHEEL



; Core Engine: Computes Pixel Shifting Delta Offsets cleanly
Func _CalculateScrollDelta($hWnd, $nBar, $nScrollCode, $nPos)
	Local $tSCROLLINFO = DllStructCreate($tagSCROLLINFO)
	DllStructSetData($tSCROLLINFO, "cbSize", DllStructGetSize($tSCROLLINFO))
	DllStructSetData($tSCROLLINFO, "fMask", $SIF_ALL)
	_GUIScrollBars_GetScrollInfo($hWnd, $nBar, $tSCROLLINFO)

	Local $iMin = DllStructGetData($tSCROLLINFO, "nMin")
	Local $iMax = DllStructGetData($tSCROLLINFO, "nMax")
	Local $iPage = DllStructGetData($tSCROLLINFO, "nPage")
	Local $iCurPos = DllStructGetData($tSCROLLINFO, "nPos")
	Local $iTrackPos = DllStructGetData($tSCROLLINFO, "nTrackPos")

	Local $iNewPos = $iCurPos

	Switch $nScrollCode
		Case 0 ; $SB_LINEUP / $SB_LINELEFT
			$iNewPos -= 20
		Case 1 ; $SB_LINEDOWN / $SB_LINERIGHT
			$iNewPos += 20
		Case 2 ; $SB_PAGEUP / $SB_PAGELEFT
			$iNewPos -= $iPage
		Case 3 ; $SB_PAGEDOWN / $SB_PAGERIGHT
			$iNewPos += $iPage
		Case 4, 5 ; $SB_THUMBPOSITION, $SB_THUMBTRACK
			$iNewPos = $iTrackPos
	EndSwitch

	Local $iMaxScrollable = $iMax - $iPage
	If $iMaxScrollable < $iMin Then $iMaxScrollable = $iMin ; Prevent negative track math

	If $iNewPos < $iMin Then $iNewPos = $iMin
	If $iNewPos > $iMaxScrollable Then $iNewPos = $iMaxScrollable

	Local $iDelta = $iCurPos - $iNewPos
	If $iDelta <> 0 Then
		_GUIScrollBars_SetScrollInfoPos($hWnd, $nBar, $iNewPos)
	EndIf

	Return $iDelta
EndFunc   ;==>_CalculateScrollDelta


#comments-start
; Win32 API Helpers to read window boundaries
Func _WinAPI_GetClientWidth($hWnd)
	Local $tRect = DllStructCreate($tagRECT)
	DllCall("user32.dll", "bool", "GetClientRect", "hwnd", $hWnd, "struct*", $tRect)
	Return DllStructGetData($tRect, "Right")
EndFunc   ;==>_WinAPI_GetClientWidth



; Win32 API Helpers to read window boundaries
Func _WinAPI_GetClientHeight($hWnd)
	Local $tRect = DllStructCreate($tagRECT)
	DllCall("user32.dll", "bool", "GetClientRect", "hwnd", $hWnd, "struct*", $tRect)
	Return DllStructGetData($tRect, "Bottom")
EndFunc   ;==>_WinAPI_GetClientHeight
#comments-end










; ------------ snap window position to the desktop area



Func _CustomGetMonitorInfo($hMonitor)
	; Clear error tracking states
	If $hMonitor = 0 Then Return SetError(1, 0, 0)

	; FIX: Flatten the RECT structs into explicit long integer coordinates.
	; cbSize (4 bytes) + rcMonitor (16 bytes) + rcWork (16 bytes) + dwFlags (4 bytes) = 40 bytes.
	Local $tMI = DllStructCreate("dword Size;" & _
			"long MonLeft;long MonTop;long MonRight;long MonBottom;" & _
			"long WorkLeft;long WorkTop;long WorkRight;long WorkBottom;" & _
			"dword Flags")

	DllStructSetData($tMI, "Size", DllStructGetSize($tMI))

	Local $aRet = DllCall("user32.dll", "bool", "GetMonitorInfoW", "handle", $hMonitor, "struct*", $tMI)
	If @error Or Not $aRet Then Return SetError(2, 0, 0)

	; Return an 11-element array to match native AutoIt _WinAPI_GetMonitorInfo syntax compatibility
	Local $aOut[11]
	$aOut[0] = 10

	; Physical Monitor Area Rectangle Coordinates
	$aOut[1] = DllStructGetData($tMI, "MonLeft")
	$aOut[2] = DllStructGetData($tMI, "MonTop")
	$aOut[3] = DllStructGetData($tMI, "MonRight")
	$aOut[4] = DllStructGetData($tMI, "MonBottom")

	; Selected Monitor's Usable Work Area Coordinates (Excludes taskbars on this display)
	$aOut[5] = DllStructGetData($tMI, "WorkLeft")
	$aOut[6] = DllStructGetData($tMI, "WorkTop")
	$aOut[7] = DllStructGetData($tMI, "WorkRight")
	$aOut[8] = DllStructGetData($tMI, "WorkBottom")

	; Monitor State Metadata Flags (e.g., MONITORINFOF_PRIMARY = 1)
	$aOut[9] = DllStructGetData($tMI, "Flags")

	Return $aOut
EndFunc   ;==>_CustomGetMonitorInfo



;		_WinSnapToDesktop
; task:		snap window into desktop area if it is outside of the area
; in:		iX, iY, iWidth, iHeight		of window
; out:		array [ iX, iY, iWidth, iHeight ] of adjusted values to fit within the multimonitor virtual desktop area
Func _WinSnapToDesktop($iX, $iY, $iWidth, $iHeight)

	Local $leftMargin = 10
	Local $topMargin = 10
	Local $rightMargin = 10
	Local $bottomMargin = 50
	Local $aTaskbarPos = WinGetPos("[CLASS:Shell_TrayWnd]")
	If Not @error Then
		$bottomMargin = 10 + $aTaskbarPos[3]
	EndIf

	; SM_XVIRTUALSCREEN & SM_YVIRTUALSCREEN handle setups where a secondary monitor
	; sits to the left or top of the primary monitor (which creates negative coordinates).
	Local $iVirtualLeft = _WinAPI_GetSystemMetrics($SM_XVIRTUALSCREEN) + $leftMargin
	Local $iVirtualTop = _WinAPI_GetSystemMetrics($SM_YVIRTUALSCREEN) + $topMargin
	Local $iVirtualWidth = _WinAPI_GetSystemMetrics($SM_CXVIRTUALSCREEN) - $leftMargin - $rightMargin
	Local $iVirtualHeight = _WinAPI_GetSystemMetrics($SM_CYVIRTUALSCREEN) - $topMargin - $bottomMargin

	Local $iVirtualRight = $iVirtualLeft + $iVirtualWidth
	Local $iVirtualBottom = $iVirtualTop + $iVirtualHeight

	Local $aAdjusted = [$iX, $iY, $iWidth, $iHeight]


	; Check if window is too far left or up of desktop area
	If $aAdjusted[0] < $iVirtualLeft Then                                                ; if to far left then
		$aAdjusted[0] = $iVirtualLeft                                                    ;   move to left side of desktop area
	EndIf                                                                                ; end if
	If $aAdjusted[1] < $iVirtualTop Then                                                 ; if to far up/north then
		$aAdjusted[1] = $iVirtualTop                                                     ;   move to top edge of desktop area
	EndIf                                                                                ; end if

	; Determine which monitor the upper left corner of the window is on
	;Local $tPoint = DllStructCreate("long X;long Y;")
	;DllStructSetData($tPoint, "X", $aAdjusted[0])
	;DllStructSetData($tPoint, "Y", $aAdjusted[1])
	Local $tPoint = _WinAPI_CreatePoint($aAdjusted[0], $aAdjusted[1])                    ; create point structure
	Local $hMonitor = _WinAPI_MonitorFromPoint($tPoint, $MONITOR_DEFAULTTONEAREST)      ; find which monitor or default to primary
	Local $aMonInfo = _CustomGetMonitorInfo($hMonitor)                                  ; get monitor desktop area dimensions
	If Not @error Then
		$iVirtualLeft = $aMonInfo[1] + $leftMargin                                            ; recalculate desktop area bounds
		$iVirtualTop = $aMonInfo[2] + $topMargin
		$iVirtualRight = $aMonInfo[3] - $rightMargin
		$iVirtualBottom = $aMonInfo[4] - $bottomMargin
		$iVirtualWidth = $aMonInfo[3] - $aMonInfo[1]
		$iVirtualHeight = $aMonInfo[4] - $aMonInfo[2]
	EndIf


	; Fix Horizontal Bounds (Left / Right edge of window)
	If ($aAdjusted[0] + $aAdjusted[2]) > $iVirtualRight Then                               ; if to far right then
		$aAdjusted[0] = $iVirtualRight - $iWidth                                           ;   move right edge of window of right side of desktop area
	EndIf                                                                                ; end if   and continue to check if it is now or has been too far left
	If $aAdjusted[0] < $iVirtualLeft Then                                                ; if to far left then
		$aAdjusted[0] = $iVirtualLeft                                                    ;   move to left side of desktop area
		If ($aAdjusted[2] > $iVirtualWidth) Then                                           ;   if the window is too wide then
			$aAdjusted[2] = $iVirtualWidth                                                ;     set window width to size of desktop area
		EndIf                                                                            ;   end if
	EndIf                                                                                ; end if

	; Fix Vertical Bounds (Top / Bottom edge of window)
	If ($aAdjusted[1] + $aAdjusted[3]) > $iVirtualBottom Then                             ; if to far down then
		$aAdjusted[1] = $iVirtualBottom - $iHeight                                        ;	snap to just fit at the bottom of the screen
	EndIf                                                                                ; end if   and continue to check if it is now or has been too far up
	If $aAdjusted[1] < $iVirtualTop Then                                                ; if to far up then
		$aAdjusted[1] = $iVirtualTop                                                    ;   snap to top of desktop area
		If $aAdjusted[3] > $iVirtualHeight Then                                            ;   if to tall to fit then
			$aAdjusted[3] = $iVirtualHeight                                                ;     set height to match desktop area
		EndIf                                                                            ;   end if
	EndIf                                                                                ; end if


	Return $aAdjusted                                                                    ; return adjusted position and size
EndFunc   ;==>_WinSnapToDesktop






