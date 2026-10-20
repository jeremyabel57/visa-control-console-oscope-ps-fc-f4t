#include-once

#cs
usage:


		__tableEdit($aArray, $aHeader = "", $aHwidths = "", $title1 = "Edit Table", $title2 = "Table")

		__tableEditReturn()
			if the no status change then it returns 0
			if the user clicked cancel it returns 1
			if the user clicked commit it returns the new edited array
			after it returns 1 or the array, subsequent calls will return 0

#ce


#include <GuiConstantsEx.au3>
#include <WindowsConstants.au3>
#include "winmgmt.au3"

#include "GUIListViewEx.au3"


; Global tracking variables required for OnEvent scope
Global $__tableEdit_iStatus = 0
Global $__tableEdit_hGUI = 0
Global $__tableEdit_hView = 0
Global $__tableEdit_iBtnSize = 20
Global $__tableEdit_hParent = 0
Global $__tableEdit_aReturn


Func __tableEdit($aArray, $aHeader = "", $aHwidths = "", $title1 = "Edit Table", $title2 = "Table", $hParent = 0)

	Local $W_MAX = 1000
	Local $W_MIN = 200
	Local $H_MIN = 200

	Local $WS_SYSTEMMENU = 0x00080000
	Local $iEditMode = "22"
	Local $i, $j
	Local $iWidth = 400
	Local $iHeight = 300

	$__tableEdit_iStatus = 0                                                    ; Reset global flag status for this session run
	$__tableEdit_hParent = $hParent

	If IsArray($aHeader) Then                                                   ; validate $aHeader array
		If UBound($aHeader) < UBound($aArray, 2) Then $aHeader = 0
	EndIf
	If Not IsArray($aHeader) Then
		Local $aH[UBound($aArray, 2)]
		For $i = 0 To UBound($aArray, 2) - 1
			$aH[$i] = $i + 1
		Next
		$aHeader = $aH
	EndIf
	If IsArray($aHwidths) Then                                                  ; validate $aHwidths array
		If UBound($aHwidths) < UBound($aArray, 2) Then $aHwidths = 0
	EndIf
	If Not IsArray($aHwidths) Then
		Local $aH[UBound($aArray, 2)]
		For $i = 0 To UBound($aArray, 2) - 1
			$aH[$i] = 80
		Next
		$aHwidths = $aH
	EndIf

	$aH = 10                                                                    ; scale the window width to fit the array
	For $i = 0 To UBound($aArray, 2) - 1
		$aH += $aHwidths[$i]
	Next
	If $aH > $W_MAX Then $aH = $W_MAX
	If $aH < $W_MIN Then $aH = $W_MIN
	$iWidth = $aH

	$iHeight = 10 + $__tableEdit_iBtnSize + 25 + 20 * UBound($aArray, 1)
	If $iHeight < $H_MIN Then $iHeight = $H_MIN


	$__tableEdit_hGUI = GUICreate($title1, $iWidth, $iHeight, -1, -1, _
			BitOR($WS_CAPTION, $WS_SYSTEMMENU, $WS_SIZEBOX, $WS_MINIMIZEBOX, $WS_MAXIMIZEBOX), -1, $hParent)

	GUISetOnEvent($GUI_EVENT_CLOSE, "__tableEdit_OnClose", $__tableEdit_hGUI)                            ; Register the GUI window close event
	;GUISetOnEvent($GUI_EVENT_RESIZED, "__tableEdit_OnResize", $__tableEdit_hGUI)                        ; Register the GUI window dynamic resize event

	Local $cTitle = GUICtrlCreateLabel($title2, 5, 8, $iWidth - 10 - 3 * $__tableEdit_iBtnSize, $__tableEdit_iBtnSize - 3)
	GUICtrlSetResizing($cTitle, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKHEIGHT))

	Local $cInsertBtn = GUICtrlCreateButton("+", $iWidth - 5 - 3 * $__tableEdit_iBtnSize, 5, $__tableEdit_iBtnSize, $__tableEdit_iBtnSize)
	GUICtrlSetResizing($cInsertBtn, BitOR($GUI_DOCKSIZE, $GUI_DOCKTOP, $GUI_DOCKRIGHT))
	GUICtrlSetOnEvent($cInsertBtn, "__tableEdit_OnInsert") ; Bind function string

	Local $cDeleteBtn = GUICtrlCreateButton("-", $iWidth - 5 - 2 * $__tableEdit_iBtnSize, 5, $__tableEdit_iBtnSize, $__tableEdit_iBtnSize)
	GUICtrlSetResizing($cDeleteBtn, BitOR($GUI_DOCKSIZE, $GUI_DOCKTOP, $GUI_DOCKRIGHT))
	GUICtrlSetOnEvent($cDeleteBtn, "__tableEdit_OnDelete") ; Bind function string

	Local $cCommitBtn = GUICtrlCreateButton(ChrW(10004), $iWidth - 5 - 1 * $__tableEdit_iBtnSize, 5, $__tableEdit_iBtnSize, $__tableEdit_iBtnSize)
	GUICtrlSetResizing($cCommitBtn, BitOR($GUI_DOCKSIZE, $GUI_DOCKTOP, $GUI_DOCKRIGHT))
	GUICtrlSetOnEvent($cCommitBtn, "__tableEdit_OnCommit") ; Bind function string

	$__tableEdit_hView = _GUICtrlListView_Create($__tableEdit_hGUI, "", 5, 5 + $__tableEdit_iBtnSize, $iWidth - 10, $iHeight - 10 - $__tableEdit_iBtnSize, _
			BitOR($LVS_DEFAULT, $WS_BORDER, $WS_EX_CLIENTEDGE))
	GUICtrlSetResizing($__tableEdit_hView, BitOR($GUI_DOCKTOP, $GUI_DOCKRIGHT, $GUI_DOCKLEFT, $GUI_DOCKBOTTOM))
	_GUICtrlListView_SetExtendedListViewStyle($__tableEdit_hView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
	_GUICtrlListView_SetTextBkColor($__tableEdit_hView, 0xFFFFFF)


	For $i = 0 To UBound($aArray, 2) - 1                                        ; add column headers to list view
		_GUICtrlListView_AddColumn($__tableEdit_hView, $aHeader[$i], $aHwidths[$i])
	Next

	For $j = 0 To UBound($aArray, 1) - 1                                        ; populate list view from $aArray data
		_GUICtrlListView_AddItem($__tableEdit_hView, $aArray[$j][0])
		For $i = 1 To UBound($aArray, 2) - 1
			_GUICtrlListView_AddSubItem($__tableEdit_hView, $j, $aArray[$j][$i], $i)
		Next
	Next

	; Initiate LVEx - use read content as array - count parameter set - red insert mark - drag image - move edit by click + headers editable
	Local $iLV_Index, $aLV_List
	$iLV_Index = _GUIListViewEx_Init($__tableEdit_hView, $aLV_List, 1, 0xFF0000, True, 4 + 8)
	_GUIListViewEx_SetEditStatus($iLV_Index, "*")                               ; All columns editable - simple text selected on open
	GUISwitch($__tableEdit_hGUI)

	; GUIListViewEx: Register for sorting, dragging and editing
	_GUIRegisterMsg(0x004E, "_GUIListViewEx_WM_NOTIFY_Handler")     ; $WM_NOTIFY
	_GUIRegisterMsg(0x0200, "_GUIListViewEx_WM_MOUSEMOVE_Handler")  ; $WM_MOUSEMOVE
	_GUIRegisterMsg(0x0202, "_GUIListViewEx_WM_LBUTTONUP_Handler")  ; $WM_LBUTTONUP
	_GUIRegisterMsg(0x0112, "_GUIListViewEx_WM_SYSCOMMAND_Handler") ; $WM_SYSCOMMAND

	_GUIRegisterMsg($WM_SIZE, "__tableEdit_WM_SIZE")                ; $WM_SIZE
	_GUIRegisterMsg($WM_MOVE, "__tableEdit_WM_SIZE")                ; $WM_MOVE
	_GUIRegisterMsg($WM_WINDOWPOSCHANGED, "__tableEdit_WM_SIZE")    ; $WM_WINDOWPOSCHANGED

	GUISetState(@SW_SHOW)
	;_GUIListViewEx_EditItem($iLV_Index, 1, 1, $iEditMode)

	LoopRegister("__tableEdit_Loop")

	If $hParent Then GUISwitch($hParent)
EndFunc   ;==>__tableEdit

Func __tableEdit_Loop()
	_GUIListViewEx_EventMonitor("22")
EndFunc   ;==>__tableEdit_Loop


Func __tableEdit_Cleanup()
	LoopUnregister("__tableEdit_Loop")
	GUISetState(@SW_HIDE, $__tableEdit_hGUI)                                ; hide the gui window
	_GUIUnregisterMsg(0x004E, "_GUIListViewEx_WM_NOTIFY_Handler")      ; $WM_NOTIFY
	_GUIUnregisterMsg(0x0200, "_GUIListViewEx_WM_MOUSEMOVE_Handler")   ; $WM_MOUSEMOVE
	_GUIUnregisterMsg(0x0202, "_GUIListViewEx_WM_LBUTTONUP_Handler")   ; $WM_LBUTTONUP
	_GUIUnregisterMsg(0x0112, "_GUIListViewEx_WM_SYSCOMMAND_Handler")  ; $WM_SYSCOMMAND
	_GUIUnregisterMsg($WM_SIZE, "__tableEdit_WM_SIZE")                 ; $WM_SIZE
	_GUIUnregisterMsg($WM_MOVE, "__tableEdit_WM_SIZE")                 ; $WM_MOVE
	_GUIUnregisterMsg($WM_WINDOWPOSCHANGED, "__tableEdit_WM_SIZE")     ; $WM_WINDOWPOSCHANGED
	GUIDelete($__tableEdit_hGUI)
	If $__tableEdit_hParent Then WinActivate($__tableEdit_hParent)
EndFunc   ;==>__tableEdit_Cleanup


; --- OnEvent Bound Callback Service Functions ---

Func __tableEdit_OnClose()
	$__tableEdit_iStatus = 1
	$__tableEdit_aReturn = False
	__tableEdit_Cleanup()
EndFunc   ;==>__tableEdit_OnClose

Func __tableEdit_OnCommit()
	$__tableEdit_iStatus = 2
	$__tableEdit_aReturn = _GUIListViewEx_ReadToArray($__tableEdit_hView, 0)        ; if user clicked checkbox then commit changes to array
	__tableEdit_Cleanup()
EndFunc   ;==>__tableEdit_OnCommit

Func __tableEdit_OnInsert()
	; We dynamically check columns count to form sizing variables safely
	Local $iCols = _GUICtrlListView_GetColumnCount($__tableEdit_hView)
	Local $vData[$iCols]
	_GUIListViewEx_Insert($vData)
EndFunc   ;==>__tableEdit_OnInsert

Func __tableEdit_OnDelete()
	_GUIListViewEx_Delete()
EndFunc   ;==>__tableEdit_OnDelete

;Func __tableEdit_OnResize()
;	Local $aNewSize = WinGetClientSize($__tableEdit_hGUI)
;	WinMove($__tableEdit_hView, "", 5, 5 + $__tableEdit_iBtnSize, $aNewSize[0] - 10, $aNewSize[1] - 10 - $__tableEdit_iBtnSize)
;EndFunc   ;==>__tableEdit_OnResize

Func __tableEdit_WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
	If Not $hWnd = $__tableEdit_hGUI Then Return $GUI_RUNDEFMSG

	; $wParam tells you the TYPE of resize (e.g., Maximized, Minimized, or Restored)
	; $lParam contains the NEW WIDTH (low word) and NEW HEIGHT (high word)
	;Local $iNewWidth = BitAND($lParam, 0xFFFF)
	;Local $iNewHeight = BitShift($lParam, 16)

	Local $aSize = WinGetClientSize($hWnd)
	Local $iNewWidth = $aSize[0]
	Local $iNewHeight = $aSize[1]
	WinMove($__tableEdit_hView, "", 5, 5 + $__tableEdit_iBtnSize, $iNewWidth - 10, $iNewHeight - 10 - $__tableEdit_iBtnSize)

	;Local $aNewSize = WinGetClientSize($__tableEdit_hGUI)
	;WinMove($__tableEdit_hView, "", 5, 5 + $__tableEdit_iBtnSize, $aNewSize[0] - 10, $aNewSize[1] - 10 - $__tableEdit_iBtnSize)
	Return $GUI_RUNDEFMSG        ; Return $GUI_RUNDEFMSG so Windows can finish drawing the resized window normally
EndFunc   ;==>__tableEdit_WM_SIZE


Func __tableEditReturn()
	If $__tableEdit_iStatus = 0 Then Return 0
	If $__tableEdit_iStatus = 1 Then
		$__tableEdit_iStatus = 0
		Return 1
	EndIf
	Local $a = $__tableEdit_aReturn
	$__tableEdit_aReturn = False                ; free memory resources
	$__tableEdit_iStatus = 0                    ; reset status
	Return $a
EndFunc   ;==>__tableEditReturn

