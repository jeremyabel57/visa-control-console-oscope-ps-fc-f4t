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



Global $g_hMainGui




; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; accelerator/hot keys
;

Global $g_aAccelKeys[0][2]                          ; [ key, guicontrolid ], keypress activates control

Func __AccelKeyAdd($sKey, $cCtrl)
	Local $i = 0, $n = UBound($g_aAccelKeys, 1) - 1 ; search current list
	If $n >= 0 Then
		For $i = 0 To $n
			If $g_aAccelKeys[$i][0] = $sKey Then ExitLoop
		Next
	EndIf
	If $i > $n Then
		$n += 1
		ReDim $g_aAccelKeys[$n + 1][2]
		$g_aAccelKeys[$n][0] = $sKey
		$g_aAccelKeys[$n][1] = $cCtrl
	EndIf
	GUISetAccelerators($g_aAccelKeys, $g_hMainGui)  ; assert new list
EndFunc   ;==>__AccelKeyAdd

Func __AccelKeyRemove($sKey)
	Local $i, $n = UBound($g_aAccelKeys, 1) - 1
	For $i = 0 To $n
		If $g_aAccelKeys[$i][0] = $sKey Then ExitLoop
	Next
	If $i > $n Then Return False
	$g_aAccelKeys[$i][0] = $g_aAccelKeys[$n][0]     ; move last item in list into current items position to overwrite/erase current item
	$g_aAccelKeys[$i][1] = $g_aAccelKeys[$n][1]
	ReDim $g_aAccelKeys[$n][2]                      ; reduce the list size by one item
	GUISetAccelerators($g_aAccelKeys, $g_hMainGui)  ; assert new list
EndFunc   ;==>__AccelKeyRemove





; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; register functions to be executed inside the main loop
;


Global $g_oLoopExec = ObjCreate("Scripting.Dictionary")


Func LoopRegister($sFunction)               ; register your function to run in main loop
	$g_oLoopExec.Item(String($sFunction)) = 1
EndFunc   ;==>LoopRegister

Func LoopUnregister($sFunction)             ; unregister your function from the main loop
	$g_oLoopExec.Remove(String($sFunction))
EndFunc   ;==>LoopUnregister


Func LoopExec()                             ; execute this in the main loop to run registered functions
	Local $sKey
	For $sKey In $g_oLoopExec
		Call($sKey)
	Next
EndFunc   ;==>LoopExec





; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; mailbox register - register functions to be executed if a variable gets populated, then reset the variable back to an empty string
;


Global $g_oMailboxRegister = ObjCreate("Scripting.Dictionary")


Func MailboxVarRegister($sVarName, $sFunction)              ; register your function and variable
	$g_oMailboxRegister.Item(String($sVarName)) = $sFunction
EndFunc   ;==>MailboxVarRegister

Func MailboxVarUnregister($sVarName)                        ; unregister your function
	$g_oMailboxRegister.Remove(String($sVarName))
EndFunc   ;==>MailboxVarUnregister


Func MailboxVarLoop()                                       ; execute this in the main loop
	Local $sKey, $vVal
	For $sKey In $g_oMailboxRegister
		$vVal = EvalEx($sKey, Null)
		If $vVal <> '' Then
			Call($g_oMailboxRegister.Item($sKey), $vVal, $sKey)     ; call registered function with parameters:  value of the mailbox variable, name of the mailbox variable
			AssignEx($sKey, '', Null)
		EndIf
	Next
EndFunc   ;==>MailboxVarLoop




; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; _GUIRegisterMsgs - a wraper for GUIRegisterMsgs
;   this will allow registering multiple handler functions to a given gui message event
;
; _GUIRegisterMsgs($iMsg,$sFunction)			to register your function
; _GUIRegisterMsgs_remove($iMsg,$sFunction)		to unregister your function
;



Global $_GUIRegisterMsg_Handlers = ObjCreate("Scripting.Dictionary")



;			_GUIRegisterMsg
; task:		this GUIRegisterMsg wrapper allows registering multiple functions to any given gui window event
; in:		$iMessage = event ID
;			$sFunction = autoit function to call
; action:	adds $sFunction to the array of handlers for $iMessage event
Func _GUIRegisterMsg($iMessage, $sFunction)
	Local $oHandle
	If Not $_GUIRegisterMsg_Handlers.Exists($iMessage) Then
		$oHandle = ObjCreate("Scripting.Dictionary")
		$_GUIRegisterMsg_Handlers.Item(String($iMessage)) = $oHandle
		GUIRegisterMsg($iMessage, "_GUIRegisterMsg_Handle")
	Else
		$oHandle = $_GUIRegisterMsg_Handlers.Item(String($iMessage))
	EndIf
	$oHandle.Item(String($sFunction)) = 1
EndFunc   ;==>_GUIRegisterMsg

; task:		remove $sFunction from the list of registered event handlers
Func _GUIUnregisterMsg($iMessage, $sFunction)
	If Not $_GUIRegisterMsg_Handlers.Exists($iMessage) Then Return
	Local $oHandle = $_GUIRegisterMsg_Handlers.Item(String($iMessage))
	If Not $oHandle.Exists($sFunction) Then Return
	$oHandle.Remove($sFunction)
	If $oHandle.Count = 0 Then
		$_GUIRegisterMsg_Handlers.Remove($iMessage)
		GUIRegisterMsg($iMessage, "")
	EndIf
EndFunc   ;==>_GUIUnregisterMsg


; universal message handler that executes every custom function registered to a given gui message
Func _GUIRegisterMsg_Handle($hWnd, $iMsg, $wParam, $lParam)
	Local $oHandle = $_GUIRegisterMsg_Handlers.Item(String($iMsg))
	If Not IsObj($oHandle) Then Return $GUI_RUNDEFMSG
	If ObjName($oHandle) <> "Dictionary" Then Return $GUI_RUNDEFMSG
	Local $sKey, $vRet, $totalRet = $GUI_RUNDEFMSG
	For $sKey In $oHandle
		$vRet = Call($sKey, $hWnd, $iMsg, $wParam, $lParam)
		If $vRet <> $GUI_RUNDEFMSG Then $totalRet = $vRet
	Next
	Return $totalRet
EndFunc   ;==>_GUIRegisterMsg_Handle



; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; misc functions



Func __IsHwndPicture($hWnd)
	If $hWnd = 0 Then Return False
	If _WinAPI_GetClassName($hWnd) <> "Static" Then Return False            ; 1. Verify it belongs to the Static class landscape
	Local $iStyle = _WinAPI_GetWindowLong($hWnd, $GWL_STYLE)                ; 2. Fetch the window's style flags
	If BitAND($iStyle, $SS_BITMAP) = $SS_BITMAP Then Return True            ; 3. Check if the control has the SS_BITMAP (0x000E) style automatically assigned by GUICtrlCreatePic
	Return False                                                            ; It's likely a standard text label
EndFunc   ;==>__IsHwndPicture



Func __Canvas_IsWebView($oCanvas)
	If Not __IsDictionary($oCanvas) Then Return False
	Return $oCanvas.Exists('aWebView')
EndFunc   ;==>__Canvas_IsWebView



Func __WinLockRepaint($hWnd = $g_hMainGui)
	GUISetState(@SW_LOCK, $hWnd)                ; prevent windows from repainting or processing changes until we are done with all changes
EndFunc   ;==>__WinLockRepaint



Func __WinUnlockRepaint($hWnd = $g_hMainGui)
	GUISetState(@SW_UNLOCK, $hWnd)              ; unlock the repainting so windows can update the screen
	_WinAPI_RedrawWindow($g_hMainGui, 0, 0, _   ; request windows to redraw/repaint
			BitOR($RDW_UPDATENOW, $RDW_ALLCHILDREN))
	;BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))
EndFunc   ;==>__WinUnlockRepaint






; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; briefly show a status message in the window title (like zoom percentage)

Global $g_iTitleNoteTimer = 0                                                                   ; Tracks the high-resolution timestamp marker
Global $g_sTitleNoteTitle = ''
Global $g_iTitleNoteTimeout = 1200


Func __WinTitleNoteTrack()
	If $g_iTitleNoteTimer = 0 Then Return
	If TimerDiff($g_iTitleNoteTimer) < $g_iTitleNoteTimeout Then Return
	_WinAPI_SetWindowText($g_hMainGui, $g_sTitleNoteTitle)
	;_WinAPI_RedrawWindow($g_hMainGui, 0, 0, BitOR($RDW_FRAME, $RDW_INVALIDATE, $RDW_UPDATENOW))
	_WinAPI_RedrawWindow($g_hMainGui, 0, 0, BitOR($RDW_FRAME, $RDW_UPDATENOW))                  ; redraw/repaint only the frame and title bar
	$g_sTitleNoteTitle = ''
	$g_iTitleNoteTimer = 0
EndFunc   ;==>__WinTitleNoteTrack


Func __WinTitleNote($sNote, $iTimeoutMS = 1200)
	If $g_sTitleNoteTitle = '' Then $g_sTitleNoteTitle = _WinAPI_GetWindowText($g_hMainGui)
	$g_iTitleNoteTimer = TimerInit()
	$g_iTitleNoteTimeout = $iTimeoutMS
	If $sNote <> '' Then $sNote = "   " & $sNote
	_WinAPI_SetWindowText($g_hMainGui, $g_sTitleNoteTitle & $sNote)
	_WinAPI_RedrawWindow($g_hMainGui, 0, 0, BitOR($RDW_FRAME, $RDW_UPDATENOW))                  ; redraw/repaint only the frame and title bar
	;_WinAPI_RedrawWindow($g_hMainGui, 0, 0, BitOR($RDW_FRAME, $RDW_INVALIDATE, $RDW_UPDATENOW))
EndFunc   ;==>__WinTitleNote







; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------------------------------------------
; GUI helper functions
;
;




Global $g_picBufs = ObjCreate("Scripting.Dictionary")



; ===================================================================================================
; Function:    __GUICtrlSetPicture
; Description: Takes raw TCP binary data, detects the control's size, optionally resizes the image to fit, and displays it
; Parameters:  $hPic - windows handle of the picture gui control
;              $bImage - The raw binary buffer downloaded from your TCP socket
; 			   $bFit = true to resize the image to fit
; ===================================================================================================
Func __GUICtrlSetPicture($hPic, $bImage, $bFit = True)
	;__WinLockRepaint($hPic)
	_GDIPlus_Startup()                                                                      ; Ensure GDI+ is initialized
	Local $hBitmap = _GDIPlus_BitmapCreateFromMemory($bImage)                               ; 1. Load the binary data into a GDI+ Bitmap object
	If @error Then Return False
	If $bFit Then
		;Local $hPic = GUICtrlGetHandle($cPic)
		Local $aPos = __API_ControlGetPos($hPic)
		If Not @error And IsArray($aPos) Then
			If UBound($aPos) >= 4 Then
				Local $iTargetWidth = $aPos[2] ; Control Width
				Local $iTargetHeight = $aPos[3] ; Control Height
				If $iTargetWidth > 0 And $iTargetHeight Then
					Local $hOrig = $hBitmap
					$hBitmap = _GDIPlus_ImageResize($hOrig, $iTargetWidth, $iTargetHeight)
					_GDIPlus_BitmapDispose($hOrig) ; Delete original memory map object
				EndIf
			EndIf
		EndIf
	EndIf
	Local $hHBitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)                      ; 2. Convert the GDI+ Bitmap into a usable Windows GDI HBITMAP
	_GDIPlus_BitmapDispose($hBitmap)                                                        ; 4. CLEAN UP MEMORY (Crucial step to prevent your app from crashing or hogging RAM)

	_SendMessage($hPic, $WM_SETREDRAW, False, 0)                                            ; 1. Turn off redrawing for this control temporarily to prevent the flash
	Local $hPrevBmp = _SendMessage($hPic, $STM_SETIMAGE, $IMAGE_BITMAP, $hHBitmap)          ; This replaces the current image and returns the previous HBITMAP handle  (0x0172 = STM_SETIMAGE)
	If $hPrevBmp Then _WinAPI_DeleteObject($hPrevBmp)                                       ; Delete the image that was just overwritten
	_SendMessage($hPic, $WM_SETREDRAW, True, 0)                                             ; 3. Turn redrawing back on
	_WinAPI_RedrawWindow($hPic, 0, 0, BitOR($RDW_UPDATENOW, $RDW_UPDATENOW))                ; 0x0100 = $RDW_UPDATENOW (Forces immediate redraw), 0x0002 = $RDW_INVALIDATE (Invalidates the region)

	$hPrevBmp = Hex($hPic)
	If $g_picBufs.Exists($hPrevBmp) Then _WinAPI_DeleteObject($g_picBufs.Item($hPrevBmp))   ; Delete our tracked backup object
	$g_picBufs.Item(Hex($hPic)) = $hHBitmap                                                 ; Track the current bitmap handle so we can safely delete it on the next incoming picture update
	_GDIPlus_Shutdown()                                                                     ; shutdown GDI+ until we need it again later
	;__WinUnlockRepaint($hPic)
	Return True
EndFunc   ;==>__GUICtrlSetPicture



OnAutoItExitRegister("__GUICtrlSetPicture_Exit")        ; register exit function

Func __GUICtrlSetPicture_Exit()
	Local $sKey
	For $sKey In $g_picBufs                                                                 ; dispose of any pic buffers
		_WinAPI_DeleteObject($g_picBufs.Item($sKey))
	Next
EndFunc   ;==>__GUICtrlSetPicture_Exit



Func __API_ControlGetFontSize($hControl)
	Local $hFont = _SendMessage($hControl, $WM_GETFONT, 0, 0)                               ; 1. Request the HFONT handle from the control
	If $hFont = 0 Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)                   ;    If the control returns 0, it means it is using the default system GUI font
	Local $tLogFont = DllStructCreate($tagLOGFONT)                                          ; 2. Create the blank structure to store font data
	_WinAPI_GetObject($hFont, DllStructGetSize($tLogFont), DllStructGetPtr($tLogFont))      ; 3. PASS ALL 3 REQUIRED ARGUMENTS: (Handle, Size of Buffer, Pointer to Buffer)
	If @error Then Return SetError(1, 0, 9)                                                 ;    if error then return default font size 9
	Local $hDC = _WinAPI_GetDC($hControl)                                                   ; 4. Get the Screen Device Context (DC) to calculate the current DPI / Scale
	Local $iLogPixelsY = _WinAPI_GetDeviceCaps($hDC, $LOGPIXELSY)                           ; Usually 96 on 100% scaling
	_WinAPI_ReleaseDC($hControl, $hDC)
	Return Round((Abs(DllStructGetData($tLogFont, "Height")) * 72) / $iLogPixelsY)          ; Formula conversion: Points = (Logical Height * 72) / DPI  (Note: Height is often negative in Win32 to signify character em-height);
EndFunc   ;==>__API_ControlGetFontSize



Func __API_ControlGetPos($hControl, $hParent = 0)
	If $hParent = 0 Then $hParent = _WinAPI_GetParent($hControl)
	Local $a[4] = [0, 0, 0, 0]
	Local $tRect = _WinAPI_GetWindowRect($hControl)                         ; 1. Get the control's absolute screen coordinates
	If @error Then Return SetError(1, 0, $a)
	Local $iLeft = DllStructGetData($tRect, "Left")                         ; Extract the structure points
	Local $iTop = DllStructGetData($tRect, "Top")
	Local $iRight = DllStructGetData($tRect, "Right")
	Local $iBottom = DllStructGetData($tRect, "Bottom")
	Local $tPoint = _WinAPI_CreatePoint($iLeft, $iTop)                      ; 2. Convert the Top-Left screen point to Parent-relative coordinates
	_WinAPI_ScreenToClient($hParent, $tPoint)
	Local $iX = DllStructGetData($tPoint, "X")
	Local $iY = DllStructGetData($tPoint, "Y")
	Local $aPos[4] = [$iX, $iY, $iRight - $iLeft, $iBottom - $iTop]         ; Return array matching ControlGetPos format: [X, Y, Width, Height]
	Return $aPos
EndFunc   ;==>__API_ControlGetPos





#cs
; This function takes your raw TCP binary bytes and scales them to specific Target Dimensions
Func __Pic_Resize($bImageBinary, $iTargetWidth, $iTargetHeight)
	_GDIPlus_Startup()
	Local $hBitmapFromMem = _GDIPlus_BitmapCreateFromMemory($bImageBinary)                          ; 1. Load the raw binary bytes into a GDI+ Bitmap
	If @error Then Return SetError(@error, @extended, False)
	Local $hResizedImage = _GDIPlus_ImageResize($hBitmapFromMem, $iTargetWidth, $iTargetHeight)     ; 2. Resize the image down/up to your exact target dimensions
	_GDIPlus_BitmapDispose($hBitmapFromMem)                                                         ; 5. Memory Cleanup (Crucial to avoid RAM crashes)
	;_GDIPlus_BitmapDispose($hResizedImage)  														; Delete the resized GDI+ map
	_GDIPlus_Shutdown()
	Return $hResizedImage
EndFunc   ;==>__Pic_Resize
#ce


#cs
; ===================================================================================================
; Function:    __GDIPlus_BitmapToBinary
; Description: Converts a GDI+ image handle back into a raw binary buffer (opposite of CreateFromMemory)
; Parameters:  $hImage      - The GDI+ image or bitmap handle
;              $sFormat     - The format string: "JPG", "PNG", "BMP", or "GIF" (Default: "JPG")
;              $iQuality    - Compression quality for JPG (0-100). Ignored for other formats.
; ===================================================================================================
Func __GDIPlus_BitmapToBinary($hImage, $sFormat = "JPG", $iQuality = 85)
	_GDIPlus_Startup()
	Local $sCLSID = _GDIPlus_EncodersGetCLSID($sFormat)                         ; 1. Get the Encoder Class ID (CLSID) for the requested target format
	If @error Then Return SetError(1, 0, Binary(""))
	Local $bBinaryResult = Binary("")
	Local $tParams = 0                                                          ; 2. Set up the image quality parameters if saving as a JPG
	If StringUpper($sFormat) = "JPG" Then
		Local $tData = DllStructCreate("int Quality")
		DllStructSetData($tData, "Quality", $iQuality)
		$tParams = _GDIPlus_ParamInit(1)
		_GDIPlus_ParamAdd($tParams, $GDIP_EPGQUALITY, 1, $GDIP_EPTLONG, DllStructGetPtr($tData))
	EndIf
	Local $hStream = _WinAPI_CreateStreamOnHGlobal()                            ; 3. Save the image data into a virtual IStream object (In-Memory Stream)
	If _GDIPlus_ImageSaveToStream($hImage, $hStream, $sCLSID, $tParams) Then _
			$bBinaryResult = _WinAPI_GetMemoryFromStream($hStream)              ; 4. Extract the raw bytes directly from the memory stream
	_WinAPI_ReleaseStream($hStream)                                             ; 5. Clean up stream resources
	_GDIPlus_Shutdown()
	Return $bBinaryResult                                                       ; Returns a variable with the "0x..." binary type
EndFunc   ;==>_GDIPlus_BitmapToBinary
#ce




Func __IsComboBox($hControl)
	If Not IsHWnd($hControl) Then Return False              ; 1. Ensure the handle is a valid window/control handle
	Local $sClassName = _WinAPI_GetClassName($hControl)     ; 2. Retrieve the underlying window class name
	Return (StringInStr($sClassName, "ComboBox") > 0)       ; 3. Check if it's a standard Win32 ComboBox or a framed variant (e.g., .NET / WinForms)
EndFunc   ;==>__IsComboBox




; ==============================================================================
; CUSTOM WINAPI PROPERTY FUNCTIONS
; ==============================================================================

Func _WinAPI_SetProp($hWnd, $sProp, $pData)
	Local $aResult = DllCall("user32.dll", "bool", "SetPropW", "hwnd", $hWnd, "wstr", $sProp, "ptr", $pData)
	Return $aResult[0]
EndFunc   ;==>_WinAPI_SetProp

Func _WinAPI_GetProp($hWnd, $sProp)
	Local $aResult = DllCall("user32.dll", "ptr", "GetPropW", "hwnd", $hWnd, "wstr", $sProp)
	Return $aResult[0]
EndFunc   ;==>_WinAPI_GetProp

Func _WinAPI_RemoveProp($hWnd, $sProp)
	Local $aResult = DllCall("user32.dll", "ptr", "RemovePropW", "hwnd", $hWnd, "wstr", $sProp)
	Return $aResult[0]
EndFunc   ;==>_WinAPI_RemoveProp







; -------------------------------------
; -------------------------------------
; -------------------------------------
; __GuiButtonSetOnState


;			__GuiToggleButtonSetOnState
; task:		toggle color and text of button based on on/off state
;			only update if state changes, and defer update if state is waffling
; in:		$cBtn = button control handle
;			$bNew = new state true/false
;			$bImmed = true to update state now and not defer to filter out waffling
;			$iBCon = background color when button is in 'on' state
;			$iFCon = foreground color when button is in 'on' state
;			$iBCoff = background color when button is in 'off' state
;			$iFCoff = foregrond color when button is in 'off' state
;			$bText = true to set button text to 'on' or 'off'.  False to leave text alone
; out:		button updated if needed.
; sop:		A property is added to the button to save the current (bNow) and previous (bPrev) states, this gives us 3 states (bPrev, bNow, and bNew).
;			if bSelf is true then (the button gui is updated if any of the states differ) - do not do deferred updates
;			  if bPrev=bNow and bNow=bNew then skip the gui update
;			if bSelf is false then
;			  if bPrev = bNew and bNow <> bPrev then the gui update is deferred until the next call
;			  else if bNew <> bNow then the gui is updated
;			The state information is rolled for the next call - bNow goes to bPrev, bNew goes to bNow
;			This filters out the case where the user clicks the button to toggle a state on the visa device and it causes the gui button to waffle/flicker.
;			  For quick response, the gui button state is changed immediately with a call here and bSelf=True.
;			  A visa command to change the device state is put into the queue, but there is already a read request in the queue before the switch command.
;			  The read request returns the previous button state and is sent to this function with bSelf=False.  This enables the waffling filter.
;			  Next, the visa device receives the switch state command, followed by an additional read state request.
;			  The 2nd read state request sends the data here and this time it matches the current state of the button, so no flickering updates occur.
;			  Later some other event happens and there are additional calls to this function.  The flicker filter only keeps the prior state so new data
;			  updates the gui button state with no issues.
; usage:	When a button is pushed by the user, call this function with bSelf = True
;			if the button status is read from the visa device, call this function with bSelf = False
;
Func __GuiToggleButtonSetOnState($cBtn, $bNew, $bImmed = True, $iBCon = $COLOR_YELLOW, $iFCon = $COLOR_BLACK, $iBCoff = $COLOR_GRAY2, $iFCoff = $COLOR_BLACK, $bText = True)
	Local $hBtn = GUICtrlGetHandle($cBtn)
	Local $iUdat = _WinAPI_GetProp($hBtn, "state")                                                              ; pull history from user property field in control
	Local $bPrev = BitAND($iUdat, 1)                                                                            ; previous state of button
	Local $bNow = BitShift(BitAND($iUdat, 2), 1)                                                                ; current state of button
	$bNew = Int(Int($bNew) <> 0)                                                                                ; new state of button
	_WinAPI_SetProp($hBtn, "state", _
			BitOR(BitShift($bNew, -1), $bNow, BitAND($iUdat, 0xFFFFFFFC)))                                      ; rotate now and prev bits and store back into the data field
	$bNew = ($bNew <> 0)

	;If Not ((Not $bNew And $bPrev) Or ($bNew And Not $bPrev) Or ($bImmed And Not $bNow And $bPrev) Or ($bImmed And Not $bNew And $bNow)) Then Return
	If $bImmed Then
		If $bNew = $bNow And $bNow = $bPrev Then Return
	Else
		If $bNew = $bPrev Then Return
	EndIf

	GUICtrlSetBkColor($cBtn, $bNew ? $iBCon : $iBCoff)
	GUICtrlSetColor($cBtn, $bNew ? $iFCon : $iFCoff)
	If $bText Then GUICtrlSetData($cBtn, ($bNew ? "On" : "Off"))
EndFunc   ;==>__GuiToggleButtonSetOnState

Func __GuiToggleButtonGetOnState($cBtn)
	Return (BitAND(_WinAPI_GetProp(GUICtrlGetHandle($cBtn), "state"), 2) = 2)
EndFunc   ;==>__GuiToggleButtonGetOnState



; --------------------------------------------------------------
; for the debug tab
; gui functions to operate the edit boxes like stacks and queues



Func __GUICtrlEdit_Append($cEdit, $sText)
	_GUICtrlEdit_AppendText($cEdit, $sText)         ; append new text to edit box
	_GUICtrlEdit_SetSel($cEdit, -1, -1)             ; move cursor position to end of text in edit box
	_GUICtrlEdit_Scroll($cEdit, $SB_SCROLLCARET)    ; move the view to follow the cursor position
EndFunc   ;==>__GUICtrlEdit_Append


Func __GUICtrlEdit_QueuePush($cEdit, $sText)
	_GUICtrlEdit_AppendText($cEdit, $sText & @CRLF) ; append new text to edit box
	_GUICtrlEdit_SetSel($cEdit, 0, 0)               ; move cursor position to end of text in edit box
	_GUICtrlEdit_Scroll($cEdit, $SB_SCROLLCARET)    ; move the view to follow the cursor position
EndFunc   ;==>__GUICtrlEdit_QueuePush

Func __GUICtrlEdit_QueuePop($cEdit)
	__GUICtrlEdit_RemoveLine($cEdit, 0)
EndFunc   ;==>__GUICtrlEdit_QueuePop

Func __GUICtrlEdit_StackPush($cEdit, $sText)
	__GUICtrlEdit_Append($cEdit, $sText & @CRLF)
EndFunc   ;==>__GUICtrlEdit_StackPush

Func __GUICtrlEdit_StackPop($cEdit)
	__GUICtrlEdit_RemoveLine($cEdit, -1)
EndFunc   ;==>__GUICtrlEdit_StackPop


Func __GUICtrlEdit_RemoveLine($cEdit, $iLineIndex)                                  ; remove line from edit box (if $iLineIndex < 0 then work from the last line = -1
	Local $hEdit = GUICtrlGetHandle($cEdit)
	If $iLineIndex < 0 Then $iLineIndex += _GUICtrlEdit_GetLineCount($cEdit)
	Local $iStartChar = _GUICtrlEdit_LineIndex($cEdit, $iLineIndex)                 ; 1. Find the character indices for the start and end of the target line
	Local $iLineLength = _GUICtrlEdit_LineLength($cEdit, $iStartChar)
	Local $iEndChar = $iStartChar + $iLineLength
	If $iLineIndex < (_GUICtrlEdit_GetLineCount($cEdit) - 1) Then $iEndChar += 2    ; If it's not the last line, include the trailing line break (@CRLF is 2 characters)
	_SendMessage($hEdit, $EM_SETSEL, $iStartChar, $iEndChar)                        ; 2. Select the line characters via API
	_SendMessage($hEdit, $EM_REPLACESEL, False, "")                                 ; 3. Overwrite the selected text with nothing (""), effectively deleting it
EndFunc   ;==>__GUICtrlEdit_RemoveLine



