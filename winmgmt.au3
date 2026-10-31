#include-once


#include "mydebug.au3"
#include "myconstants.au3"
#include "datatypes.au3"



#include <GuiTab.au3>
#include <ProgressConstants.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <MsgBoxConstants.au3>

#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <StructureConstants.au3>
#include <GUIConstantsEx.au3>

#include <ScrollBarConstants.au3>
#include <ScrollBarsConstants.au3>
#include <GuiScrollBars.au3>

#include <GuiToolTip.au3>
#include <GDIPlus.au3>

#include <Math.au3>

#include <WinAPISys.au3>
#include <WinAPIGdi.au3>
#include <WinAPI.au3>
#include <WinAPISysWin.au3>
#include <SendMessage.au3> ; Required For _SendMessage


#include "webview2tab.au3"
#include "winfuncs.au3"





Global $g_oGuiPics = ObjCreate("Scripting.Dictionary")
Global $g_oTabExec = ObjCreate("Scripting.Dictionary")
Global $g_cTab, $g_hTab, $g_oMainCanvas, $g_oCanvas


Global Const $CANVASZOOMTYPE_MIN = 2
Global Const $CANVASZOOMTYPE_FREE = 1




Func winmgmt_Init()                                                                                         ; Call this function after creating and showing the main gui to initialize
	;$g_oGuiPics = ObjCreate("Scripting.Dictionary")
	;$g_oTabExec = ObjCreate("Scripting.Dictionary")

	_GUIRegisterMsg($WM_SIZE, "__Canvas_WM_SIZE")                   ; window resized
	_GUIRegisterMsg($WM_VSCROLL, "__Canvas_WM_VSCROLL_HANDLER")     ; vertical scroll bar activity
	_GUIRegisterMsg($WM_HSCROLL, "__Canvas_WM_HSCROLL_HANDLER")     ; horizontal scroll bar activity
	_GUIRegisterMsg($WM_MOUSEWHEEL, "__Canvas_WM_MOUSEWHEEL")       ; mouse wheel activity
	;_GUIRegisterMsg($WM_NOTIFY, "__Canvas_BlockTabNativeToggle_Handler")   	; Tab control selection changed
	;_GUIRegisterMsg(0x0014, "__Canvas_WM_ERASEBKGND_Handler")       ; 0x0014 = $WM_ERASEBKGND ; Subclass the picture control to handle its messages directly

	GUICtrlSetOnEvent($g_cTab, "OnTabChange")                                                               ; register tab change event to function handler in winmgmt.au3
	OnTabChange()

	LoopRegister("__WinTitleNoteTrack")
	LoopRegister("MailboxVarLoop")
EndFunc   ;==>winmgmt_Init




; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; register functions to be called when tab control is changed
;

Global $g_hMainGui                                                                          ; main window handle


Func TabRegister($sFunction)                    ; register your function to run when an event occurs in the gui tab control
	$g_oTabExec.Item(String($sFunction)) = 1
EndFunc   ;==>TabRegister

Func TabUnregister($sFunction)                  ; unregister your function to run when gui tab control receives an event
	$g_oTabExec.Remove($sFunction)
EndFunc   ;==>TabUnregister


Func OnTabChange()                              ; this executes on change of tab gui control
	__WinLockRepaint()
	Local $iActiveTab = GUICtrlRead($g_cTab)
	Local $sActiveTab = _GUICtrlTab_GetItemText($g_hTab, $iActiveTab)
	__Canvas_OnTabChange($iActiveTab)
	For $sKey In $g_oTabExec
		;$g_oTabExec.Item(String($sActiveTab))
		Call($sKey, $iActiveTab, $sActiveTab, $g_hMainGui, $g_hTab)
	Next
	__WinUnlockRepaint()
EndFunc   ;==>OnTabChange


Func winmgmt_OnTabRegister($cTab)                                                       ; call this function after register the OnTabChange function below to your gui tab control $cTab
	$g_cTab = $cTab
	$g_hTab = GUICtrlGetHandle($cTab)
	GUICtrlSetOnEvent($cTab, "OnTabChange")
EndFunc   ;==>winmgmt_OnTabRegister



Func TabSwitch($iTab)                                                                   ; switch to a given tab
	$iTab = Int($iTab)
	Local $n = _GUICtrlTab_GetItemCount($g_hTab)
	If $iTab > $n Then $iTab = $n
	_GUICtrlTab_SetCurSel($g_hTab, $iTab)
	OnTabChange()
EndFunc   ;==>TabSwitch


; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; Tab Canvas functions
;   must first register tab control with winmgmt_OnTabRegister
;
;   register tab to use visible and resize functions below that work with a GUICreate canvas
;



Global $g_aCanvas[0]                                                                        ; list of canvas in each tab
Global $g_hCanvas = 0, $g_iTabW, $g_iTabH, $g_oCanvas                                       ; currently active tab
Global $g_hViewport = 0, $g_iViewportX, $g_iViewportY, $g_iViewportW, $g_iViewportH = 0     ; viewport canvas for the scrollbars



;		call this inside the main gui window creation in place of GUICtrlCreateTabItem to create a canvas with gui elements inside the tab page
;		this will create the tab element, then use GUICreate to make a child window that overlays the tab page
;		it will then register it in the list for the show/hide function and also the resize function
; in:	$sTabName = name of the tab
;		$fCanvasGuiCreate = function that creates the gui elements to populate the canvas inside this tab.  their parent will be the $hCanvas window.
;			this can return [ $iW, $iH ] as desired canvas size for use with scroll bars
;		$fTabGuiCreate = function that creates the gui element to populate this tab - their parent window will be $g_hMainGui
Func TabCreateCanvas($sTabName, $fCanvasGuiCreate = '', $fTabGuiCreate = '', $iType = $CANVASZOOMTYPE_FREE)
	__Canvas_Viewport_Init()

	Local $cTab = GUICtrlCreateTabItem($sTabName)
	Local $iTabIdx = _GUICtrlTab_FindTab($g_hTab, $sTabName)                                ; get the tab index number
	Local $iW = $g_iViewportW
	Local $iH = $g_iViewportH
	Local $oCanvas = ''
	__Canvas_Create($oCanvas, $iTabIdx, $iW, $iH, $iType, $cTab)                            ; create and add the canvas to the aCanvas array

	If $fTabGuiCreate <> '' Then Call($fTabGuiCreate, $iTabIdx, $oCanvas)                   ; call client function to populate the tab
	Local $hCanvas = GUICreate("Canvas", $iW, $iH, 0, 0, $WS_CHILD, -1, $g_hViewport)       ; create the canvas for the tab
	$oCanvas.Item('hWnd') = HWnd($hCanvas)
	;GUISwitch($hCanvas) 																	; select canvas
	Local $aSize
	If $fCanvasGuiCreate <> '' Then _
			$aSize = Call($fCanvasGuiCreate, $iTabIdx, $oCanvas, $hCanvas)                  ; call client function to populate the canvas
	GUISwitch($g_hMainGui)                                                                  ; set focus back to the main window / tab
	If IsArray($aSize) Then                                                                 ; if client gives us a preferred size then use it for the canvas size
		If UBound($aSize) >= 2 Then
			$iW = $aSize[0]
			$iH = $aSize[1]
		EndIf
	EndIf

	; SWP_NOMOVE (0x0002) ignores the X and Y parameters entirely.
	; SWP_NOZORDER (0x0004) retains the window's original placement in the Z-order stack.
	; SWP_NOACTIVATE (0x0010) prevents the window from stealing focus.
	_WinAPI_SetWindowPos($hCanvas, 0, 0, 0, $iW, $iH, BitOR($SWP_NOMOVE, $SWP_NOZORDER, $SWP_NOACTIVATE))       ; change just the size of the canvas to match desired

	$oCanvas.Item('iW') = $iW
	$oCanvas.Item('iH') = $iH
EndFunc   ;==>TabCreateCanvas



Func __Canvas_Create(ByRef $oCanvas, $iTabIdx = -1, $iW = 0, $iH = 0, $iType = $CANVASZOOMTYPE_FREE, $cTab = -1)
	If Not __IsDictionary($oCanvas) Then $oCanvas = ObjCreate("Scripting.Dictionary")
	$oCanvas.Item('iW') = $iW
	$oCanvas.Item('iH') = $iH
	$oCanvas.Item('iTabIdx') = $iTabIdx
	$oCanvas.Item('zoomType') = $iType
	$oCanvas.Item('bZoomNeedCataloged') = True
	If $iType = $CANVASZOOMTYPE_MIN Then
		$oCanvas.Item('iMinW') = $iW
		$oCanvas.Item('iMinH') = $iH
	EndIf
	$oCanvas.Item('cTab') = $cTab
	If $iTabIdx >= 0 Then
		If UBound($g_aCanvas) <= $iTabIdx Then ReDim $g_aCanvas[$iTabIdx + 1]
		$g_aCanvas[$iTabIdx] = $oCanvas
	EndIf
	Return $oCanvas
EndFunc   ;==>__Canvas_Create



Func __Canvas_Viewport_Init()
	If $g_iViewportH <> 0 Then Return                                                           ; if already initialized then return
	Local $aPageRect = _GUICtrlTab_GetDisplayRect($g_hTab)                                      ; get the dimensions of the tab page viewport area
	If @error Then Return SetError(@error, 0, 0)
	$g_iViewportX = $aPageRect[0]
	$g_iViewportY = $aPageRect[1]
	$g_iViewportW = $aPageRect[2] - $aPageRect[0]
	$g_iViewportH = $aPageRect[3] - $aPageRect[1]
	$g_hViewport = GUICreate("Viewport", $g_iViewportW, $g_iViewportH, $g_iViewportX, $g_iViewportY, $WS_CHILD, -1, $g_hMainGui)        ; create viewport canvas
	_GUIScrollBars_Init($g_hViewport)                           ; Initialize the custom Windows system scrollbar subsystem directly onto the viewport framework
	GUISwitch($g_hMainGui)
EndFunc   ;==>__Canvas_Viewport_Init



;		callback for tab changed event
Func __Canvas_OnTabChange($iActiveTab)
	If UBound($g_aCanvas) <= $iActiveTab Then ReDim $g_aCanvas[$iActiveTab + 1]

	Local $oCanvas, $hCanvas, $cTab
	Local $i, $n = UBound($g_aCanvas) - 1
	For $i = 0 To $n                                    ; hide all other registered tab canvases
		If $i = $iActiveTab Then ContinueLoop
		$oCanvas = $g_aCanvas[$i]
		If __IsDictionary($oCanvas) Then
			$hCanvas = HWnd($oCanvas.Item('hWnd'))
			If Number($hCanvas) <> 0 Then
				__API_ControlSetOnTopVisible($hCanvas, False)
				If __Canvas_IsWebView($oCanvas) Then _
						__WebView2Visible($oCanvas.Item('aWebView'), False)
			EndIf
			$cTab = $oCanvas.Item('cTab')
			GUICtrlSetState($cTab, $GUI_HIDE)
		EndIf
	Next

	$oCanvas = $g_aCanvas[$iActiveTab]
	$g_hCanvas = 0
	If __IsDictionary($oCanvas) Then $g_hCanvas = HWnd($oCanvas.Item('hWnd'))
	If $g_hCanvas = 0 Then
		__API_ControlSetOnTopVisible($g_hViewport, False)       ; make the viewport invisible so it does not cover other tab contents
		$g_oCanvas = 0                                          ; mark the global variables to signal we do not have a canvas
		$g_iTabW = 0
		$g_iTabH = 0
	Else
		If $oCanvas.Exists('bZoomNeedCataloged') Then __Canvas_ZoomCatalog($oCanvas)
		$g_oCanvas = $oCanvas
		$g_iTabW = $oCanvas.Item('iW')
		$g_iTabH = $oCanvas.Item('iH')
		$cTab = $oCanvas.Item('cTab')
		GUICtrlSetState($cTab, $GUI_SHOW)

		Local $bIsWebView = __Canvas_IsWebView($oCanvas)
		If Not $bIsWebView Then _
				__Canvas_AdjZoom($oCanvas)                      ; make sure all elements are scaled correctly
		__API_ControlSetOnTopVisible($g_hViewport, True)        ; make the viewport visible
		__API_ControlSetOnTopVisible($g_hCanvas, True)          ; make the canvas visible inside the viewport
		If $bIsWebView Then _
				__WebView2Visible($oCanvas.Item('aWebView'), True)
	EndIf

	__Canvas_WM_SIZE($g_hMainGui, 0, 0, 0)
	_WinAPI_RedrawWindow($g_hMainGui, 0, 0, _
			BitOR($RDW_UPDATENOW, $RDW_ALLCHILDREN))
	;BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))

EndFunc   ;==>__Canvas_OnTabChange



Func __API_ControlSetOnTopVisible($hWnd, $bVisible = True)
	Local $HWND_TOP = 0                 ; moves z-order to top if making it visible
	GUISetState(($bVisible ? @SW_SHOW : @SW_HIDE), HWnd($hWnd))
	_WinAPI_SetWindowPos(HWnd($hWnd), $HWND_TOP, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOACTIVATE, _
			($bVisible ? $SWP_SHOWWINDOW : BitOR($SWP_HIDEWINDOW, $SWP_NOZORDER))))
EndFunc   ;==>__API_ControlSetOnTopVisible


Func __API_ControlSetVisible($hWnd, $bVisible = True)
	Local $HWND_TOP = 0                 ; moves z-order to top
	;Local $SWP_NOMOVE = 0x0002         ; do not move x, y
	;Local $SWP_NOSIZE = 0x0001         ; do not change w, h
	; $SWP_NOZORDER = 0x0004			; do not change z
	;Local $SWP_SHOWWINDOW = 0x0040
	;Local $SWP_HIDEWINDOW = 0x0080
	;GUISetState(($bVisible ? @SW_SHOW : @SW_HIDE), HWnd($hWnd))
	_WinAPI_SetWindowPos(HWnd($hWnd), $HWND_TOP, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_NOACTIVATE, _
			($bVisible ? $SWP_SHOWWINDOW : $SWP_HIDEWINDOW)))
EndFunc   ;==>__API_ControlSetVisible




; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Canvas resize handler

Global $g_controlBarHeight

Func __Canvas_WM_SIZE($hWnd, $Msg, $wParam, $lParam)
	If $hWnd <> $g_hMainGui Then Return $GUI_RUNDEFMSG

	Local $aSize = WinGetClientSize($g_hMainGui)                                                            ; 1. Keep parent tab boundaries completely synchronized with physical window scaling adjustments
	GUICtrlSetPos($g_cTab, 0, 0, $aSize[0], $aSize[1] - $g_controlBarHeight)
	If $g_hCanvas = 0 Then Return $GUI_RUNDEFMSG                                                            ; if no Canvas child visible then do nothing more

	Local $aPageRect = _GUICtrlTab_GetDisplayRect($g_hTab)                                                  ; 2. Recalculate working viewport bounds inside the scaled tab components
	$g_iViewportX = $aPageRect[0]
	$g_iViewportY = $aPageRect[1]
	$g_iViewportW = $aPageRect[2] - $aPageRect[0] ; This is the visible width of your view window
	$g_iViewportH = $aPageRect[3] - $aPageRect[1] ; This is the visible height of your view window

	Local $iSBW = _WinAPI_GetSystemMetrics($SM_CXVSCROLL)                                                   ; add buffer for vertical scroll bar
	Local $iSBH = _WinAPI_GetSystemMetrics($SM_CYHSCROLL)                                                   ; add buffer for horizontal scroll bar

	Local $zType = $CANVASZOOMTYPE_FREE                                                                     ; zoomType:  if viewport smaller than canvas, then scrollbars control viewport of larger canvas
	If __IsDictionary($g_oCanvas) Then $zType = $g_oCanvas.Item('zoomType')                                 ; zoomType MIN = if viewport larger than canvas then scale the canvas to match viewport.  otherwise leave canvas scale alone
	Local $iSX, $iSY, $iPW, $iMinW, $iMaxW, $iPH, $iMinH, $iMaxH
	Local $iTabMinH = $g_oCanvas.Item('iMinH'), $iTabH = $g_iTabH
	Local $iTabMinW = $g_oCanvas.Item('iMinW'), $iTabW = $g_iTabW
	__Canvas_GetScrollPos($iSX, $iSY)                                                                       ; get current scroll bar offset position
	If $zType = $CANVASZOOMTYPE_MIN Then
		If $g_iTabH <= $g_iViewportH Then $iSBW = 0
		If $g_iTabW <= $g_iViewportW Then $iSBH = 0
	EndIf
	__Canvas_CheckScrollPos($iSY, $iPH, $iMinH, $iMaxH, $g_iTabH, $g_iViewportH, $iTabMinH, $zType, $iSBH)                      ; adjust to new viewport dimensions, assuming we have horizontal scroll bar
	__Canvas_CheckScrollPos($iSX, $iPW, $iMinW, $iMaxW, $g_iTabW, $g_iViewportW, $iTabMinW, $zType, ($iMaxH = 0) ? 0 : $iSBW)   ; adjust to new viewport dimensions, knowing we have or do not have vertical scroll bar
	If $iMaxW = 0 Then __Canvas_CheckScrollPos($iSY, $iPH, $iMinH, $iMaxH, $g_iTabH, $g_iViewportH, $iTabMinH, $zType, 0)       ; readjust to new viewport dimensions, knowing if we have horizontal scroll bar

	If $iTabW <> $g_iTabW Or $iTabH <> $g_iTabH Then
		_WinAPI_SetWindowPos($g_hCanvas, 0, -$iSX, -$iSY, $g_iTabW, $g_iTabH, _                             ; scroll/move canvas to new position
				BitOR($SWP_NOZORDER, $SWP_NOACTIVATE))                                                      ; also resize canvas
		If __IsDictionary($g_oCanvas) Then
			$g_oCanvas.Item('iW') = $g_iTabW                                                                ; save new width
			$g_oCanvas.Item('iH') = $g_iTabH                                                                ; save new height
			If $g_oCanvas.Exists('aWebView') Then                                                           ; if this is a webview then resize webview bounds to match
				Local $aWebView = $g_oCanvas.Item('aWebView')
				If IsArray($aWebView) Then _WebView2_SetBounds($aWebView, 0, 0, $g_iTabW, $g_iTabH)
			EndIf
		EndIf
	Else
		_WinAPI_SetWindowPos($g_hCanvas, 0, -$iSX, -$iSY, 0, 0, _                                           ; scroll/move canvas to new position, preserve size
				BitOR($SWP_NOSIZE, $SWP_NOZORDER, $SWP_NOACTIVATE))                                         ; SWP_NOSIZE (0x0001) preserves the canvas tracking width/height ($g_iTabW, $g_iTabH)
	EndIf
	_WinAPI_SetWindowPos($g_hViewport, 0, $g_iViewportX, $g_iViewportY, $g_iViewportW, $g_iViewportH, _     ; resize the viewport to match new window size
			BitOR($SWP_NOREDRAW, $SWP_NOZORDER, $SWP_NOACTIVATE))                                           ; SWP_NOREDRAW (0x0008) = no repainting.  SWP_NOZORDER (0x0004) = don't change z order.  SWP_NOACTIVE (0x0010) = do not activate or change focus to this window pane
	__API_UpdateScrollbarMetrics($g_hViewport, $SB_HORZ, $iMinH, $iMaxW, $iPW, Abs($iSX))                   ; update the horizontal scrollbar
	__API_UpdateScrollbarMetrics($g_hViewport, $SB_VERT, $iMinH, $iMaxH, $iPH, Abs($iSY))                   ; update the vertical scrollbar

	If __IsDictionary($g_oCanvas) Then                                                                      ; if available then
		$g_oCanvas.Item('iSX') = $iSX                                                                       ;   update canvas scroll bar positions
		$g_oCanvas.Item('iSY') = $iSY                                                                       ;
	EndIf                                                                                                   ; endif

	Return 0
	;Return $GUI_RUNDEFMSG
EndFunc   ;==>__Canvas_WM_SIZE



Func __Canvas_GetScrollPos(ByRef $iX, ByRef $iY)
	If Int($g_hViewport) <> 0 Then
		$iX = _GUIScrollBars_GetScrollInfoPos($g_hViewport, $SB_HORZ)
		$iY = _GUIScrollBars_GetScrollInfoPos($g_hViewport, $SB_VERT)
		If $iX < 0 Then $iX = 0   ; if above scrollbar function call returns -1 error then reset to 0
		If $iY < 0 Then $iY = 0   ; if above scrollbar function call returns -1 error then reset to 0
		If $g_iViewportW > $g_iTabW Then $iX = -$iX                                                         ; if canvas is smaller than viewport then we are using negative positions
		If $g_iViewportH > $g_iTabH Then $iY = -$iY
	EndIf
	If __IsDictionary($g_oCanvas) Then                                                                      ; Pull scroll offset from prior record or viewport scrollbars
		If $g_oCanvas.Exists('iSX') Then $iX = $g_oCanvas.Item('iSX')
		If $g_oCanvas.Exists('iSY') Then $iY = $g_oCanvas.Item('iSY')
	EndIf
EndFunc   ;==>__Canvas_GetScrollPos



Func __Canvas_CheckScrollPos(ByRef $iPos, ByRef $iPage, ByRef $iMin, ByRef $iMax, ByRef $iTabLen, $iViewLen, $iTabMin, $iType, $iSBlen = 0)
	Local $iViewLenSB = Int($iViewLen) - Int($iSBlen)
	Local $iPosMin, $iPosMax                                        ; make sure scroll bar metrics are in bounds to keep canvas and viewport over each other
	If $iTabLen < $iViewLenSB Then                                  ; if tab is smaller than viewport then
		If $iType = $CANVASZOOMTYPE_MIN Then                        ;   if zoomtype is Min size mode then
			If $iTabMin <= $iViewLenSB Then                         ;     if viewport still larger than canvas minimum then
				$iTabLen = $iViewLen                                ;       scale tab to fill viewport
				$iPosMin = 0                                        ;       set scrollbars metrics to be invisible
				$iPosMax = 0                                        ;
				$iPage = 1
				$iMin = 0
				$iMax = 0
				$iPos = 0
			Else                                                    ;     else we have reached smallest canvas scale, now viewport will become smaller than canvas
				$iTabLen = $iTabMin                                 ;       set iTabLen to its minimum and this will be processed on the next If $iTabLen >= $iViewLenSB statement
			EndIf
		Else                                                        ;   else scrollbars control position of canvas inside the dimensions of the viewport
			$iPosMin = -$iViewLenSB ; + $iSBlen ; $iTabLen - $iViewLenSB                       ;     tab to viewport offset range is delta to 0
			$iPosMax = 0                                            ;     ;
			$iPage = $iTabLen                                       ;     scrollbar page is the smaller dimension
			$iMin = 0                                               ;     scrollbar min is 0
			$iMax = $iViewLenSB                                     ;     scrollbar max is the larger dimension between canvas and viewport
		EndIf                                                       ;   end if
	EndIf
	If $iTabLen >= $iViewLenSB Then                                 ; else tab is equal to or larger than viewport
		If $iType = $CANVASZOOMTYPE_MIN Then                        ;   if zoomtype is Min size mode then
			$iTabLen = ($iViewLenSB < $iTabMin) ? $iTabMin : $iViewLenSB ;  scale tab down to viewport or tab minimum
		EndIf
		$iPosMin = 0                                                ;   tab to viewport offset range is 0 to delta
		$iPosMax = $iTabLen                                         ;
		$iPage = $iViewLenSB                                        ;   scrollbar page is the smaller dimension
		$iMin = 0                                                   ;   scrollbar min is 0
		$iMax = $iTabLen                                            ;   scrollbar max is the larger dimension between canvas and viewport
		If $iTabLen - $iViewLen <= $iSBlen Then
			$iMax = 0
			$iPosMax = 0
		EndIf
	EndIf                                                           ; end if

	If $iPos < $iPosMin Then $iPos = $iPosMin                       ; keep position within bounds
	If $iPos > $iPosMax Then $iPos = $iPosMax                       ;
EndFunc   ;==>__Canvas_CheckScrollPos




; =======================================================================================================================
; Function Name:    _API_UpdateScrollbarMetrics
; Description:      Updates nMin, nMax, nPage, and nPos on a target window scrollbar using exact structural bitmasking.
; Parameter(s):     $hWnd     - The window handle (HWND) hosting the target scroll bar framework.
;                   $iBar     - The target scrollbar direction constant ($SB_HORZ or $SB_VERT).
;                   $iMin     - The new minimum tracking boundary.
;                   $iMax     - The new maximum layout boundary.
;                   $iPage    - The new visible page size footprint.
;                   $iPos     - The new tracking thumb position.
; Return Value(s):  True on success, False on failure.
; =======================================================================================================================
Func __API_UpdateScrollbarMetrics($hWnd, $iBar, $iMin, $iMax, $iPage, $iPos)
	Local $tSI = DllStructCreate($tagSCROLLINFO)                                ; Instantiate a clean Win32 SCROLLINFO structure layout template
	DllStructSetData($tSI, "cbSize", DllStructGetSize($tSI))
	DllStructSetData($tSI, "fMask", BitOR($SIF_RANGE, $SIF_PAGE, $SIF_POS))     ; SIF_RANGE (0x0001) maps nMin and nMax.
	DllStructSetData($tSI, "nMin", $iMin)                                       ; SIF_PAGE  (0x0002) maps nPage.
	DllStructSetData($tSI, "nMax", $iMax)                                       ; SIF_POS   (0x0004) maps nPos.
	DllStructSetData($tSI, "nPage", $iPage)                                     ; This excludes SIF_DISABLENOSCROLL (0x0008) and guarantees no other state data is written.
	DllStructSetData($tSI, "nPos", $iPos)                                       ; Apply parameter sets down to raw memory offsets
	Return _GUIScrollBars_SetScrollInfo($hWnd, $iBar, $tSI)                     ; Push structure down to the Win32 API window manager pipeline
EndFunc   ;==>__API_UpdateScrollbarMetrics




; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Canvas scroll handlers


Func __Canvas_WM_VSCROLL_HANDLER($hWnd, $Msg, $wParam, $lParam)
	If $hWnd <> $g_hViewport Then Return $GUI_RUNDEFMSG
	Local $nScrollCode = BitAND($wParam, 0x0000FFFF)
	Local $nPos = BitShift($wParam, 16)
	__Canvas_Scroll($hWnd, $SB_VERT, $nScrollCode, $nPos)
	Return 0    ;	we do not need the windows native handlers to recalculate anything more
EndFunc   ;==>__Canvas_WM_VSCROLL_HANDLER



Func __Canvas_WM_HSCROLL_HANDLER($hWnd, $Msg, $wParam, $lParam)
	If $hWnd <> $g_hViewport Then Return $GUI_RUNDEFMSG
	Local $nScrollCode = BitAND($wParam, 0x0000FFFF)
	Local $nPos = BitShift($wParam, 16)
	__Canvas_Scroll($hWnd, $SB_HORZ, $nScrollCode, $nPos)
	Return 0    ;	we do not need the windows native handlers to recalculate anything more
EndFunc   ;==>__Canvas_WM_HSCROLL_HANDLER



; Handle Mouse Wheel Events (For vertical scrolling or zooming)
Func __Canvas_WM_MOUSEWHEEL($hWnd, $Msg, $wParam, $lParam)
	If $hWnd <> $g_hMainGui Then Return $GUI_RUNDEFMSG

	Local $iDelta = BitShift($wParam, 16)                               ; Positive = up, Negative = down
	Local $fRet = 1                                                     ; default to 'handled' so we return 0
	Local $iModifiers = BitAND($wParam, 0xFFFF)                         ; keyboard modifier keys
	Local $MK_CONTROL = 0x0008                                          ;
	If BitAND($iModifiers, $MK_CONTROL) = $MK_CONTROL Then              ; if control key is held down then zoom instead of scroll
		Local $fZoomAdj = ($iDelta >= 0) ? +0.05 : -0.05
		Local $aMouse = MouseGetPos()                                   ;   Gets absolute screen positions [0]=X, [1]=Y
		Local $tRectView = _WinAPI_GetWindowRect($g_hViewport)          ;
		If $aMouse[0] >= DllStructGetData($tRectView, "Left") And _     ;
				$aMouse[0] < DllStructGetData($tRectView, "Right") And _
				$aMouse[1] >= DllStructGetData($tRectView, "Top") And _
				$aMouse[1] < DllStructGetData($tRectView, "Bottom") Then ;  if mouse is inside viewport then
			If __Canvas_IsWebView($g_oCanvas) Then Return $GUI_RUNDEFMSG ;    if webview then pass mousewheel events along
			$fRet = __Canvas_AdjZoom($g_oCanvas, $fZoomAdj, True)       ;     zoom the viewport canvas
		Else                                                            ;   else
			$fRet = __Canvas_AdjZoom($g_oMainCanvas, $fZoomAdj * 2, True) ;   zoom the tab bar and other elements of main window
		EndIf                                                           ;   end if
	Else                                                                ; else
		If __Canvas_IsWebView($g_oCanvas) Then Return $GUI_RUNDEFMSG    ;   if webview then pass mousewheel events along
		Local $nScrollCode = 0                                          ;   $SB_LINEUP
		If $iDelta < 0 Then $nScrollCode = 1                            ;   $SB_LINEDOWN
		For $i = 1 To 3                                                 ;   Execute scroll jump multiple times for smooth speed matching typical OS configurations
			__Canvas_Scroll($g_hViewport, $SB_VERT, $nScrollCode, 0)
		Next
		;$fRet = 1
	EndIf                                                               ; end if
	Return (($fRet = 0) ? $GUI_RUNDEFMSG : 0)                           ; return 0 to stop any other event triggers from intercepting this event, if $fRet=0 then return $GUI_RUNDEFMSG to run other triggers
EndFunc   ;==>__Canvas_WM_MOUSEWHEEL



; Compute Pixel Shifting Delta Offsets
Func __Canvas_Scroll($hWnd, $nBar, $nScrollCode, $nPos)
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
		Case 0                      ; $SB_LINEUP / $SB_LINELEFT
			$iNewPos -= 20
		Case 1                      ; $SB_LINEDOWN / $SB_LINERIGHT
			$iNewPos += 20
		Case 2                      ; $SB_PAGEUP / $SB_PAGELEFT
			$iNewPos -= $iPage
		Case 3                      ; $SB_PAGEDOWN / $SB_PAGERIGHT
			$iNewPos += $iPage
		Case 4, 5                   ; $SB_THUMBPOSITION, $SB_THUMBTRACK
			$iNewPos = $iTrackPos
	EndSwitch

	Local $iMaxScrollable = $iMax - $iPage
	If $iMaxScrollable < $iMin Then $iMaxScrollable = $iMin                 ; Prevent negative track math

	If $iNewPos < $iMin Then $iNewPos = $iMin
	If $iNewPos > $iMaxScrollable Then $iNewPos = $iMaxScrollable

	If $iCurPos <> $iNewPos Then
		Local $iSX, $iSY, $iP, $iMin, $iMax, $iTabMin, $iSBlen
		__Canvas_GetScrollPos($iSX, $iSY)                                   ; get current scroll bar offset position
		If $nBar = $SB_HORZ Then
			If $g_iViewportW > $g_iTabW Then $iNewPos = -$iNewPos           ; if canvas smaller than viewport then we are using negative positions
			__Canvas_CheckScrollPos($iNewPos, $iP, $iMin, $iMax, $g_iTabW, $g_iViewportW, $iTabMin, $CANVASZOOMTYPE_FREE, $iSBlen)  ; keep newposition within bounds
			$iSX = $iNewPos
		ElseIf $nBar = $SB_VERT Then
			If $g_iViewportH > $g_iTabH Then $iNewPos = -$iNewPos           ; if canvas smaller than viewport then we are using negative positions
			__Canvas_CheckScrollPos($iNewPos, $iP, $iMin, $iMax, $g_iTabH, $g_iViewportH, $iTabMin, $CANVASZOOMTYPE_FREE, $iSBlen)  ; keep newposition within bounds
			$iSY = $iNewPos
		EndIf

		Local $tSI = DllStructCreate($tagSCROLLINFO)                        ; update scroll bar internal position number nPos
		DllStructSetData($tSI, "cbSize", DllStructGetSize($tSI))
		DllStructSetData($tSI, "fMask", $SIF_POS)                           ; SIF_POS (0x0004) tells Windows we are only updating the numerical position value.
		DllStructSetData($tSI, "nPos", Abs($iNewPos))
		_GUIScrollBars_SetScrollInfo($hWnd, $nBar, $tSI)                    ; Pass the structure cleanly to update the scrollbar thumb without triggering native frame jumping

		If __IsDictionary($g_oCanvas) Then                                  ; save current scrollbar position in the tab's canvas data structure
			If $nBar = $SB_HORZ Then
				$g_oCanvas.Item('iSX') = $iSX
			ElseIf $nBar = $SB_VERT Then
				$g_oCanvas.Item('iSY') = $iSY
			EndIf
		EndIf
		_WinAPI_SetWindowPos($g_hCanvas, 0, -$iSX, -$iSY, 0, 0, _           ; scroll canvas to absolute position
				BitOR($SWP_NOSIZE, $SWP_NOZORDER, $SWP_NOACTIVATE))         ; SWP_NOSIZE (0x0001) preserves the canvas tracking width/height ($g_iTabW, $g_iTabH)

	EndIf
EndFunc   ;==>__Canvas_Scroll



; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Canvas zoom functions





Func __Canvas_ZoomCatalog($oCanvas)                                             ; catalog all window elements in the gui for later zooming
	If Not __IsDictionary($oCanvas) Then Return
	Local $hCanvas = HWnd($oCanvas.Item('hWnd'))
	If Number($hCanvas) = 0 Then Return SetError(-1, 0, False)
	Local $i, $n
	Local $iColumn = -2                                                         ; column and row to pull data from $aChildren or $aList
	Local $aChildren = $oCanvas.Item('aCtrls')
	$oCanvas.Remove('bZoomNeedCataloged')
	;__ConsolePrintVars("zoomCatalog, ","aChildren",$aChildren,"oCanvas",$oCanvas)
	If IsArray($aChildren) Then
		If UBound($aChildren, 0) = 2 Then
			Local $iColCount = UBound($aChildren, 2)
			If $iColCount >= 6 Then Return                                      ; array already created and control list processed
			If $iColCount = 2 Then                                              ; if we have a list of children windows already then set $iColumn for processing
				$iColumn = 0
				$n = $aChildren[0][0]
			EndIf
		Else
			$n = UBound($aChildren)
			If $n > 0 Then $iColumn = -1                                        ; if provided list is not empty then process as list of children hWnd handles
		EndIf
	EndIf
	If $iColumn < -1 Then                                                       ; if no valid list exists yet then enumerate the children windows/controls/elements
		$aChildren = _WinAPI_EnumChildWindows(HWnd($hCanvas), False)            ; 2nd param=false so it does not error out when the handle is not fully visible yet
		If @error Then Return SetError(@error, 0, False)
		$iColumn = 0
		$n = $aChildren[0][0]
	EndIf

	Local $iPW = $oCanvas.Item('iW')
	Local $iPH = $oCanvas.Item('iH')

	Local $hCtrl, $aPos
	Local $aCtrls[$n + 1][6]
	$aCtrls[0][0] = $hCanvas                                                    ; window handle of the canvas
	$aCtrls[0][1] = $n                                                          ; number of controls in this array
	$aCtrls[0][3] = $iPW                                                        ; canvas base/original width
	$aCtrls[0][4] = $iPH                                                        ; canvas base/original height

	For $i = 1 To $n
		If $iColumn < 0 Then
			$hCtrl = $aChildren[$i - 1]
		Else
			$hCtrl = $aChildren[$i][$iColumn]
		EndIf
		$hCtrl = HWnd($hCtrl)
		$aPos = __API_ControlGetPos($hCtrl)                                     ; look up coordinates relative to its actual immediate parent so nested groups scale uniformly.
		$aCtrls[$i][0] = $hCtrl                                                 ; control window handle
		$aCtrls[$i][1] = $aPos[0]                                               ; X
		$aCtrls[$i][2] = $aPos[1]                                               ; Y
		$aCtrls[$i][3] = $aPos[2]                                               ; W
		$aCtrls[$i][4] = $aPos[3]                                               ; H
		$aCtrls[$i][5] = __API_ControlGetFontSize($hCtrl)                       ; font size
	Next
	$oCanvas.Item('aCtrls') = $aCtrls
	If Not $oCanvas.Exists('fzScale') Then $oCanvas.Item('fzScale') = 1.0

EndFunc   ;==>__Canvas_ZoomCatalog



Func __Canvas_AdjZoom($oCanvas, $fAdj = 0, $UX = False)
	If Not __IsDictionary($oCanvas) Then Return 0
	Local $fZoom = $oCanvas.Item('fzScale')
	If Number($fZoom) = 0 Then $fZoom = 1.0
	$fZoom += $fAdj
	If 0.97 < $fZoom And $fZoom < 1.03 Then $fZoom = 1.0                     ; if within 3% of 100% then snap to 100%
	Return __Canvas_SetZoom($oCanvas, $fZoom, $UX)
EndFunc   ;==>__Canvas_AdjZoom



Func __Canvas_SetZoom($oCanvas, $fNewScale = "", $UX = False)
	If Not __IsDictionary($oCanvas) Then Return 0
	If __Canvas_IsWebView($oCanvas) Then Return 0
	;__ConsolePrintVars("__Canvas_SetZoom, ", 'fNewScale', $fNewScale, 'oCanvas width', $oCanvas.Item('iW'))
	If Number($fNewScale) = 0 Then $fNewScale = 1.0                         ; if $fNewScale is invalid then reset to 1.0
	Local $aCtrls = $oCanvas.Item('aCtrls')                                 ; get the gui control elements array from the canvas object
	;__ConsolePrintVars("__Canvas_SetZoom, ", "aCtrls", $aCtrls)
	If Not IsArray($aCtrls) Then Return 0                                   ; must be array
	If UBound($aCtrls, 0) <> 2 Then Return 0                                ; 2D
	If UBound($aCtrls, 2) < 6 Then Return 0                                 ; at least 6 columns
	If UBound($aCtrls, 1) < 2 Then Return 0                                 ; at least control [1+] in addition to the canvas entry [0]

	Local $fMinZoom = 0.1
	Local $fMaxZoom = 10.0
	If $fNewScale < $fMinZoom Then $fNewScale = $fMinZoom                   ; lower scale limit of 10% (1/10)
	If $fNewScale > $fMaxZoom Then $fNewScale = $fMaxZoom                   ; upper scale limit of 10x

	Local $hCanvas = $aCtrls[0][0]                                          ; canvas handle
	If Number($hCanvas) = 0 Then $hCanvas = $g_hMainGui
	Local $bCanvas = ($hCanvas <> $g_hMainGui)
	Local $n = $aCtrls[0][1]                                                ; number of controls inside canvas
	Local $iX, $iY, $iW, $iH, $iF

	Local $aPos, $hWnd

	; resize the canvas and its elements
	__WinLockRepaint($hCanvas)                                              ; prevent windows from repainting or processing changes until we are done with all changes
	If $bCanvas Then
		$aPos = __API_ControlGetPos($hCanvas)                               ; retain the old position of the canvas
		$iX = $aPos[0]
		$iY = $aPos[1]
		$iW = Int($aCtrls[0][3] * $fNewScale)                               ; calculate the new size of the canvas
		$iH = Int($aCtrls[0][4] * $fNewScale)
		$g_iTabW = $iW                                                      ; set the currently selected canvas width for setting scrollbars later
		$g_iTabH = $iH                                                      ; set the currently selected canvas height for setting scrollbars later
		$oCanvas.Item('iW') = $iW                                           ; save width in the oCanvas structure
		$oCanvas.Item('iH') = $iH                                           ; save height in the oCanvas structure
		__API_ControlSetPos($hCanvas, $iX, $iY, $iW, $iH)                   ; resize the canvas
	EndIf

	For $i = 1 To $n                                                        ; resize every control inside the canvas
		$hWnd = HWnd($aCtrls[$i][0])
		$iX = Int($aCtrls[$i][1] * $fNewScale)
		$iY = Int($aCtrls[$i][2] * $fNewScale)
		$iW = Int($aCtrls[$i][3] * $fNewScale)
		$iH = Int($aCtrls[$i][4] * $fNewScale)
		__API_ControlSetPos(HWnd($hWnd), $iX, $iY, $iW, $iH)                ; resize the control
		$iF = $aCtrls[$i][5]
		If IsBinary($iF) And __IsHwndPicture($hWnd) Then
			__GUICtrlSetPicture($hWnd, $iF, True)                           ; scale picture from orig source
		Else
			$iF = Int($iF * $fNewScale)
			__API_ControlSetFontSize(HWnd($hWnd), $iF)                      ; scale the font
		EndIf
	Next

	__WinUnlockRepaint($hCanvas)                                            ; release canvas paint lock and refresh the display
	$oCanvas.Item('fzScale') = $fNewScale                                   ; save zoom scale for future reference

	If $UX Then __WinTitleNote(Int(100 * $fNewScale) & "%")                 ; show user the new zoom/scale factor
	Return $fNewScale
	;Return 1
EndFunc   ;==>__Canvas_SetZoom



Func __Canvas_GetZoom($oCanvas)
	If Not __IsDictionary($oCanvas) Then Return 1.0
	Return $oCanvas.Item('fzScale')
EndFunc   ;==>__Canvas_GetZoom



Func __Canvas_ZoomFind($oCanvas, $hWnd)                                     ; return the aZoomControls array index number of control $hWnd.  return -1 if not found
	If Not __IsDictionary($oCanvas) Then Return -1
	If Not $oCanvas.Exists('aCtrls') Then Return -1
	Local $aControls = $oCanvas.Item('aCtrls')
	If Not IsArray($aControls) Then Return -1
	If UBound($aControls, 0) <> 2 Then Return -1
	If UBound($aControls, 2) < 6 Then Return -1
	Local $i = 0, $n = UBound($aControls, 1) - 1
	For $i = 0 To $n
		If $aControls[$i][0] = $hWnd Then Return $i
	Next
	Return -1
EndFunc   ;==>__Canvas_ZoomFind



Func __API_ControlSetPos($hWnd, $iX, $iY, $iW, $iH)
	_WinAPI_SetWindowPos(HWnd($hWnd), 0, $iX, $iY, $iW, $iH, _
			BitOR($SWP_NOZORDER, $SWP_NOACTIVATE, $SWP_NOREDRAW))
EndFunc   ;==>__API_ControlSetPos



Func __API_ControlSetFontSize($hControl, $iNewPointSize)
	Local $hFont = _SendMessage($hControl, $WM_GETFONT, 0, 0)                               ; 1. READ: Get the current HFONT from the control
	If $hFont = 0 Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
	Local $tLogFont = DllStructCreate($tagLOGFONT)                                          ; Extract the current font settings into a LOGFONT structure
	_WinAPI_GetObject($hFont, DllStructGetSize($tLogFont), DllStructGetPtr($tLogFont))
	If @error Then Return SetError(1, 0, False)
	Local $hDC = _WinAPI_GetDC($hControl)                                                   ; 2. MODIFY: Calculate the new logical height based on Screen DPI
	Local $iLogPixelsY = _WinAPI_GetDeviceCaps($hDC, $LOGPIXELSY)
	_WinAPI_ReleaseDC($hControl, $hDC)
	Local $iNewLogicalHeight = -Round(($iNewPointSize * $iLogPixelsY) / 72)                 ; Formula: Logical Height = -(Points * DPI) / 72
	DllStructSetData($tLogFont, "Height", $iNewLogicalHeight)                               ; Update just the Height field in our structure template
	Local $hNewFont = _WinAPI_CreateFontIndirect($tLogFont)                                 ; 3. CREATE: Generate a brand new font using the updated structure
	If $hNewFont = 0 Then Return SetError(2, 0, False)
	_SendMessage($hControl, $WM_SETFONT, $hNewFont, False)                                  ; 4. WRITE: Send the new HFONT to the control and force it to redraw  ; wParam = Font Handle, lParam = True (Forcibly repaint the control)
	Return True
EndFunc   ;==>__API_ControlSetFontSize




; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; block autoit from responding to tab selection notifications

Func __Canvas_BlockTabNativeToggle_Handler($hWnd, $iMsg, $wParam, $lParam)
	; 1. Instantiate the standard Win32 NMHDR structure from the incoming memory pointer
	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	Local $hFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))

	; Only intercept if the notification message originated from your master Tab Control
	If $hFrom = $g_hTab Then
		Local $iCode = DllStructGetData($tNMHDR, "Code")
		Local Const $TCN_SELCHANGING = -552
		Local Const $TCN_SELCHANGE = -551

		Switch $iCode
			Case $TCN_SELCHANGING
				; Returning True (1) here tells Windows to completely freeze the transition.
				; This stops AutoIt from ever knowing the selection is about to change,
				; thereby completely disabling its native hide loop.
				Return 1

			Case $TCN_SELCHANGE
				; Returning 0 here blocks the subsequent selection response handler
				; to ensure no residual AutoIt layout logic triggers.
				Return 0
		EndSwitch
	EndIf

	; Allow all other system notification messages to process normally via the native pipeline
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__Canvas_BlockTabNativeToggle_Handler



; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; quell background erase for pictures in the gui



Func __Canvas_GuiPicRegister($hWnd)     ; register your picture handle to block WM_ERASEBKGND events
	If Not __IsDictionary($g_oGuiPics) Then $g_oGuiPics = ObjCreate("Scripting.Dictionary")
	$g_oGuiPics.Item(String($hWnd)) = 1
EndFunc   ;==>__Canvas_GuiPicRegister

Func __Canvas_GuiPicUnregister($hWnd)   ; unregister your picture handle
	$g_oGuiPics.Remove($hWnd)
EndFunc   ;==>__Canvas_GuiPicUnregister


Func __Canvas_WM_ERASEBKGND_Handler($hWnd, $iMsg, $wParam, $lParam)
	If $g_oGuiPics.Exists(String($hWnd)) Then Return 1              ; Return 1 to tell Windows the erase is handled (prevents the flash)
	Return $GUI_RUNDEFMSG                                           ; Let other controls erase normally
EndFunc   ;==>__Canvas_WM_ERASEBKGND_Handler









; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; _WinSnapToDesktop
;    Take window position data and readjust it to fit the desktop and/or viewing area of the monitor that it is on
;




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
	If $aAdjusted[0] < $iVirtualLeft Then                                               ; if to far left then
		$aAdjusted[0] = $iVirtualLeft                                                   ;   move to left side of desktop area
	EndIf                                                                               ; end if
	If $aAdjusted[1] < $iVirtualTop Then                                                ; if to far up/north then
		$aAdjusted[1] = $iVirtualTop                                                    ;   move to top edge of desktop area
	EndIf                                                                               ; end if

	; Determine which monitor the upper left corner of the window is on
	;Local $tPoint = DllStructCreate("long X;long Y;")
	;DllStructSetData($tPoint, "X", $aAdjusted[0])
	;DllStructSetData($tPoint, "Y", $aAdjusted[1])
	Local $tPoint = _WinAPI_CreatePoint($aAdjusted[0], $aAdjusted[1])                   ; create point structure
	Local $hMonitor = _WinAPI_MonitorFromPoint($tPoint, $MONITOR_DEFAULTTONEAREST)      ; find which monitor or default to primary
	Local $aMonInfo = _CustomGetMonitorInfo($hMonitor)                                  ; get monitor desktop area dimensions
	If Not @error Then
		$iVirtualLeft = $aMonInfo[1] + $leftMargin                                      ; recalculate desktop area bounds
		$iVirtualTop = $aMonInfo[2] + $topMargin
		$iVirtualRight = $aMonInfo[3] - $rightMargin
		$iVirtualBottom = $aMonInfo[4] - $bottomMargin
		$iVirtualWidth = $aMonInfo[3] - $aMonInfo[1]
		$iVirtualHeight = $aMonInfo[4] - $aMonInfo[2]
	EndIf


	; Fix Horizontal Bounds (Left / Right edge of window)
	If ($aAdjusted[0] + $aAdjusted[2]) > $iVirtualRight Then                            ; if to far right then
		$aAdjusted[0] = $iVirtualRight - $iWidth                                        ;   move right edge of window of right side of desktop area
	EndIf                                                                               ; end if   and continue to check if it is now or has been too far left
	If $aAdjusted[0] < $iVirtualLeft Then                                               ; if to far left then
		$aAdjusted[0] = $iVirtualLeft                                                   ;   move to left side of desktop area
		If ($aAdjusted[2] > $iVirtualWidth) Then                                        ;   if the window is too wide then
			$aAdjusted[2] = $iVirtualWidth                                              ;     set window width to size of desktop area
		EndIf                                                                           ;   end if
	EndIf                                                                               ; end if

	; Fix Vertical Bounds (Top / Bottom edge of window)
	If ($aAdjusted[1] + $aAdjusted[3]) > $iVirtualBottom Then                           ; if to far down then
		$aAdjusted[1] = $iVirtualBottom - $iHeight                                      ;	snap to just fit at the bottom of the screen
	EndIf                                                                               ; end if   and continue to check if it is now or has been too far up
	If $aAdjusted[1] < $iVirtualTop Then                                                ; if to far up then
		$aAdjusted[1] = $iVirtualTop                                                    ;   snap to top of desktop area
		If $aAdjusted[3] > $iVirtualHeight Then                                         ;   if to tall to fit then
			$aAdjusted[3] = $iVirtualHeight                                             ;     set height to match desktop area
		EndIf                                                                           ;   end if
	EndIf                                                                               ; end if


	Return $aAdjusted                                                                   ; return adjusted position and size
EndFunc   ;==>_WinSnapToDesktop



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






