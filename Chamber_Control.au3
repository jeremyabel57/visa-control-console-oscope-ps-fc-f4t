; goal:
; gui input box for setting chamber control
; gui read only text field for real time temperature monitoring (poll every 1-2 seconds)
; set temperature button
; toggle power on/off

#AutoIt3Wrapper_Icon=f4t_temperatureChamber2.ico
#AutoIt3Wrapper_UseX64=Y
#AutoIt3Wrapper_Change2CUI=N


#include "general.au3"

Global $hIpAddr, $hDevID

#include "f4t_modbustcp.au3"
#include "f4t_config_file.au3"
#include "f4t_visadll.au3"

ProgressOn("F4T Temperature Chamber", "Starting Chamber Remote", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
ProgressSet(0, "Initializing...")



Global $g_bCommValid = 0                      ; IP address and/or communications are valid
Opt("GUIDataSeparatorChar", "|")
Global $bInTarget = 0                        ; true if we are within 0.5 degree of setpoint temperature
Global $iReadIndex = -1

; Main window
MainGuiCreate()                             ; create main gui window, but do not show it yet
ProgressSet(50, "Reading Config....")
ConfigRead()                                ; read config file and update settings
ProgressSet(75, "Connecting to chamber...")
MainGuiShow()                                ; show the main gui and register event handlers

;Sleep(3000)
;GetID()

ProgressSet(100)
ProgressOff()


Global $hIpAddr, $refreshBtn, $findBtn, $hTunits, $hSPunits, $hSPbtn, $hPowerBtn, $hT, $hTnote, $hTunits, $hSP, $hSPunits

; Track time for background chamber polling (runs every 1500ms without freezing the GUI)
Local $iTimer = TimerInit()

While 1
	; 1. Poll the Windows Message Queue
	Local $nMsg = GUIGetMsg()

	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			CloseApp()

		Case $hIpAddr, $refreshBtn
			IpAddrChange()

		Case $findBtn
			ScanNetwork()

		Case $hTunits
			ToggleTunits()

		Case $hSPunits
			ToggleSetPointUnits()

		Case $hSPbtn
			ChangeSetPoint()

		Case $hPowerBtn
			PowerBtnClick()
	EndSwitch

	;MsgBox(0, "hi", "hi")

	; 2. Non-blocking Background Hardware Polling
	If (Not ($g_bCommValid = 0)) And TimerDiff($iTimer) >= 900 Then
		$iReadIndex = Mod($iReadIndex + 1, 3)
		Local $fRead, $fReadC, $fPrev
		;MsgBox(0, "hi", "iReadIndex=" & $iReadIndex & @CRLF)

		Switch $iReadIndex
			Case 0
				;*		MsgBox(0, "hi", "hi")
				;ConsoleWrite("iReadIndex: __F4T_GetTepmerature().  valid=" & $g_bCommValid & @CRLF)
				$fReadC = Number(__F4T_GetTemperature())                        ; read temperature
				;ConsoleWrite("iReadIndex: __F4T_GetTepmerature().  valid=" & $g_bCommValid & ",  fReadC=" & $fReadC & @CRLF)
				If $fReadC > -1000 Then
					$fRead = $fReadC
					If Not GuiGetUnits($hTunits) Then $fRead = __F4T_CtoF($fReadC)
					$fRead = StringFormat("%.1f", $fRead)
					$fPrev = Number(GUICtrlRead($hT))
					If $fPrev <> $fRead Then GUICtrlSetData($hT, $fRead)        ; if number changed then update GUI
					; notify user when we reach temperature
					If (GUICtrlRead($hTnote) = $GUI_CHECKED) Then
						Local $bInTargetNow = (Abs($fPrev - $fRead) <= 0.5) ? 1 : 0
						If Not ($bInTargetNow = $bInTarget) Then
							If $bInTargetNow Then
								Local $sT = $fRead & " " & (GuiGetUnits($hTunits) ? $ICON_DEGREEC : $ICON_DEGREEF)
								Local $sS = StringFormat("%.1f", Number(GUICtrlRead($hSP))) & " " & (GuiGetUnits($hSPunits) ? $ICON_DEGREEC : $ICON_DEGREEF)
								MsgBox($MB_OK, "Chamber " & GUICtrlRead($hIpAddr), "Setpoint temperature reached" & @CRLF & _
										"Temperature = " & $sT & @CRLF & _
										"Set Point = " & $sS & @CRLF)
							EndIf
							$bInTarget = $bInTargetNow
						EndIf
					EndIf

				EndIf
			Case 1
				$fReadC = Number(__F4T_GetSetpoint())                            ; read setpoint
				If $fReadC > -1000 Then
					$fRead = $fReadC
					If Not GuiGetUnits($hSPunits) Then $fRead = __F4T_CtoF($fReadC)
					$fRead = StringFormat("%.1f", $fRead)
					$fPrev = Number(GUICtrlRead($hSP))
					If $fPrev <> $fRead Then GUICtrlSetData($hSP, $fRead)        ; if number changed then update GUI
				EndIf
			Case 2
				UpdateOutputState(__F4T_GetEnable())                            ; read the output state and update GUI
		EndSwitch



		$iTimer = TimerInit() ; Reset background clock
	EndIf

WEnd

CloseApp()
Exit





; ---------------------------- Main window functions

Global $CANVAS_H, $CANVAS_W


Func MainGuiCreate()

	;Opt("GUIOnEventMode", 1)
	Global Const $V_WIDTH = 200
	Global Const $V_HEIGHT = 140
	$CANVAS_W = $V_WIDTH - 20
	$CANVAS_H = $V_HEIGHT - 20

	Global $hMainGui = GUICreate("Chamber", $V_WIDTH, $V_HEIGHT, -1, -1, _
			BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX))

	;GUISetOnEvent($GUI_EVENT_CLOSE, "CloseApp")

	Local $y = 5

	Local $hAddrLbl = GUICtrlCreateLabel("IP Address:", 10, $y + 3, 55, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hIpAddr = GUICtrlCreateCombo("", 65, $y, 105, 22)
	GUICtrlSetData($hIpAddr, "|192.168.0.25", "192.168.0.25")
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "IpAddrChange")
	Global $findBtn = GUICtrlCreateButton($ICON_GLASS, 170, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 14)
	;GUICtrlSetOnEvent(-1, "ScanNetwork")
	GUICtrlSetTip(-1, "Scan subnet 192.168.0.0 for possible VISA devices")

	$y = $y + 25
	Global $hDevIDlbl = GUICtrlCreateLabel("Device:", 10, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;;GUICtrlSetOnEvent(-1, "devidlblClick")
	Global $hDevID = GUICtrlCreateInput("", 50, $y, 120, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $refreshBtn = GUICtrlCreateButton($ICON_REFRESH, 170, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "IpAddrChange")
	GUICtrlSetTip(-1, "Reconnect to Chamber")
	GUICtrlSetFont(-1, 18, 600)

	$y = $y + 45
	Local $hTlbl = GUICtrlCreateLabel("Temperature:", 15, $y + 3, 80, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hT = GUICtrlCreateInput("----", 95, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	Global $hTunits = GUICtrlCreateLabel($ICON_DEGREEC, 150, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "ToggleTunits")
	Global $hTnote = GUICtrlCreateCheckbox("", 176, $y, 20, 20)
	GUICtrlSetState(-1, 0)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$y = $y + 27
	Local $hSPlbl = GUICtrlCreateLabel("Set Point:", 45, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hSP = GUICtrlCreateInput("----", 95, $y - 2, 55, 23, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 12)
	Global $hSPunits = GUICtrlCreateLabel($ICON_DEGREEC, 150, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "ToggleSetPointUnits")
	Global $hSPbtn = GUICtrlCreateButton($ICON_CFG, 170, $y - 3, 25, 25, BitOR($GUI_SS_DEFAULT_INPUT, $BS_DEFPUSHBUTTON))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "ChangeSetPoint")
	GUICtrlSetFont(-1, 11, 600)


	Global $hPowerBtn = GUICtrlCreateButton($ICON_POWERBTN, 10, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "PowerBtnClick")
	GUICtrlSetTip(-1, "Toggle Chamber Compressor/output on/off." & @CRLF & "Click here then wait one second to confirm it took effect.")
	;GUICtrlSetFont(-1, 8, 600, 0, "Segoe UI")

	#comments-start
		; Create Heat Progress Bar (Solid Red, No Animation)
		Local $hHeatLbl = GUICtrlCreateLabel("Heat:", 10, 110, 30, 15)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		Global $hHeatBar = GUICtrlCreateProgress(40, 110, 135, 12, $PBS_SMOOTH)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetData(-1, 0)
		DllCall("uxtheme.dll", "long", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hHeatBar), "wstr", "", "wstr", "")
		GUICtrlSetColor($hHeatBar, 0xDF3A25)                                 ; Set to Solid Red
		GUICtrlSetBkColor($hHeatBar, 0xEAEAEA)                               ; Light Gray Background

		; Create Cool Progress Bar (Solid Blue, No Animation)
		Local $hCoolLbl = GUICtrlCreateLabel("Cool:", 10, 130, 30, 15)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		Global $hCoolBar = GUICtrlCreateProgress(40, 130, 135, 12, $PBS_SMOOTH)
		GUICtrlSetResizing(-1, $GUI_DOCKALL)
		GUICtrlSetData(-1, 0)
		DllCall("uxtheme.dll", "long", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hCoolBar), "wstr", "", "wstr", "")
		GUICtrlSetColor($hCoolBar, 0x2A75D3)                                 ; Set to Solid Blue
		GUICtrlSetBkColor($hCoolBar, 0xEAEAEA)                               ; Light Gray Background
	#comments-end

EndFunc   ;==>MainGuiCreate



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



Func CloseApp()
	ConfigWrite()                    ; save settings on exit
	GUIDelete()
	Exit
EndFunc   ;==>CloseApp









; ---------------- Read Data from chamber functions

Func GetIP()
	Return GUICtrlRead($hIpAddr)
EndFunc   ;==>GetIP

Func SetIP($sIP)
	Local $a = "|" & _GUICtrlComboBox_GetList($hIpAddr)             ; IP address list
	If Not StringInStr($a, "|" & $sIP) Then $a = "|" & $sIP & $a    ; if $sIP not found in existing list, then add it
	GUICtrlSetData($hIpAddr, $a, $sIP)                              ; IP Address combo box
EndFunc   ;==>SetIP

Func SetID($sId)
	GUICtrlSetData($hDevID, $sId)
	_GUICtrlEdit_SetSel($hDevID, 0, 0)
EndFunc   ;==>SetID

Func GetID()                        ; read ID from VISA device
	GUICtrlSetData($hDevID, "Checking...")
	Local $sIP = "raw:" & GetIP()
	Local $sId = __viGetID($sIP)
	;ConsoleWrite("$sIP=" & $sIP & @CRLF)
	;SetIP($sIP)
	$sId = StringReplace($sId, '"', '')
	$g_bCommValid = ($sId == "") ? 0 : 1
	SetID($sId)
	;ConsoleWrite("$sId=" & $sId & @CRLF & "$g_bCommValid=" & $g_bCommValid & @CRLF)
EndFunc   ;==>GetID


Func FellOffline()
	$g_bCommValid = 0
	GUICtrlSetData($hT, "")
	GUICtrlSetData($hSP, "")
	UpdateOutputState(0)
	GUICtrlSetData($hDevID, "")                                   ; show user that we have lost communications
EndFunc   ;==>FellOffline







; -----------------  GUI event handler functions



Func GuiGetUnits($hLbl)            ; return true if unit label is C or false if F
	Return (GUICtrlRead($hLbl) = $ICON_DEGREEC) + 0            ; return 1 or 0 instead of True / False
EndFunc   ;==>GuiGetUnits



Func GuiSetUnits($hLbl, $bUnits = 1)    ; update the GUI units field with deg C or deg F
	GUICtrlSetData($hLbl, (($bUnits + 0) <> 0) ? $ICON_DEGREEC : $ICON_DEGREEF)
EndFunc   ;==>GuiSetUnits



Func ToggleTunits()                                                            ; switch between C and F
	GuiSetUnits($hTunits, 1 - GuiGetUnits($hTunits))
EndFunc   ;==>ToggleTunits



Func IpAddrChange()                            ; user updated IP address
	GUICtrlSetData($hT, "---")
	GUICtrlSetData($hSP, "---")
	UpdateOutputState(0)
	GetID()                                    ; check if VISA device responds to IP address
	If $g_bCommValid Then ConfigWrite()          ; if ok then save config
EndFunc   ;==>IpAddrChange



Func ToggleSetPointUnits()                                                    ; switch between C and F
	GuiSetUnits($hSPunits, 1 - GuiGetUnits($hSPunits))
EndFunc   ;==>ToggleSetPointUnits



Func UpdateSetPoint($nSP)                    ; update the displayed setpoint in the gui
	If Not ($nSP == "") And (Not StringInStr($nSP, $F4T_VISAERRMSG)) Then
		If Not GuiGetUnits($hSPunits) Then $nSP = __F4T_CtoF($nSP)
		$nSP = StringFormat("%.1f", $nSP)
	EndIf
	GUICtrlSetData($hSP, $nSP)
EndFunc   ;==>UpdateSetPoint



Func ChangeSetPoint()
	Local $iSP = Round(Number(GUICtrlRead($hSP)), 2)
	$iSP = InputBox("Set temperature set point", "SetPoint", $iSP, "", 200, 120)
	If ($iSP = "") Or (Not StringIsFloat($iSP) And Not StringIsInt($iSP)) Then Return
	If Not GuiGetUnits($hSPunits) Then $iSP = __F4T_FtoC($iSP)
	$iSP = StringFormat("%.1f", $iSP)
	;VisaSetParameter($VISASETPOINT & " " & $iSP, $VISASETPOINT & "?", SetPointCheck, $iSP)
	Local $aSession[$_MBsize]
	$aSession[$_MBipAddr] = GUICtrlRead($hIpAddr)
	__F4T_writeSetpoint($aSession, $iSP)
	__mbClose($aSession)
EndFunc   ;==>ChangeSetPoint


Func GetOutputState($s = "")                        ; get the current output/power state of the VISA device
	;If $s = "" Then $s = StringUpper(StringLeft(__viExecOneShot(GUICtrlRead($hIpAddr), 1, $VISAOUTPUT1 & "?"), 3))
	Return (($s = "AUT") Or ($s = "MAN") Or ($s = "ON") Or (Number($s) = 1)) + 0
EndFunc   ;==>GetOutputState



Func UpdateOutputState($sState)
	$sState = GetOutputState(StringUpper(StringLeft(StringStripWS($sState, 3), 3)))
	GUICtrlSetBkColor($hPowerBtn, $sState ? 0xFFFF00 : 0xFDFDFD)
	GUICtrlSetData($hPowerBtn, $sState ? "On" : "Off")
EndFunc   ;==>UpdateOutputState



Func GetGuiOutputState()
	Return (GUICtrlRead($hPowerBtn) = "On") + 0
EndFunc   ;==>GetGuiOutputState



Func PowerBtnClick()
	Local $bState = 1 - GetGuiOutputState()
	;Local $sState = ($bState ? "ON" : "OFF")
	;VisaSetParameter($VISAOUTPUT1 & " " & $bState, $VISAOUTPUT1 & "?", OutputPowerStateCheck, $sState)
	Local $aSession[$_MBsize]
	$aSession[$_MBipAddr] = GUICtrlRead($hIpAddr)
	__F4T_writeEnable($aSession, $bState)
	__mbClose($aSession)
	UpdateOutputState($bState)
EndFunc   ;==>PowerBtnClick



Func ScanNetwork()
	Local $aRet = __viScanSubnetFilter(__viScanSubnet("192.168.0.0"), "Chamber")
	GUICtrlSetData($hIpAddr, $aRet[0], $aRet[1])
EndFunc   ;==>ScanNetwork


