#include-once

#include "filemisc.au3"
#include "myconstants.au3"
#include "mydebug.au3"
#include "visascpi.au3"


#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>




Global Const $DCPS_CH_ALL = 0


Global $g_dcps_bCommValid = 0                       ; IP address and/or communications are valid
Global $g_dcps_screenShotFile = ""
Global $g_hMainGui, $g_dcps_iTabIdx, $g_dcps_hIpAddr, $g_dcps_hDevID, _
		$g_dcps_cSeqForm, $g_dcps_seqVisible, $g_dcps_iReadTimer, $g_dcps_iReadIndex, _
		$g_dcps_sRead, $g_dcps_viSession = '', $g_dcps_hSeqForm

Global $g_dcps_measV[4]                             ; read voltage
Global $g_dcps_measI[4]                             ; read current
Global $g_dcps_measP[4]                             ; read power = v*i
Global $g_dcps_setV[4]                              ; set voltage
Global $g_dcps_setVb[4]                             ; set voltage button
Global $g_dcps_setI[4]                              ; set current
Global $g_dcps_setIb[4]                             ; set current button
Global $g_dcps_on[4]                                ; on/off button
Global $g_dcps_onState[4]                           ; current on/off state
Global $g_dcps_lbl[4]                               ; output channel label
Global $g_dcps_pcolor[4] = [$COLOR_YELLOW, $COLOR_GREEN, $COLOR_BLUE, $COLOR_PURPLE]

Global $g_dcps_upSeqCh[4] = [1, 2, 0, -1]           ; default sequence
Global $g_dcps_upSeqTm[4] = [0.5, 0.5, 0, 0]
Global $g_dcps_dnSeqCh[4] = [0, 2, 1, -1]
Global $g_dcps_dnSeqTm[4] = [0.5, 0.5, 0, 0]
Global $g_dcps_cSeqUp[4]                            ; gui controls
Global $g_dcps_cSeqUpdly[4]
Global $g_dcps_cSeqDn[4]
Global $g_dcps_cSeqDndly[4]

Global $g_dcps_bPicDownloading = False
Global $g_dcps_bPicData = ''
Global $g_dcps_iScreen, $g_dcps_hScreen


;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; initialization functions


Func dcpsTab_init()
	dcpsTab_SeqGuiCreate()                      ; create sequence settings window, not shown yet
	$g_dcps_bCommValid = True
	$g_dcps_iReadIndex = -1
	LoopRegister("dcpsTab_Loop")
	$g_dcps_iReadTimer = TimerInit()            ; Track time for background supply polling (runs every 900ms without blocking GUI)

	dcpsTab_ConfigRead()                        ; read config file and assert settings
EndFunc   ;==>dcpsTab_init



Func dcpsTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	$g_dcps_iTabIdx = $iTabIdx

	GUICtrlCreateLabel("IP Address:", 24, 9, 58, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_dcps_hIpAddr = GUICtrlCreateCombo("192.168.0.16", 80, 6, 105, 22)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "dcpsTab_GetID")
	GUICtrlCreateButton($ICON_SEARCH, 185, 6, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 15)
	GUICtrlSetTip(-1, "Scan Network for DC Power Supply")
	GUICtrlSetOnEvent(-1, "dcpsTab_ScanNetwork")

	GUICtrlCreateButton($ICON_REFRESH, 205, 6, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 16, 600)
	GUICtrlSetTip(-1, "Reconnect to DC Power Supply")
	GUICtrlSetOnEvent(-1, "dcpsTab_GetID")
	GUICtrlCreateLabel("Device:", 228, 9, 38, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_dcps_hDevID = GUICtrlCreateInput("devid", 266, 6, 163, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	GUICtrlCreateButton($ICON_SCREENSHOT, 16, 88, 40, 40, BitOR($BS_BOTTOM, $BS_CENTER))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 28)
	GUICtrlSetTip(-1, "Grab a screenshot of the DC Power supply display")
	GUICtrlSetOnEvent(-1, "dcpsTab_screenShotClick")

	GUICtrlCreateLabel("Reading:", 16, 64, 47, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Voltage", 80, 64, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Current (mA)", 56, 88, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Power (mW)", 56, 112, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Setting:", 16, 136, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Voltage", 80, 136, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Current (A)", 56, 160, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	Local $i
	For $i = 0 To 3
		$g_dcps_lbl[$i] = GUICtrlCreateLabel("(" & ($i + 1) & ")", 128 + 92 * $i, 40, 85, 17, BitOR($SS_CENTER, $SS_CENTER, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetBkColor($g_dcps_lbl[$i], $g_dcps_pcolor[$i])
		GUICtrlSetFont(-1, Default, 700)
		If $i = 0 Then
			GUICtrlSetColor($g_dcps_lbl[$i], $COLOR_BLACK)
		Else
			GUICtrlSetColor($g_dcps_lbl[$i], $COLOR_WHITE)
		EndIf
		GUICtrlSetTip(-1, "Click here to change the name")
		GUICtrlSetOnEvent(-1, "dcpsTab_lblClick")

		$g_dcps_measV[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 62, 85, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dcps_measI[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 86, 85, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dcps_measP[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 110, 85, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dcps_setV[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 134, 69, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dcps_setVb[$i] = GUICtrlCreateButton($ICON_CFG, 196 + 92 * $i, 134, 17, 20)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetTip(-1, "Change the voltage")
		GUICtrlSetOnEvent(-1, "dcpsTab_setvClick")
		$g_dcps_setI[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 158, 69, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$g_dcps_setIb[$i] = GUICtrlCreateButton($ICON_CFG, 196 + 92 * $i, 158, 17, 20)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetTip(-1, "Change the max current")
		GUICtrlSetOnEvent(-1, "dcpsTab_setiClick")
		$g_dcps_onState[$i] = 0
	Next

	GUICtrlCreateButton("Up", 16, 184, 40, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Power up via the configured sequence")
	GUICtrlSetOnEvent(-1, "dcpsTab_pwrupClick")
	GUICtrlCreateButton("Down", 56, 184, 40, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Power down via the configured sequence")
	GUICtrlSetOnEvent(-1, "dcpsTab_pwrdnClick")
	GUICtrlCreateButton($ICON_CFG, 96, 184, 17, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Edit the power up/down sequence")
	GUICtrlSetOnEvent(-1, "dcpsTab_sequenceClick")

	For $i = 0 To 3
		$g_dcps_on[$i] = GUICtrlCreateButton("Off", 154 + 92 * $i, 184, 33, 25)
		;GUICtrlSetColor($g_dcps_on[$i], $COLOR_BLACK)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetOnEvent(-1, "dcpsTab_onClick")
	Next

	GUICtrlCreateButton("EMO Stop", 436, 3, 55, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetBkColor(-1, $COLOR_RED)
	GUICtrlSetColor(-1, $COLOR_WHITE)
	GUICtrlSetOnEvent(-1, "__dcps_emo")


	Local $issHeight = 240                          ; expected dimensions of screenshot
	Local $issWidth = 320
	Local $y = 242
	Local $x = 522 + 10
	Local $y2 = 10

	GUICtrlCreateButton($ICON_SCREENSHOT, $x, $y2 - 3, 20, 20)
	GUICtrlSetFont(-1, 14)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "dcpsTab_PicRefresh")
	$y2 += 20

	$g_dcps_hScreen = GUICtrlGetHandle(GUICtrlCreatePic("", $x, $y2, $issWidth, $issHeight))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y2 += $issHeight + 5
	$y = _Max($y, $y2)
	$x = $x + $issWidth


	Local $a[] = [$x, $y]
	Return $a
EndFunc   ;==>dcpsTab_GuiCreate






; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; Sequence configuration window
;


Func dcpsTab_SeqGuiCreate()
	$g_dcps_hSeqForm = GUICreate("Power Sequence", 262, 202, 192, 124, -1, -1, $g_hMainGui)    ; child of main window
	GUISetOnEvent($GUI_EVENT_CLOSE, "dcpsTab_seqClose")
	GUICtrlCreateLabel("Power up sequence", 24, 8, 99, 17)
	GUICtrlCreateLabel("Power down sequence", 144, 8, 113, 17)
	GUICtrlCreateLabel("channel", 27, 27, 42, 17)
	GUICtrlCreateLabel("delay (s)", 75, 27, 43, 17)
	GUICtrlCreateLabel("channel", 147, 27, 42, 17)
	GUICtrlCreateLabel("delay (s)", 195, 27, 43, 17)
	For $i = 0 To 3
		GUICtrlCreateLabel(($i + 1) & ".", 10, 52 + 30 * $i, 13, 17)
		$g_dcps_cSeqUp[$i] = GUICtrlCreateCombo("", 24, 48 + 30 * $i, 40, 25, BitOR($CBS_DROPDOWN, $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
		GUICtrlSetData($g_dcps_cSeqUp[$i], "")
		GUICtrlSetData($g_dcps_cSeqUp[$i], "1|2|3|4")
		$g_dcps_cSeqUpdly[$i] = GUICtrlCreateInput("0.5", 72, 48 + 30 * $i, 60, 21)
		$g_dcps_cSeqDn[$i] = GUICtrlCreateCombo("1", 144, 48 + 30 * $i, 40, 25, BitOR($CBS_DROPDOWN, $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
		GUICtrlSetData($g_dcps_cSeqDn[$i], "")
		GUICtrlSetData($g_dcps_cSeqDn[$i], "1|2|3|4")
		$g_dcps_cSeqDndly[$i] = GUICtrlCreateInput("0.5", 192, 48 + 30 * $i, 60, 21)
	Next
	GUICtrlCreateButton("OK", 40, 167, 65, 25)
	GUICtrlSetOnEvent(-1, "dcpsTab_seqOk")
	GUICtrlCreateButton("Cancel", 136, 167, 89, 25)
	GUICtrlSetOnEvent(-1, "dcpsTab_seqClose")
	GUISwitch($g_hMainGui)
EndFunc   ;==>dcpsTab_SeqGuiCreate



Func dcpsTab_sequenceClick()
	Local $j
	For $j = 0 To 3
		GUICtrlSetData($g_dcps_cSeqUp[$j], "")
		GUICtrlSetData($g_dcps_cSeqUp[$j], "1|2|3|4|0", $g_dcps_upSeqCh[$j])
		GUICtrlSetData($g_dcps_cSeqUpdly[$j], $g_dcps_upSeqTm[$j])
		GUICtrlSetData($g_dcps_cSeqDn[$j], "")
		GUICtrlSetData($g_dcps_cSeqDn[$j], "1|2|3|4|0", $g_dcps_dnSeqCh[$j])
		GUICtrlSetData($g_dcps_cSeqDndly[$j], $g_dcps_dnSeqTm[$j])
	Next
	GUISetState(@SW_SHOW, $g_dcps_hSeqForm)     ; show the config dialog
	$g_dcps_seqVisible = 1
EndFunc   ;==>dcpsTab_sequenceClick



Func dcpsTab_seqClose()
	$g_dcps_seqVisible = 0
	GUISetState(@SW_HIDE, $g_dcps_hSeqForm)
	WinActivate($g_hMainGui)
EndFunc   ;==>dcpsTab_seqClose



Func dcpsTab_seqOk()
	Local $j
	For $j = 0 To 3                                            ; read settings from dialog box and put into setting table
		$g_dcps_upSeqCh[$j] = GUICtrlRead($g_dcps_cSeqUp[$j])
		$g_dcps_upSeqTm[$j] = Number(GUICtrlRead($g_dcps_cSeqUpdly[$j]), $NUMBER_DOUBLE)
		$g_dcps_dnSeqCh[$j] = GUICtrlRead($g_dcps_cSeqDn[$j])
		$g_dcps_dnSeqTm[$j] = Number(GUICtrlRead($g_dcps_cSeqDndly[$j]), $NUMBER_DOUBLE)
	Next
	dcpsTab_seqClose()
EndFunc   ;==>dcpsTab_seqOk




; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------







; ---------------------------------------------------------------------------
; GUI Event Handler Functions



Func dcpsTab_GetID()
	Local $sId = __viGUIGetID($g_dcps_hDevID, $g_dcps_hIpAddr)
	$g_dcps_bCommValid = Not ($sId = "")
	$g_dcps_viSession = dcpsTab_GetIP()
	Return $sId
EndFunc   ;==>dcpsTab_GetID



Func dcpsTab_GetIP()
	Return __viGetIP($g_dcps_hIpAddr)
EndFunc   ;==>dcpsTab_GetIP



Func dcpsTab_lblClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dcps_lbl[0]
			$j = 1
		Case $g_dcps_lbl[1]
			$j = 2
		Case $g_dcps_lbl[2]
			$j = 3
		Case $g_dcps_lbl[3]
			$j = 4
	EndSwitch
	Local $n = InputBox("Set Label" & $j, "Label", GUICtrlRead(@GUI_CtrlId), "", 200, 120)
	If $n <> "" Then GUICtrlSetData(@GUI_CtrlId, $n)
EndFunc   ;==>dcpsTab_lblClick



Func dcpsTab_onClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dcps_on[0]
			$j = 0
		Case $g_dcps_on[1]
			$j = 1
		Case $g_dcps_on[2]
			$j = 2
		Case $g_dcps_on[3]
			$j = 3
	EndSwitch
	Local $bState = __dcps_GetState($g_dcps_viSession, $j + 1)
	If @error Then Return
	__dcps_SetState($g_dcps_viSession, $j + 1, 1 - Number($bState))
	If @error Then Return
	$bState = __dcps_GetState($g_dcps_viSession, $j + 1)
	dcpsTab_SetOnState($j + 1, $bState)
EndFunc   ;==>dcpsTab_onClick



Func dcpsTab_pwrupClick()
	For $j = 0 To 3
		If $g_dcps_upSeqCh[$j] > 0 Then
			dcpsTab_SetState($g_dcps_upSeqCh[$j], 1)
			Sleep($g_dcps_upSeqTm[$j] * 1000)
		EndIf
	Next
EndFunc   ;==>dcpsTab_pwrupClick



Func dcpsTab_pwrdnClick()
	For $j = 0 To 3
		If $g_dcps_dnSeqCh[$j] > 0 Then
			dcpsTab_SetState($g_dcps_dnSeqCh[$j], 0)
			Sleep($g_dcps_dnSeqTm[$j] * 1000)
		EndIf
	Next
EndFunc   ;==>dcpsTab_pwrdnClick



; in:		$ch = channel 1-4
Func dcpsTab_SetState($ch, $s)
	If $ch < 1 Or 4 < $ch Then Return
	$s = $s ? 1 : 0
	__dcps_SetState($g_dcps_viSession, $ch, $s)
	dcpsTab_SetOnState($ch, $s)
EndFunc   ;==>dcpsTab_SetState



Func dcpsTab_setvClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dcps_setVb[0]
			$j = 0
		Case $g_dcps_setVb[1]
			$j = 1
		Case $g_dcps_setVb[2]
			$j = 2
		Case $g_dcps_setVb[3]
			$j = 3
	EndSwitch
	Local $v = InputBox("Set output " & ($j + 1) & " voltage", "Voltage", StringTrimRight(GUICtrlRead($g_dcps_setV[$j]), 2), "", 200, 120)
	If $v = "" Then Return
	__dcps_SetVoltage($g_dcps_viSession, $j + 1, $v) ; set voltage
	$g_dcps_bCommValid = 1
EndFunc   ;==>dcpsTab_setvClick



Func dcpsTab_setiClick()
	Local $j
	Switch @GUI_CtrlId
		Case $g_dcps_setIb[0]
			$j = 0
		Case $g_dcps_setIb[1]
			$j = 1
		Case $g_dcps_setIb[2]
			$j = 2
		Case $g_dcps_setIb[3]
			$j = 3
	EndSwitch
	Local $i = InputBox("Set output " & ($j + 1) & " max current", "Max Current", StringTrimRight(GUICtrlRead($g_dcps_setI[$j]), 2), "", 200, 120)
	If $i = "" Then Return
	__dcps_SetCurrent($g_dcps_viSession, $j + 1, $i)    ; set max current
	$g_bCommValid = 1
EndFunc   ;==>dcpsTab_setiClick



Func dcpsTab_SetOnState($ch, $s)    		; ch=1-4
	$ch-=1
	If $g_dcps_onState[$ch] <> $s Then
		$g_dcps_onState[$ch] = $s
		GUICtrlSetBkColor($g_dcps_on[$ch], (($s = 0) ? $COLOR_GRAY : $g_dcps_pcolor[$ch - 1]))
		GUICtrlSetColor($g_dcps_on[$ch], ((($s <> 0) or ($ch = 0)) ? $COLOR_BLACK : $COLOR_WHITE))
		GUICtrlSetData($g_dcps_on[$ch], (($s = 0) ? "Off" : "On"))
	EndIf
EndFunc   ;==>dcpsTab_SetOnState



;---------- Capture screen shot functions
Func dcpsTab_screenShotClick()
	;------------  grab screenshot
	; ==============================================================================
	; Script:      Grab_N6705B_Screenshot_viOpen.au3
	; Description: Connects to an Agilent N6705B using raw visa32.dll functions
	;              (viOpenDefaultRM, viOpen, viReadToFile), triggers a screenshot,
	;              and streams it directly to a local file.
	; ==============================================================================

	; --- CONFIGURATION ---
	Local $sSavePath = $g_dcps_screenShotFile
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($sSavePath, $sDrive, $sDir, $sFileName, $sExtension)
	$sSavePath = FileSaveDialog("Save Screen Shot", $sDrive & $sDir, "(*.gif;*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName & $sExtension, $g_hMainGui)
	If $sSavePath = "" Then Return

	Local $iRet = __dcps_SaveScreenShot($g_dcps_viSession, $sSavePath)
	;MsgBox(0, "hi", "$iRet=" & $iRet & @CRLF & "error=" & @error & @CRLF)

EndFunc   ;==>dcpsTab_screenShotClick





; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; dc power supply visa functions



; task:			Set the on/off state of a DC Power supply channel
; in:			$ch = channel 1-4
;				$b = 1 for on, 0 for off
Func __dcps_SetState(ByRef $viSession, $ch, $b)
	__viCmdBl($viSession, ":OUTP " & ($b ? "OFF" : "ON") & ", (@" & $ch & ")")        ; send command, do not wait for response
EndFunc   ;==>__dcps_SetState

Func __dcps_GetState(ByRef $viSession, $ch, $iTimeoutMS = 1000)
	Return __viReqBl($viSession, ":OUTP:STAT? (@" & $ch & ")", $iTimeoutMS)
EndFunc   ;==>__dcps_GetState

; task:			turn all power output channels off
Func __dcps_emo()
	Local $viSession = dcpsTab_GetIP()
	__viCmdBl($viSession, ":OUTP OFF, (@1:4)")
EndFunc   ;==>__dcps_emo




; task:			set the output voltage of a channel
; in:			ch = channel 1-4
Func __dcps_SetVoltage($viSession, $iCh, $fVoltage)
	__viCmd($viSession, ":VOLT " & $fVoltage & ", (@" & $iCh & ")")                 ; set voltage
EndFunc   ;==>__dcps_SetVoltage



; task:			set the max output current of a channel
; in:			ch = channel 1-4
Func __dcps_SetCurrent($viSession, $iCh, $fCurrent)
	__viCmd($viSession, ":CURR " & $fCurrent & ", (@" & $iCh & ")")                 ; set current
EndFunc   ;==>__dcps_SetCurrent



;			send request for a given channel
; in:		$ipAddr = IP address of device
;			$sReq = request prefix (without the "(@ch)" channel number)
;			$iCh = 1-4 or 0 for all
; out:		response from device
Func __dcps_viChRequest($viSession, $sReq, $iCh = 0)
	$iCh = Number($iCh)
	If ($iCh < 1) Or (4 < $iCh) Then $iCh = "1:4"
	Return __viReqBl($viSession, $sReq & " (@" & $iCh & ")", 1000)
EndFunc   ;==>__dcps_viChRequest




; task:		grab screenshot and save it to file
; in:		$vSession = ip address of DC power supply, or existing visa session handle
;			$sFile = path and name of destination file
Func __dcps_SaveScreenShot($viSession, $sFile = $g_dcps_screenShotFile, $iTimeoutMS = 15000)
	Local $aCmds = [ _
			"$ignore=:SYST:ERR?", _
			":HCOPy:SDUMp:DATA:FORMat PNG", _
			"$ignore=*OPC?", _
			"##:HCOPy:SDUMp:DATA?"]
	__viScript($viSession, $aCmds, $sFile, $iTimeoutMS)
	Return __viFlush($viSession)
EndFunc   ;==>__dcps_SaveScreenShot




Func dcpsTab_ScanNetwork()
	__viScanSubnet("192.168.0.0", $g_dcps_hIpAddr, "DC Power Supply")
EndFunc   ;==>dcpsTab_ScanNetwork



Func dcpsTab_PicRefresh()             ; download latest screenshot from DCPS and show in the gui
	$g_dcps_bPicDownloading = True
	$g_dcps_bPicData = ''
	Local $aCmds = [ _
			"$ignore=:SYST:ERR?", _
			":HCOPy:SDUMp:DATA:FORMat PNG", _
			"$ignore=*OPC?", _
			"$g_dcps_bPicData=HCOPy:SDUMp:DATA?"]
	__viScript($g_dcps_viSession, $aCmds, "", 15000)
EndFunc   ;==>dcpsTab_PicRefresh




; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

; background loop


Func dcpsTab_Loop()

	If $g_dcps_bPicDownloading Then             ; when screenshot download is received then update the gui
		If IsBinary($g_dcps_bPicData) Then
			__viParsePicture($g_dcps_bPicData)
			Local $oCanvas = $g_aCanvas[$g_dcps_iTabIdx]
			If $g_dcps_iScreen < 0 Then $g_dcps_iScreen = __Canvas_ZoomFind($oCanvas, $g_dcps_hScreen)
			If $g_dcps_iScreen >= 0 Then
				Local $aCtrl = $oCanvas.Item('aCtrls')
				$aCtrl[$g_dcps_iScreen][5] = $g_dcps_bPicData
				$oCanvas.Item('aCtrls') = $aCtrl
				;__ConsolePrintVar("picdl", "iScreen", $g_dcps_iScreen, "aCtrl", $aCtrl)
				;__GUICtrlSetPicture($g_dcps_hScreen, $g_dcps_bPicData, True)
				If GUICtrlRead($g_cTab) = $g_dcps_iTabIdx Then __Canvas_AdjZoom($oCanvas)      ; adjust the picture to the current zoom scale and put it in the gui
				$g_dcps_bPicData = 0
			EndIf
			$g_dcps_bPicDownloading = False
		EndIf
	EndIf

	If GUICtrlRead($g_cTab) <> $g_dcps_iTabIdx Then Return      ; if we are not the visible tab then nothing more to do

	Local $MEASVOLT = "MEAS:VOLT? (@1:4)"       ; read measured output voltage
	Local $MEASCURR = "MEAS:CURR? (@1:4)"       ; read measured output current
	Local $RVOLTSET = "VOLT? (@1:4)"            ; read output voltage setpoint
	Local $RCURRSET = "CURR? (@1:4)"            ; read max output current setpoint
	Local $OUTPSTAT = "OUTP:STAT? (@1:4)"       ; read output state (on or off)
	Local $SREAD = "$g_dcps_sRead="             ; prefix to save visa reply to this global variable
	Local $i

	If $g_dcps_bCommValid And TimerDiff($g_dcps_iReadTimer) >= 200 Then
		If $g_dcps_iReadIndex < 0 Then
			$g_dcps_sRead = ''
			__viReq($g_dcps_viSession, $SREAD & $MEASVOLT)
			$g_dcps_iReadIndex = 0
		EndIf
		If $g_dcps_sRead <> '' Then             ; if we received response from last request then update gui and send next request
			Local $aRead = StringSplit($g_dcps_sRead, ",")
			Local $sNextReq = ''
			Switch $g_dcps_iReadIndex
				Case 0
					If $aRead[0] >= 4 Then
						For $i = 0 To 3
							GUICtrlSetData($g_dcps_measV[$i], StringFormat("%.3f", $aRead[$i + 1]) & " V")
						Next
					EndIf
					$sNextReq = $MEASCURR
				Case 1
					If $aRead[0] >= 4 Then
						For $i = 0 To 3
							GUICtrlSetData($g_dcps_measI[$i], StringFormat("%.1f", Number($aRead[$i + 1], $NUMBER_DOUBLE) * 1000) & " mA")
							GUICtrlSetData($g_dcps_measP[$i], StringFormat("%.1f", Number(StringTrimRight(GUICtrlRead($g_dcps_measV[$i]), 2), $NUMBER_DOUBLE) * Number($aRead[$i + 1], $NUMBER_DOUBLE) * 1000) & " mW")
						Next
					EndIf
					$sNextReq = $RVOLTSET
				Case 2
					If $aRead[0] >= 4 Then
						For $i = 0 To 3
							GUICtrlSetData($g_dcps_setV[$i], StringFormat("%.3f", $aRead[$i + 1]) & " V")
						Next
					EndIf
					$sNextReq = $RCURRSET
				Case 3
					If $aRead[0] >= 4 Then
						For $i = 0 To 3
							GUICtrlSetData($g_dcps_setI[$i], StringFormat("%.3f", Number($aRead[$i + 1], $NUMBER_DOUBLE)) & " A")
						Next
					EndIf
					$sNextReq = $OUTPSTAT
				Case 4
					If $aRead[0] >= 4 Then
						For $i = 0 To 3
							dcpsTab_SetOnState($i + 1, $aRead[$i + 1])
						Next
					EndIf
					__viReq($g_dcps_viSession, "$ignore=" & $VI_REQ_ERR)
					$sNextReq = $MEASVOLT
			EndSwitch
			$g_dcps_sRead = ''
			__viReq($g_dcps_viSession, $SREAD & $sNextReq)
			$g_dcps_iReadIndex = Mod($g_dcps_iReadIndex + 1, 5)
		EndIf

		$g_dcps_iReadTimer = TimerInit()        ; Reset background clock
	EndIf
EndFunc   ;==>dcpsTab_Loop








; ----------------------
; ----------------------
; ----------------------
; ----------------------
; ----------------------

; config file functions



Global $dcpsTab_ConfigSection = "DCPS"
Global $g_configFile

Func dcpsTab_ConfigWrite()
	__viSaveIP($g_dcps_hIpAddr, $dcpsTab_ConfigSection)
	Local $j
	For $j = 0 To 3
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "V" & ($j + 1), StringTrimRight(GUICtrlRead($g_dcps_setV[$j]), 2))
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "I" & ($j + 1), StringTrimRight(GUICtrlRead($g_dcps_setI[$j]), 2))
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "upseqch" & ($j + 1), $g_dcps_upSeqCh[$j])
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "upseqtm" & ($j + 1), $g_dcps_upSeqTm[$j])
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "dnseqch" & ($j + 1), $g_dcps_dnSeqCh[$j])
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "dnseqtm" & ($j + 1), $g_dcps_dnSeqTm[$j])
		IniWrite($g_configFile, $dcpsTab_ConfigSection, "chlbl" & ($j + 1), GUICtrlRead($g_dcps_lbl[$j]))
	Next
	IniWrite($g_configFile, $dcpsTab_ConfigSection, "screenShot", $g_dcps_screenShotFile)        ; file name of the screenshot file
EndFunc   ;==>dcpsTab_ConfigWrite



Func dcpsTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	Local $j
	__viLoadIP($g_dcps_hIpAddr, $dcpsTab_ConfigSection)
	For $j = 0 To 3
		GUICtrlSetData($g_dcps_setV[$j], IniRead($g_configFile, $dcpsTab_ConfigSection, "V" & ($j + 1), StringTrimRight(GUICtrlRead($g_dcps_setV[$j]), 2)) & " V")
		GUICtrlSetData($g_dcps_setI[$j], IniRead($g_configFile, $dcpsTab_ConfigSection, "I" & ($j + 1), StringTrimRight(GUICtrlRead($g_dcps_setI[$j]), 2)) & " A")
		$g_dcps_upSeqCh[$j] = IniRead($g_configFile, $dcpsTab_ConfigSection, "upseqch" & ($j + 1), $g_dcps_upSeqCh[$j])
		$g_dcps_upSeqTm[$j] = IniRead($g_configFile, $dcpsTab_ConfigSection, "upseqtm" & ($j + 1), $g_dcps_upSeqTm[$j])
		$g_dcps_dnSeqCh[$j] = IniRead($g_configFile, $dcpsTab_ConfigSection, "dnseqch" & ($j + 1), $g_dcps_dnSeqCh[$j])
		$g_dcps_dnSeqTm[$j] = IniRead($g_configFile, $dcpsTab_ConfigSection, "dnseqtm" & ($j + 1), $g_dcps_dnSeqTm[$j])
		GUICtrlSetData($g_dcps_lbl[$j], IniRead($g_configFile, $dcpsTab_ConfigSection, "chlbl" & ($j + 1), GUICtrlRead($g_dcps_lbl[$j])))
	Next
	$g_dcps_screenShotFile = IniRead($g_configFile, $dcpsTab_ConfigSection, "screenShot", $g_dcps_screenShotFile)           ; screen shot file
	dcpsTab_ConfigAssert()
EndFunc   ;==>dcpsTab_ConfigRead



; task:			Assert config in the GUI onto the DC Power supply
;				if voltage and current settings are the same, then the channel is left alone
;				if voltage or current are updated, then the output state is turned off for safety
Func dcpsTab_ConfigAssert()


	Return ;????


	Local $i, $cv, $nv, $aReadV, $aReadI
	dcpsTab_GetID()
	__viCmd($g_dcps_viSession, $VI_CLS)
	$aReadV = StringSplit(__dcps_viChRequest($g_dcps_viSession, "VOLT?", $DCPS_CH_ALL), ",")
	If $aReadV[0] < 4 Then Return SetError(-1, 0, 0)
	$aReadI = StringSplit(__dcps_viChRequest($g_dcps_viSession, "CURR?", $DCPS_CH_ALL), ",")
	If $aReadI[0] < 4 Then Return SetError(-1, 0, 0)

	For $i = 0 To 3
		; voltage setpoint
		$cv = StringFormat("%.3f", $aReadV[$i + 1])
		$nv = StringTrimRight(GUICtrlRead($g_dcps_setV[$i]), 2)
		If Not ($cv = $nv) Then
			__dcps_SetState($g_dcps_viSession, $i + 1, 0)                ; turn off the channel power output
			__dcps_SetVoltage($g_dcps_viSession, $i + 1, Number($nv))    ; set the voltage
		EndIf

		; max current setpoint
		$cv = StringFormat("%.3f", $aReadI[$i + 1])
		$nv = StringTrimRight(GUICtrlRead($g_dcps_setI[$i]), 2)
		If Not ($cv = $nv) Then
			__dcps_SetState($g_dcps_viSession, $i + 1, 0)                ; turn off the channel power output
			__dcps_SetCurrent($g_dcps_viSession, $i + 1, Number($nv))    ; set the max current
		EndIf
	Next
EndFunc   ;==>dcpsTab_ConfigAssert










; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------

