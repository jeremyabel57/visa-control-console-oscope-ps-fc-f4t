#include-once
#include <SendMessage.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <Array.au3>
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
#include <WinAPISysWin.au3>
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>
#include <WinAPI.au3>
#include <SliderConstants.au3>


; -------------------------------------------------------------------------
; INTERFACE GLOBAL GEOMETRY BOUNDS
; -------------------------------------------------------------------------
Global $__ArrayEdit2D_hMainGui
Global $__ArrayEdit2D_bCanvasUpdated = False    ; Cooperative main loop pooling synchronization flag
Global $__ArrayEdit2D_iLastXOffset = 0          ; Tracks active horizontal pixel displacement
Global $__ArrayEdit2D_iLastYOffset = 0          ; Tracks active vertical pixel displacement
Global $__ArrayEdit2D_CanvasW                      ; width of canvas
Global $__ArrayEdit2D_CanvasH                      ; height of canvas




; Matrix tracking metrics
Global $g_iRows = 6, $g_iCols = 5
Global $g_aData[$g_iRows][$g_iCols]

; Populate sample dummy data strings
For $r = 0 To $g_iRows - 1
	For $c = 0 To $g_iCols - 1
		$g_aData[$r][$c] = "Val " & $r & "," & $c
	Next
Next


__ArrayEdit2D($g_aData)

Exit



Func __ArrayEdit2D(ByRef $aArray, $title = "Edit Table", $iW = 300, $iH = 100, $iCW = 100, $iCH = 20)
	Local $iVx = 0                          ; cell currently in upper left corner of window
	Local $iVy = 0                          ; cell currently in upper left corner of window
	Local $iTh = UBound($aArray, 1)         ; number of rows in the entire table
	Local $iTw = UBound($aArray, 2)         ; number of columns in the entire table
	Local $aColumnWidths[$iTw]
	Local $aRowHeights[$iTh]
	Local $i, $x, $y

	Local $iOldOnEventMode = Opt("GUIOnEventMode", 0) ; Temporarily switch to standard Message-Loop mode

	If IsArray($iCH) Then
		$aRowHeights = $iCH
	Else
		For $y = 0 To $iTh - 1                    ; default row widths and column heights
			$aRowHeights[$y] = $iCH
		Next
	EndIf
	If IsArray($iCW) Then
		$aColumnWidths = $iCW
	Else
		For $x = 0 To $iTw - 1
			$aColumnWidths[$x] = $iCW
		Next
	EndIf


	; initialize the gui
	$__ArrayEdit2D_hMainGui = GUICreate($title, $iW, $iH, -1, -1, _
			BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX, $WS_VSCROLL, $WS_HSCROLL))
	__ArrayEdit2D_ArrayToEdit($aArray, $aColumnWidths, $aRowHeights, $__ArrayEdit2D_CanvasW, $__ArrayEdit2D_CanvasH)


	; Initialize the Scroll engine
	GUISetState(@SW_SHOW, $__ArrayEdit2D_hMainGui)

	; 1. Fire up the native scroll bar system structures
	_GUIScrollBars_Init($__ArrayEdit2D_hMainGui)
	_GUIScrollBars_SetScrollRange($__ArrayEdit2D_hMainGui, $SB_HORZ, 0, $__ArrayEdit2D_CanvasW)
	_GUIScrollBars_SetScrollRange($__ArrayEdit2D_hMainGui, $SB_VERT, 0, $__ArrayEdit2D_CanvasH)

	; 2. Bind the low-level system interactions to our unified router pipeline
	GUIRegisterMsg($WM_VSCROLL, "__ArrayEdit2D_ScrollMessageRouter")
	GUIRegisterMsg($WM_HSCROLL, "__ArrayEdit2D_ScrollMessageRouter")
	GUIRegisterMsg($WM_MOUSEWHEEL, "__ArrayEdit2D_ScrollMessageRouter")
	GUIRegisterMsg($WM_SIZE, "__ArrayEdit2D_ScrollMessageRouter")

	; 3. Run an initial manual execution sync pass to fit thumb layout metrics perfectly
	__ArrayEdit2D_ProcessCanvasWindowResize($__ArrayEdit2D_hMainGui, $__ArrayEdit2D_CanvasW, $__ArrayEdit2D_CanvasH)

	Local $nMsg
	Local $bKeepRunning = True

	While $bKeepRunning
		$nMsg = GUIGetMsg()

		Switch $nMsg
			Case $GUI_EVENT_CLOSE
				$bKeepRunning = False

		EndSwitch

		If $__ArrayEdit2D_bCanvasUpdated Then
			; scroll bars moved
		EndIf
	WEnd

	__ArrayEdit2D_EditToArray($aArray)
	GUIDelete($__ArrayEdit2D_hMainGui)



	Opt("GUIOnEventMode", $iOldOnEventMode)        ; Seamlessly restore previous script orchestration layout
EndFunc   ;==>__ArrayEdit2D



;			__ArrayEdit2D_ArrayToEdit
; task:		convert 2D array of data items to a list of pointers to GUI edit elements with the data inside them
; in:		$aArray = data array
;			$aColumnWidths
;			$aRowHeights
; out:		$aArray = array of pointers to gui edit boxes containing the data
;			$iW, $iH = resulting canvas size
Func __ArrayEdit2D_ArrayToEdit(ByRef $aArray, $aColumnWidths, $aRowHeights, ByRef $iW, ByRef $iH)
	Local $rowBorder = 2
	Local $columnBorder = 0
	Local $iXgui, $iCH, $iCW
	Local $iYgui = 0
	For $iY = 0 To UBound($aArray, 1) - 1
		$iXgui = 0
		$iCH = $aRowHeights[$iY]
		For $iX = 0 To UBound($aArray, 2) - 1
			$iCW = $aColumnWidths[$iX]
			$aArray[$iY][$iX] = GUICtrlCreateEdit($aArray[$iY][$iX], $iXgui, $iYgui, $iCW, $iCH, $ES_MULTILINE)
			GUICtrlSetResizing(-1, $GUI_DOCKALL)
			$iXgui += $iCW + $columnBorder
		Next
		$iYgui += $iCH + $rowBorder
	Next
	$iW = $iXgui - $columnBorder
	$iH = $iYgui - $rowBorder
EndFunc   ;==>__ArrayEdit2D_ArrayToEdit




;			__ArrayEdit2D_EditToArray
; task:		convert 2D array of data items to a list of pointers to GUI edit elements with the data inside them
; in:		$aArray = data array
; out:		$aArray = array of pointers to gui edit boxes containing the data
Func __ArrayEdit2D_EditToArray(ByRef $aArray)
	Local $iX, $iY
	For $iY = 0 To UBound($aArray, 1) - 1
		For $iX = 0 To UBound($aArray, 2) - 1
			$aArray[$iY][$iX] = GUICtrlRead($aArray[$iY][$iX])
		Next
	Next
EndFunc   ;==>__ArrayEdit2D_EditToArray



; -------------------------------------------------------------------------
; SYSTEM CENTRAL MASTER ROUTER WINDOWS INTERCEPT PIPELINE (FIXED)
; -------------------------------------------------------------------------
Func __ArrayEdit2D_ScrollMessageRouter($hWnd, $Msg, $wParam, $lParam)

	If $hWnd <> $__ArrayEdit2D_hMainGui Then Return $GUI_RUNDEFMSG

	Select
		Case $Msg = $WM_VSCROLL
			Local $nScrollCode = BitAND($wParam, 0x0000FFFF)
			Local $nPos = BitShift($wParam, 16)

			; 1. Compute the corrected relative scrolling adjustment value
			Local $iYDelta = __ArrayEdit2D_CalculatePanelDelta($hWnd, $SB_VERT, $nScrollCode, $nPos)

			; 2. Execute the pixel shift if a positional change occurred
			If $iYDelta <> 0 Then _GUIScrollBars_ScrollWindow($hWnd, 0, $iYDelta)
			$__ArrayEdit2D_bCanvasUpdated = True
			Return 0

		Case $Msg = $WM_HSCROLL
			Local $nScrollCode = BitAND($wParam, 0x0000FFFF)
			Local $nPos = BitShift($wParam, 16)

			; Compute and execute the horizontal pixel shift
			Local $iXDelta = __ArrayEdit2D_CalculatePanelDelta($hWnd, $SB_HORZ, $nScrollCode, $nPos)
			If $iXDelta <> 0 Then _GUIScrollBars_ScrollWindow($hWnd, $iXDelta, 0)
			$__ArrayEdit2D_bCanvasUpdated = True
			Return 0

		Case $Msg = $WM_MOUSEWHEEL
			Local $iDelta = BitShift($wParam, 16)
			Local $nScrollCode = ($iDelta < 0) ? 1 : 0 ; Map mouse steps: 1 = Linedown ($SB_LINEDOWN), 0 = Lineup ($SB_LINEUP)

			; Process standard multi-step mouse wheel pacing
			Local $iWheelDelta = __ArrayEdit2D_CalculatePanelDelta($hWnd, $SB_VERT, $nScrollCode, 0)
			If $iWheelDelta <> 0 Then _GUIScrollBars_ScrollWindow($hWnd, 0, $iWheelDelta)
			$__ArrayEdit2D_bCanvasUpdated = True
			Return 0

		Case $Msg = $WM_SIZE
			__ArrayEdit2D_ProcessCanvasWindowResize($hWnd, $__ArrayEdit2D_CanvasW, $__ArrayEdit2D_CanvasH)
			Return 0
	EndSelect

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__ArrayEdit2D_ScrollMessageRouter

; -------------------------------------------------------------------------
; INTERNAL MATH CALCULATION CORE ENGINES (FIXED & ALIGNED)
; -------------------------------------------------------------------------
Func __ArrayEdit2D_CalculatePanelDelta($hWnd, $nBar, $nScrollCode, $nPos)
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

	; Determine pixel jumping resolution steps based on column layout sizes
	Switch $nScrollCode
		Case 0 ; $SB_LINEUP / $SB_LINELEFT
			$iNewPos -= 24 ; Drop/raise exactly 24 pixels per step interaction
		Case 1 ; $SB_LINEDOWN / $SB_LINERIGHT
			$iNewPos += 24
		Case 2 ; $SB_PAGEUP / $SB_PAGELEFT
			$iNewPos -= $iPage
		Case 3 ; $SB_PAGEDOWN / $SB_PAGERIGHT
			$iNewPos += $iPage
		Case 4, 5 ; $SB_THUMBPOSITION, $SB_THUMBTRACK
			$iNewPos = $iTrackPos
	EndSwitch

	; Keep position modifications bound tightly within our logical canvas limits
	Local $iMaxScrollable = $iMax - $iPage
	If $iMaxScrollable < $iMin Then $iMaxScrollable = $iMin

	If $iNewPos < $iMin Then $iNewPos = $iMin
	If $iNewPos > $iMaxScrollable Then $iNewPos = $iMaxScrollable

	; CRITICAL INVERSION FIX:
	; Calculate the true directional difference. Moving down means controls shift UP (negative value).
	Local $iDelta = $iCurPos - $iNewPos

	If $iDelta <> 0 Then
		_GUIScrollBars_SetScrollInfoPos($hWnd, $nBar, $iNewPos)
		If $nBar = $SB_VERT Then $__ArrayEdit2D_iLastYOffset = $iNewPos
		If $nBar = $SB_HORZ Then $__ArrayEdit2D_iLastXOffset = $iNewPos
	EndIf

	Return $iDelta
EndFunc   ;==>__ArrayEdit2D_CalculatePanelDelta



Func __ArrayEdit2D_ProcessCanvasWindowResize($hWnd, $iCanvasW, $iCanvasH)
	Local $tSCROLLINFO = DllStructCreate($tagSCROLLINFO)
	DllStructSetData($tSCROLLINFO, "cbSize", DllStructGetSize($tSCROLLINFO))
	DllStructSetData($tSCROLLINFO, "fMask", BitOR($SIF_PAGE, $SIF_RANGE))
	DllStructSetData($tSCROLLINFO, "nMin", 0)

	; --- Rescale Vertical Bar Proportions ---
	;Local $iH = _WinAPI_GetClientHeight($hWnd)
	;Local $iHM = $iCanvasH - $iH
	;if $iHM < 0 then $iHM = 0
	DllStructSetData($tSCROLLINFO, "nMax", $iCanvasH)
	DllStructSetData($tSCROLLINFO, "nPage", _WinAPI_GetClientHeight($hWnd))
	_GUIScrollBars_SetScrollInfo($hWnd, $SB_VERT, $tSCROLLINFO)

	; --- Rescale Horizontal Bar Proportions ---
	;Local $iW = _WinAPI_GetClientWidth($hWnd)
	;Local $iWM = $iCanvasW - $iW
	;if $iWM < 0 then $iWM = 0
	DllStructSetData($tSCROLLINFO, "nMax", $iCanvasW)
	DllStructSetData($tSCROLLINFO, "nPage", _WinAPI_GetClientWidth($hWnd))
	_GUIScrollBars_SetScrollInfo($hWnd, $SB_HORZ, $tSCROLLINFO)

	;ConsoleWrite("iW=" & $iW & ", iWM=" & $iWM & ", iH=" & $iH & ", iHM=" & $iHM & @CRLF)
EndFunc   ;==>__ArrayEdit2D_ProcessCanvasWindowResize










; ====================================================================================================
; Function Name:    _GUICtrlEdit_CalculateRequiredWidth
; Description:      Calculates the exact pixel width required to display a string inside an edit control
;                   without causing text truncation or horizontal scrolling.
; Parameter(s):     $idEdit   - The Control ID or Window Handle (hWnd) of the Target Edit box.
;                   $sText    - The string text whose visual pixel boundary you want to evaluate.
; Return Value(s):  Success   - The precise pixel width required (Integer).
;                   Failure   - 0, sets @error.
; ====================================================================================================
Func __ArrayEdit2D_GUICtrlEdit_CalculateRequiredWidth($idEdit, $sText)
	; 1. Resolve control handle if a Control ID integer was passed instead of an hWnd pointer
	Local $hWndEdit = IsHWnd($idEdit) ? $idEdit : GUICtrlGetHandle($idEdit)
	If Not IsHWnd($hWndEdit) Then Return SetError(1, 0, 0)

	; 2. Fetch the true device context handle for the control
	Local $hDC = _WinAPI_GetDC($hWndEdit)
	If Not $hDC Then Return SetError(2, 0, 0)

	; 3. Query the control to see exactly what font structure it is using (WM_GETFONT = 0x0031)
	Local $hFont = _SendMessage($hWndEdit, 0x0031, 0, 0)
	Local $hOldFont = 0

	; If the control has a custom font assigned, temporarily map it into our evaluation context
	If $hFont <> 0 Then $hOldFont = _WinAPI_SelectObject($hDC, $hFont)

	; 4. Calculate the bounding size array [Width, Height] using the true text vector properties
	Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, $sText)
	Local $iCalculatedWidth = DllStructGetData($tSize, "X")

	; 5. Context Cleanup: Restore previous GDI environment mappings out of active RAM thread
	If $hOldFont <> 0 Then _WinAPI_SelectObject($hDC, $hOldFont)
	_WinAPI_ReleaseDC($hWndEdit, $hDC)

	; 6. CRITICAL STEP: Add internal structural buffer padding.
	;    Windows Edit boxes have non-client borders and internal character margins (typically 6-8px on each side).
	Local Const $iInternalBordersBuffer = 14

	Return $iCalculatedWidth + $iInternalBordersBuffer
EndFunc   ;==>__ArrayEdit2D_GUICtrlEdit_CalculateRequiredWidth

