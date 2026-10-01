; todo
;   add a button for logging the power


#AutoIt3Wrapper_Icon=dcps_powersupply.ico
#AutoIt3Wrapper_UseX64=Y
#AutoIt3Wrapper_Change2CUI=N

Opt("GUIDataSeparatorChar", "|")

Global $g_bCommValid = 0                      ; IP address and/or communications are valid
Global $g_screenShotFile = ""
Global $hMainGui
Global Const $DCPS_CH_ALL = 0

#include "general.au3"
#include "dcps_visadll.au3"
#include "dcps_config_file.au3"

ProgressOn("DC Power Supply Remote", "Starting DC Power Supply console", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
ProgressSet(0, "Initializing GUI...")


Global $scanButton, $refreshButton, $openButton, $saveButton, $screenShotButton, $emo, _
		$sequenceButton, $upButton, $dnButton, $seqOKbutton, $seqCancelButton, $hIpAddr
Global $mv[4]           ; read voltage
Global $mi[4]           ; read current
Global $rp[4]           ; read power = v*i
Global $sv[4]           ; set voltage
Global $svb[4]          ; set voltage button
Global $si[4]           ; set current
Global $sib[4]          ; set current button
Global $on[4]           ; on/off button
Global $onState[4]      ; current on/off state
Global $lbl[4]          ; output channel label
Global $pcolor[4] = [$COLOR_YELLOW, $COLOR_GREEN, $COLOR_BLUE, $COLOR_PURPLE]
;Global $pcolor[4] = [0xFFFF00, 0x00FF00, 0x0000FF, 0xFF00FF]



MainGuiCreate()                               ; create main gui window, but do not show it yet
SeqGuiCreate()                                ; create sequence settings window, not shown yet
GUISwitch($hMainGui)                          ; switch context back to main gui window

Global $upseqch[4] = [1, 2, 0, -1]            ; default sequence
Global $upseqtm[4] = [0.5, 0.5, 0, 0]
Global $dnseqch[4] = [0, 2, 1, -1]
Global $dnseqtm[4] = [0.5, 0.5, 0, 0]

ProgressSet(50, "Loading config...")
ConfigRead()                                  ; read config file and assert settings

ProgressSet(75, "Connecting to DC Power Supply...")

MainGuiShow()                                 ; show the main gui and register event handlers


GetID()

ProgressOff()



Local $iReadIndex = -1                ; rolling index of items to read from visa device
Local $iTimer = TimerInit()            ; Track time for background supply polling (runs every 900ms without blocking GUI)

While 1
	; 1. Poll the Windows Message Queue
	Local $nMsg = GUIGetMsg()

	Switch $nMsg
		; --- Global/Main Window Events ---
		Case $GUI_EVENT_CLOSE
			CloseApp()

		Case $scanButton
			ScanNetwork()

		Case $refreshButton, $hIpAddr
			GetID()

			;Case $openButton
			;	ConfigOpen()

			;Case $saveButton
			;	ConfigSave()

		Case $screenShotButton
			screenShotClick()

		Case $emo
			__dcps_emo()

		Case $upButton
			pwrupClick()

		Case $dnButton
			pwrdownClick()

			; --- Dynamically Generated Control Arrays ---
		Case $lbl[0], $lbl[1], $lbl[2], $lbl[3]
			lblClick($nMsg) ; Pass the clicked control ID down

		Case $svb[0], $svb[1], $svb[2], $svb[3]
			setvClick($nMsg)

		Case $sib[0], $sib[1], $sib[2], $sib[3]
			setiClick($nMsg)

		Case $on[0], $on[1], $on[2], $on[3]
			onClick($nMsg)

		Case $sequenceButton
			sequenceClick()
	EndSwitch

	; 2. Non-blocking Background Hardware Polling
	If $g_bCommValid And TimerDiff($iTimer) >= 400 Then
		$iReadIndex = Mod($iReadIndex + 1, 5)
		;__viFlushErrors("" & GetIP())
		Local $aRead
		Local $viSession = GetIP()
		Switch $iReadIndex
			Case 0
				$aRead = StringSplit(__dcps_viChRequest($viSession, "MEAS:VOLT?", $DCPS_CH_ALL), ",")
				If $aRead[0] >= 4 Then
					Local $i
					For $i = 0 To 3
						GUICtrlSetData($mv[$i], StringFormat("%.3f", $aRead[$i + 1]) & " V")
					Next
				EndIf
			Case 1
				$aRead = StringSplit(__dcps_viChRequest($viSession, "MEAS:CURR?", $DCPS_CH_ALL), ",")
				If $aRead[0] >= 4 Then
					Local $i
					For $i = 0 To 3
						GUICtrlSetData($mi[$i], StringFormat("%.1f", Number($aRead[$i + 1], $NUMBER_DOUBLE) * 1000) & " mA")
						GUICtrlSetData($rp[$i], StringFormat("%.1f", Number(StringTrimRight(GUICtrlRead($mv[$i]), 2), $NUMBER_DOUBLE) * Number($aRead[$i + 1], $NUMBER_DOUBLE) * 1000) & " mW")
					Next
				EndIf
			Case 2
				$aRead = StringSplit(__dcps_viChRequest($viSession, "VOLT?", $DCPS_CH_ALL), ",")
				If $aRead[0] >= 4 Then
					Local $i
					For $i = 0 To 3
						GUICtrlSetData($sv[$i], StringFormat("%.3f", $aRead[$i + 1]) & " V")
					Next
				EndIf
			Case 3
				$aRead = StringSplit(__dcps_viChRequest($viSession, "CURR?", $DCPS_CH_ALL), ",")
				If $aRead[0] >= 4 Then
					Local $i
					For $i = 0 To 3
						GUICtrlSetData($si[$i], StringFormat("%.3f", Number($aRead[$i + 1], $NUMBER_DOUBLE)) & " A")
					Next
				EndIf
			Case 4
				$aRead = StringSplit(__dcps_viChRequest($viSession, "OUTP:STAT?", $DCPS_CH_ALL), ",")
				If $aRead[0] >= 4 Then
					Local $i
					For $i = 0 To 3
						SetOnState($i + 1, $aRead[$i + 1])
					Next
				EndIf
				Local $sErr = __viReadError($viSession)
				If $sErr <> "" Then MsgBox($MB_OK, "DC Power Supply Error", "Error: " & $sErr, 5)
		EndSwitch

		$iTimer = TimerInit() ; Reset background clock
	EndIf
WEnd


CloseApp()
Exit




; GUI create functions


; Main window
Func MainGuiCreate()
	Global Const $V_WIDTH = 522
	Global Const $V_HEIGHT = 242
	$CANVAS_W = $V_WIDTH - 20
	$CANVAS_H = $V_HEIGHT - 20

	$hMainGui = GUICreate("DC Power Supply", $V_WIDTH, $V_HEIGHT, -1, -1, _
			BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX))

	Local $iplbl = GUICtrlCreateLabel("IP Address:", 24, 9, 58, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hIpAddr = GUICtrlCreateCombo("192.168.0.16", 80, 6, 105, 22)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $scanButton = GUICtrlCreateButton($ICON_GLASS, 185, 6, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 13)
	GUICtrlSetTip(-1, "Scan Network for DC Power Supply")

	Global $refreshButton = GUICtrlCreateButton($ICON_REFRESH, 205, 6, 20, 20)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 16, 600)
	GUICtrlSetTip(-1, "Reconnect to DC Power Supply")
	Local $devidlbl = GUICtrlCreateLabel("Device:", 228, 9, 38, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hDevID = GUICtrlCreateInput("devid", 266, 6, 163, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	;Global $openButton = GUICtrlCreateButton("Open", 16, 37, 40, 20)
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetTip(-1, "Load settings from file")
	;Global $saveButton = GUICtrlCreateButton("Save", 56, 37, 40, 20)
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetTip(-1, "Save settings to file")

	Global $screenShotButton = GUICtrlCreateButton($ICON_SCREENSHOT, 16, 88, 40, 40, BitOR($BS_BOTTOM, $BS_CENTER))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 28)
	GUICtrlSetTip(-1, "Grab a screenshot of the DC Power supply display")

	Local $readinglbl = GUICtrlCreateLabel("Reading:", 16, 64, 47, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $voltagelbl = GUICtrlCreateLabel("Voltage", 80, 64, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $currentlbl = GUICtrlCreateLabel("Current (mA)", 56, 88, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $powerlbl = GUICtrlCreateLabel("Power (mW)", 56, 112, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $settinglbl = GUICtrlCreateLabel("Setting:", 16, 136, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $voltagelbl2 = GUICtrlCreateLabel("Voltage", 80, 136, 40, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $currentlbl2 = GUICtrlCreateLabel("Current (A)", 56, 160, 62, 17, $SS_RIGHT)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	For $i = 0 To 3
		$lbl[$i] = GUICtrlCreateLabel("(" & ($i + 1) & ")", 128 + 92 * $i, 40, 85, 17, BitOR($SS_CENTER, $SS_CENTER, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetBkColor($lbl[$i], $pcolor[$i])
		GUICtrlSetFont(-1, Default, 700)
		If $i = 2 Then GUICtrlSetColor($lbl[$i], $COLOR_WHITE)
		GUICtrlSetTip(-1, "Click here to change the name")

		$mv[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 62, 85, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$mi[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 86, 85, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$rp[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 110, 85, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$sv[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 134, 69, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$svb[$i] = GUICtrlCreateButton($ICON_CFG, 196 + 92 * $i, 134, 17, 20)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetTip(-1, "Change the voltage")
		$si[$i] = GUICtrlCreateInput("--", 128 + 92 * $i, 158, 69, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP))
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		$sib[$i] = GUICtrlCreateButton($ICON_CFG, 196 + 92 * $i, 158, 17, 20)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetTip(-1, "Change the max current")
		$onState[$i] = 0
	Next

	Global $upButton = GUICtrlCreateButton("Up", 16, 184, 40, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Power up via the configured sequence")
	Global $dnButton = GUICtrlCreateButton("Down", 56, 184, 40, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Power down via the configured sequence")
	Global $sequenceButton = GUICtrlCreateButton($ICON_CFG, 96, 184, 17, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Edit the power up/down sequence")

	For $i = 0 To 3
		$on[$i] = GUICtrlCreateButton("Off", 154 + 92 * $i, 184, 33, 25)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		;GUICtrlSetBkColor(-1, $pcolor[$i])
	Next

	Global $emo = GUICtrlCreateButton("EMO Stop", 436, 3, 55, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetBkColor(-1, $COLOR_RED)
	GUICtrlSetColor(-1, $COLOR_WHITE)
EndFunc   ;==>MainGuiCreate



; Sequence configuration window
Func SeqGuiCreate()
	Global $seqForm = GUICreate("Power Sequence", 262, 202, 192, 124, -1, -1, $hMainGui)    ; child of main window
	Local $seqLbl5 = GUICtrlCreateLabel("Power up sequence", 24, 8, 99, 17)
	Local $seqLbl6 = GUICtrlCreateLabel("Power down sequence", 144, 8, 113, 17)
	Local $seqLbl1 = GUICtrlCreateLabel("channel", 27, 27, 42, 17)
	Local $seqLbl2 = GUICtrlCreateLabel("delay (s)", 75, 27, 43, 17)
	Local $seqLbl3 = GUICtrlCreateLabel("channel", 147, 27, 42, 17)
	Local $seqLbl4 = GUICtrlCreateLabel("delay (s)", 195, 27, 43, 17)
	Global $sequp[4]
	Global $sequpdly[4]
	Global $seqdn[4]
	Global $seqdndly[4]
	Global $seqLbl[4]
	For $i = 0 To 3
		$seqLbl[$i] = GUICtrlCreateLabel(($i + 1) & ".", 10, 52 + 30 * $i, 13, 17)
		$sequp[$i] = GUICtrlCreateCombo("", 24, 48 + 30 * $i, 40, 25, BitOR($CBS_DROPDOWN, $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
		GUICtrlSetData($sequp[$i], "")
		GUICtrlSetData($sequp[$i], "1|2|3|4")
		$sequpdly[$i] = GUICtrlCreateInput("0.5", 72, 48 + 30 * $i, 60, 21)
		$seqdn[$i] = GUICtrlCreateCombo("1", 144, 48 + 30 * $i, 40, 25, BitOR($CBS_DROPDOWN, $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
		GUICtrlSetData($seqdn[$i], "")
		GUICtrlSetData($seqdn[$i], "1|2|3|4")
		$seqdndly[$i] = GUICtrlCreateInput("0.5", 192, 48 + 30 * $i, 60, 21)
	Next
	Global $seqOKbutton = GUICtrlCreateButton("OK", 40, 167, 65, 25)
	Global $seqCancelButton = GUICtrlCreateButton("Cancel", 136, 167, 89, 25)
EndFunc   ;==>SeqGuiCreate



Func MainGuiShow()
	GUISetState(@SW_SHOW, $hMainGui)

	_GUIScrollBars_Init($hMainGui)
	_GUIScrollBars_SetScrollRange($hMainGui, $SB_HORZ, 0, $CANVAS_W)
	_GUIScrollBars_SetScrollRange($hMainGui, $SB_VERT, 0, $CANVAS_H)

	GUIRegisterMsg($WM_VSCROLL, "WM_VSCROLL")
	GUIRegisterMsg($WM_HSCROLL, "WM_HSCROLL")
	GUIRegisterMsg($WM_MOUSEWHEEL, "WM_MOUSEWHEEL")
	GUIRegisterMsg($WM_SIZE, "WM_SIZE")

	WM_SIZE($hMainGui, 0, 0, 0)                        ; Initialize page sizing adjustments manually on startup
EndFunc   ;==>MainGuiShow




; --- GUI Message Handlers ---




Func SetID($s)
	GUICtrlSetData($hDevID, $s)
EndFunc   ;==>SetID
Func GetIP()
	Return GUICtrlRead($hIpAddr)
EndFunc   ;==>GetIP


Func lblClick($ctrlId)
	Local $j
	Switch $ctrlId
		Case $lbl[0]
			$j = 0
		Case $lbl[1]
			$j = 1
		Case $lbl[2]
			$j = 2
		Case $lbl[3]
			$j = 3
	EndSwitch
	Local $n = InputBox("Set Label" & ($j + 1), "Label", GUICtrlRead($lbl[$j]), "", 200, 120)
	If $n <> "" Then GUICtrlSetData($lbl[$j], $n)
EndFunc   ;==>lblClick



Func onClick($ctrlId)
	Local $j
	Switch $ctrlId
		Case $on[0]
			$j = 0
		Case $on[1]
			$j = 1
		Case $on[2]
			$j = 2
		Case $on[3]
			$j = 3
	EndSwitch
	Local $viSession = GetIP()
	If Not __viBegin($viSession) Then Return SetError(@error, @extended, 0)
	Local $bState = __dcps_GetState($viSession, $j + 1)
	If @error Then
		__viEnd($viSession)
		Return
	EndIf
	__dcps_SetState($viSession, $j + 1, 1 - Number($bState))
	If @error Then
		__viEnd($viSession)
		Return
	EndIf
	$bState = __dcps_GetState($viSession, $j + 1)
	__viEnd($viSession)
	SetOnState($j + 1, $bState)
EndFunc   ;==>onClick



Func pwrupClick()
	For $j = 0 To 3
		If $upseqch[$j] > 0 Then
			SetState($upseqch[$j], 1)
			Sleep($upseqtm[$j] * 1000)
		EndIf
	Next
EndFunc   ;==>pwrupClick



Func pwrdownClick()
	For $j = 0 To 3
		If $dnseqch[$j] > 0 Then
			SetState($dnseqch[$j], 0)
			Sleep($dnseqtm[$j] * 1000)
		EndIf
	Next
EndFunc   ;==>pwrdownClick



; in:		$ch = channel 1-4
Func SetState($ch, $s)
	If $ch < 1 Or 4 < $ch Then Return
	$s = $s ? 1 : 0
	Local $viSession = GetIP()
	__dcps_SetState($viSession, $ch, $s)
	SetOnState($ch, $s)
EndFunc   ;==>SetState



Func sequenceClick()
	Local $j
	For $j = 0 To 3
		GUICtrlSetData($sequp[$j], "")
		GUICtrlSetData($sequp[$j], "1|2|3|4|0", $upseqch[$j])
		GUICtrlSetData($sequpdly[$j], $upseqtm[$j])
		GUICtrlSetData($seqdn[$j], "")
		GUICtrlSetData($seqdn[$j], "1|2|3|4|0", $dnseqch[$j])
		GUICtrlSetData($seqdndly[$j], $dnseqtm[$j])
	Next
	GUISetState(@SW_SHOW, $seqForm)        ; show the config dialog

	Global $g_seqVisible = 1

	While $g_seqVisible
		; 1. Poll the Windows Message Queue
		Local $nMsg = GUIGetMsg()

		Switch $nMsg
			; --- Global/Main Window Events ---
			Case $seqOKbutton
				Local $j
				For $j = 0 To 3                                ; read settings from dialog box and put into setting table
					$upseqch[$j] = GUICtrlRead($sequp[$j])
					$upseqtm[$j] = Number(GUICtrlRead($sequpdly[$j]), $NUMBER_DOUBLE)
					$dnseqch[$j] = GUICtrlRead($seqdn[$j])
					$dnseqtm[$j] = Number(GUICtrlRead($seqdndly[$j]), $NUMBER_DOUBLE)
				Next
				seqClose()

			Case $GUI_EVENT_CLOSE, $seqCancelButton
				seqClose()

		EndSwitch
	WEnd
EndFunc   ;==>sequenceClick


Func seqClose()
	$g_seqVisible = 0
	GUISetState(@SW_HIDE, $seqForm)
	;GUISetState(@SW_ENABLE, $hMainGui)
	WinActivate($hMainGui)
EndFunc   ;==>seqClose




Func setvClick($ctrlId)
	Local $j
	Switch $ctrlId
		Case $svb[0]
			$j = 0
		Case $svb[1]
			$j = 1
		Case $svb[2]
			$j = 2
		Case $svb[3]
			$j = 3
	EndSwitch
	Local $v = InputBox("Set output " & ($j + 1) & " voltage", "Voltage", StringTrimRight(GUICtrlRead($sv[$j]), 2), "", 200, 120)
	If $v = "" Then Return
	Local $viSession = GetIP()
	__dcps_SetVoltage($viSession, $j + 1, $v) ; set voltage
	$g_bCommValid = 1
EndFunc   ;==>setvClick



Func setiClick($ctrlId)
	Local $j
	Switch $ctrlId
		Case $sib[0]
			$j = 0
		Case $sib[1]
			$j = 1
		Case $sib[2]
			$j = 2
		Case $sib[3]
			$j = 3
	EndSwitch
	Local $i = InputBox("Set output " & ($j + 1) & " max current", "Max Current", StringTrimRight(GUICtrlRead($si[$j]), 2), "", 200, 120)
	If $i = "" Then Return
	Local $viSession = GetIP()
	__dcps_SetCurrent($viSession, $j + 1, $i)    ; set max current
	$g_bCommValid = 1
EndFunc   ;==>setiClick



; Custom event handler function
Func CloseApp()
	ConfigWrite()
	GUIDelete()
	Exit
EndFunc   ;==>CloseApp



Func GetID()
	GUICtrlSetData($hDevID, "Checking...")
	$g_bCommValid = 0
	Local $viSession = GetIP()
	Local $sId = __viGetID($viSession)
	If @error Then $sId = ""
	GUICtrlSetData($hDevID, $sId)
	_GUICtrlEdit_SetSel($hDevID, 0, 0)
	$g_bCommValid = Number($sId <> "")
EndFunc   ;==>GetID





Func SetOnState($ch, $s)
	If $onState[$ch - 1] <> $s Then
		$onState[$ch - 1] = $s
		GUICtrlSetBkColor($on[$ch - 1], (($s = 0) ? $COLOR_GRAY : $pcolor[$ch - 1]))
		GUICtrlSetData($on[$ch - 1], (($s = 0) ? "Off" : "On"))
	EndIf
EndFunc   ;==>SetOnState









;---------- Capture screen shot functions


Func screenShotClick()
	;------------  grab screenshot
	; ==============================================================================
	; Script:      Grab_N6705B_Screenshot_viOpen.au3
	; Description: Connects to an Agilent N6705B using raw visa32.dll functions
	;              (viOpenDefaultRM, viOpen, viReadToFile), triggers a screenshot,
	;              and streams it directly to a local file.
	; ==============================================================================

	; --- CONFIGURATION ---
	Local $sSavePath = $g_screenShotFile
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($sSavePath, $sDrive, $sDir, $sFileName, $sExtension)
	$sSavePath = FileSaveDialog("Save Screen Shot", $sDrive & $sDir, "(*.gif;*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName & $sExtension, $hMainGui)
	If $sSavePath = "" Then Return

	Local $iRet = __dcps_SaveScreenShot("" & GetIP(), $sSavePath)
	;MsgBox(0, "hi", "$iRet=" & $iRet & @CRLF & "error=" & @error & @CRLF)

EndFunc   ;==>screenShotClick





Func ScanNetwork()
	Local $aRet = __viScanSubnetFilter(__viScanSubnet("192.168.0.0"), "DC Power Supply")
	GUICtrlSetData($hIpAddr, $aRet[0], $aRet[1])
	$g_bCommValid = 1
EndFunc   ;==>ScanNetwork
