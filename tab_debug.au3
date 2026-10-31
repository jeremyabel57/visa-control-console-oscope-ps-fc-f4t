#include-once

#cs

change this to work in the main queue only
$g_oDevMain

change the selection box to pick from $g_oViSelect

add pause, forward and backwards buttons




;add debug edit box to enter script/visa commands and a combo select box to select which item to send it to
;	another edit box to show the results, an execute button, save and load buttons for the edit field

edit box for output showing outgoing visa command and incomming data

save button to save last output received to a file
open and save and execute buttons
combo box to select the visa device

edit box for input of visa command script

#ce



#include <Math.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <StaticConstants.au3>
#include <GuiEdit.au3>

#include "myconstants.au3"
#include "filemisc.au3"
#include "visascpi.au3"
#include "winfuncs.au3"
#include "winmgmt.au3"





Global $g_dbg_iReadTimer, $g_dbg_iRefreshInterval = 950


; GUI elements
Global $g_dbg_hIpAddr, $g_dbg_hDevID, $g_dbg_hInput, $g_dbg_hOutput, $g_dbg_iTabIdx, $g_dbg_oDev
Global $g_dbg_outFile, $g_dbg_inFile, $g_dbg_lastOut, $g_dbg_hStack, $g_dbg_hQueue




;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; initialization functions


; called after gui window is shown during init/setup
Func dbgTab_init()
	;LoopRegister("debugTab_Loop")
	$g_dbg_oDev = dbgTab_GetIP()
	dbgTab_IpRefresh()
	$g_dbg_iReadTimer = TimerInit()
EndFunc   ;==>dbgTab_init





; called during the Tab control section of main gui window setup
Func dbgTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	$g_dbg_iTabIdx = $iTabIdx                   ; save for later to determine if we are the selected tab

	Local $iW = $oCanvas.Item('iW')
	Local $iH = $oCanvas.Item('iH')
	Local $iX = 5
	Local $iY = 3
	Local $w1, $x2
	Local $iW2 = 250                            ; width of column 2
	Local $iWM = $iW - $iX - $iX - $iW2         ; width/height inside margins
	Local $iHM = $iH - $iY - $iY
	Local $iHbar = 30                           ; height of the middle bar
	Local $iH1 = Int(($iHM - $iHbar) * 0.66)    ; height of the upper edit fields
	Local $iH2 = ($iHM - $iHbar) - $iH1         ; height of the lower edit fields
	Local $iYbar = $iY + $iH1 + 5               ; top of middle bar



	$g_dbg_hOutput = GUICtrlCreateInput("", $iX, $iY, $iWM, $iH1, BitOR($GUI_SS_DEFAULT_INPUT, $ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM))
	$g_dbg_hStack = GUICtrlCreateInput("", $iX + $iWM, $iY, $iW2, $iH1, BitOR($GUI_SS_DEFAULT_INPUT, $ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKBOTTOM, $GUI_DOCKWIDTH))


	$iX2 = $iX
	GUICtrlCreateButton($ICON_SAVE, $iX2, $iYbar - 3, 25, 25)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetFont(-1, 16)
	GUICtrlSetOnEvent(-1, "dbgTab_SaveOutput")
	GUICtrlSetTip(-1, "Save the last VISA/SCPI response to a file")
	$iX2 += 25 + 5

	$w1 = Int(($iWM - 280) / 2)
	GUICtrlCreateLabel("Device:", $iX2, $iYbar + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	$g_dbg_hIpAddr = GUICtrlCreateCombo("", $iX2 + 40, $iYbar, $w1, 22)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetOnEvent(-1, "dbgTab_IpRefresh")
	GUICtrlCreateButton($ICON_SEARCH, $iX2 + 40 + $w1, $iYbar - 3, 25, 25)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetFont(-1, 20, 600)
	GUICtrlSetTip(-1, "Scan subnet 192.168.0.0 for possible VISA devices")
	GUICtrlSetOnEvent(-1, "dbgTab_ScanNetwork")
	$iX2 += 40 + $w1 + 25 + 5

	GUICtrlCreateLabel("DevID:", $iX2, $iYbar + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	$g_dbg_hDevID = GUICtrlCreateInput("", $iX2 + 40, $iYbar, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKHEIGHT, $GUI_DOCKRIGHT))
	GUICtrlCreateButton($ICON_REFRESH, $iX2 + 40 + $w1, $iYbar - 3, 25, 25)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetTip(-1, "Reconnect")
	GUICtrlSetFont(-1, 17, 600)
	GUICtrlSetOnEvent(-1, "dbgTab_IpRefresh")
	$iX2 += 65 + $w1 + 5

	GUICtrlCreateButton($ICON_OPEN, $iX2, $iYbar - 3, 25, 25)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetFont(-1, 16)
	GUICtrlSetOnEvent(-1, "dbgTab_OpenInput")
	GUICtrlSetTip(-1, "Open a VISA/SCPI script file")
	$iX2 += 25 + 5
	GUICtrlCreateButton($ICON_SAVE, $iX2, $iYbar - 3, 25, 25)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetFont(-1, 16)
	GUICtrlSetOnEvent(-1, "dbgTab_SaveInput")
	GUICtrlSetTip(-1, "Save this VISA/SCPI script to a file")
	$iX2 += 25 + 5

	Local $cSend = GUICtrlCreateButton("Send", $iX2, $iYbar - 3, 50, 25)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	GUICtrlSetOnEvent(-1, "dbgTab_Send")
	GUICtrlSetTip(-1, "Send the VISA/SCPI commands to the device")
	$iX2 += 50

	$g_dbg_hInput = GUICtrlCreateInput("", $iX, $iY + $iH1 + $iHbar, $iWM, $iH2, BitOR($GUI_SS_DEFAULT_INPUT, $ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKBOTTOM, $GUI_DOCKRIGHT, $GUI_DOCKHEIGHT))
	$g_dbg_hQueue = GUICtrlCreateInput("", $iX + $iWM, $iY + $iH1 + $iHbar, $iW2, $iH2, BitOR($GUI_SS_DEFAULT_INPUT, $ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))

	__AccelKeyAdd("^{Enter}", $cSend)

EndFunc   ;==>dbgTab_GuiCreate





; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------


; ---------------------------------------------------------------------------
; GUI Event Handler Functions


Func dbgTab_ScanNetwork()
	__viScanSubnet()
EndFunc   ;==>dbgTab_ScanNetwork

Func dbgTab_SaveOutput()
	Local $sDrive, $sDir, $sName, $sExt
	_PathSplit($g_dbg_outFile, $sDrive, $sDir, $sName, $sExt)
	Local $sFile = FileSaveDialog("Save Output", $sDrive & $sDir, "(*.*)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sName, $g_hMainGui)
	If $sFile = "" Then Return
	$g_dbg_outFile = $sFile
	Local $hFile = FileOpen($sFile, 17) ; 1=file (over)write, 16=binary
	If $hFile <= 0 Then Return
	FileWrite($hFile, $g_dbg_lastOut)
	FileClose($hFile)
EndFunc   ;==>dbgTab_SaveOutput

Func dbgTab_SaveInput()
	Local $sDrive, $sDir, $sName, $sExt
	_PathSplit($g_dbg_inFile, $sDrive, $sDir, $sName, $sExt)
	Local $sFile = FileSaveDialog("Save Script", $sDrive & $sDir, "(*.txt)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sName, $g_hMainGui)
	If $sFile = "" Then Return
	$g_dbg_inFile = $sFile
	Local $hFile = FileOpen($sFile, 1) ; open for (over) writing
	If $hFile <= 0 Then Return
	FileWrite($hFile, GUICtrlRead($g_dbg_hInput))
	FileClose($hFile)
EndFunc   ;==>dbgTab_SaveInput

Func dbgTab_OpenInput()
	Local $sDrive, $sDir, $sName, $sExt
	_PathSplit($g_dbg_inFile, $sDrive, $sDir, $sName, $sExt)
	Local $sFile = FileOpenDialog("Open Script", $sDrive & $sDir, "(*.txt)", BitOR($FD_PATHMUSTEXIST, $FD_FILEMUSTEXIST), $sName, $g_hMainGui)
	If $sFile = "" Then Return
	$g_dbg_inFile = $sFile
	Local $hFile = FileOpen($sFile, 0) ; read mode
	If $hFile <= 0 Then Return
	GUICtrlSetData($g_dbg_hInput, FileRead($hFile))
	FileClose($hFile)
EndFunc   ;==>dbgTab_OpenInput

Func dbgTab_Send()
	If Not __viResolveInstrument($g_dbg_oDev) Then Return
	$g_dbg_oDev.Item('debug') = ""
	Local $i
	Local $sReq = GUICtrlRead($g_dbg_hInput)
	Local $aReq = StringSplit($sReq, @LF)
	Local $n = $aReq[0]
	If $n <= 0 Then Return
	For $i = 1 To $n
		$sReq = StringStripWS($aReq[$i], 3)
		__viCmd($g_dbg_oDev, $sReq)
	Next
EndFunc   ;==>dbgTab_Send


Func dbgTab_IpRefresh()
	Local $oDevOld = $g_dbg_oDev
	dbgTab_GetID()
	If $g_dbg_oDev <> $oDevOld Then
		If __IsDictionary($oDevOld) Then
			If $oDevOld.Exists('debug') Then $oDevOld.Remove('debug')   ; remove debug flag from old selection
		EndIf
		GUICtrlSetData($g_dbg_hOutput, "")
		GUICtrlSetData($g_dbg_hQueue, "")
		GUICtrlSetData($g_dbg_hStack, "")
	EndIf
	If __IsDictionary($g_dbg_oDev) Then
		$g_dbg_oDev.Item('debug') = ''                                  ; add debug flag to new selection
		GUICtrlSetData($g_dbg_hOutput, __sPrintVar($g_dbg_oDev, @CRLF & "  ", "oDev") & @CRLF)
	EndIf
EndFunc   ;==>dbgTab_IpRefresh

Func dbgTab_GetIP()
	Return __viGUIGetIP($g_dbg_hIpAddr)
EndFunc   ;==>dbgTab_GetIP

Func dbgTab_GetID()
	__viGUIGetID($g_dbg_hDevID, $g_dbg_hIpAddr, $g_dbg_oDev, "", "")
EndFunc   ;==>dbgTab_GetID





; ----------------------
; ----------------------
; ----------------------
; ----------------------
; ----------------------

; config file functions

Global $dbgTab_ConfigSection = "Diag"
Global $g_configFile

Func dbgTab_ConfigWrite()
	__viSaveIP($g_dbg_hIpAddr, $dbgTab_ConfigSection)
EndFunc   ;==>dbgTab_ConfigWrite

Func dbgTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	__viLoadIP($g_dbg_hIpAddr, $dbgTab_ConfigSection)
EndFunc   ;==>dbgTab_ConfigRead




; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; ---------------------------------------------------------------------------
; Background Polling Subroutines

Func dbgTab_Loop()
	If TimerDiff($g_dbg_iReadTimer) < $g_dbg_iRefreshInterval Then Return
	$g_dbg_iReadTimer = TimerInit()

	If GUICtrlRead($g_cTab) <> $g_dbg_iTabIdx Then Return
	If Not __IsDictionary($g_dbg_oDev) Then Return
	;Local $s = ""
	;If $g_dbg_oDev.Exists('debug') Then $s = $g_dbg_oDev.Item('debug')
	;If $s = "" Then Return

	;_GUICtrlEdit_AppendText($g_dbg_hOutput, $s)

	;$g_dbg_oDev.Item('debug') = ''
EndFunc   ;==>dbgTab_Loop


;; Flicker-Free Append & Scroll Function
;Func _GUICtrlEdit_Append($hEdit, $sText)
;    GUICtrlSendMsg($hEdit, $EM_SETSEL, -1, -1)  			; 1. Move the caret/cursor to the very end of the text ($EM_SETSEL)
;    GUICtrlSendMsg($hEdit, $EM_REPLACESEL, True, $sText)    ; 2. Replace the empty selection at the end with your new text ($EM_REPLACESEL)    ; The 'True' parameter enables the Undo buffer (False bypasses it)
;    GUICtrlSendMsg($idEdit, $EM_SCROLLCARET, 0, 0)          ; 3. Force the control to scroll down to the new caret position ($EM_SCROLLCARET)
;EndFunc
