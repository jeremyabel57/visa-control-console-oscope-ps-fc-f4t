#include-once


; goal:
; reset counter button
; capture screenshot button
; capture allan deviation
; capture center frequency
; wait for minimum 1000 samples






#include <Math.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>

#include <GDIPlus.au3>
#include <GDIPlusConstants.au3>
#include <StaticConstants.au3>

#include "myconstants.au3"
#include "filemisc.au3"
#include "visascpi.au3"
#include "winmgmt.au3"



; visa commands for Frequency counter
Global Const $FC_VI_INIT = ":INITiate:IMMediate"                            ; start the measurements/data collection
Global Const $FC_VI_RESET = "*RST"                                          ; reset settings
Global Const $FC_VI_CLS = "*CLS"                                            ; clear current measurements
Global Const $FC_VI_ABORT = ":ABORt"                                        ; abort current measurement/data collection
Global Const $FC_VI_CALC_CLEAR = ":CALCulate:AVERage:CLEar"                 ; clear measurement statistics and restart from sample #1
Global Const $FC_VI_CALC_COUNT = ":CALCulate:AVERage:COUNt:CURRent?"        ; get the current sample count
Global Const $FC_VI_CALC_ADEV = ":CALCulate:AVERage:ADEViation?"            ; get the current Allan Deviation value
Global Const $FC_VI_CALC_ALL = ":CALCulate:AVERage:ALL?"                    ; get the current measurement stats: mean, stddev, min, max
Global Const $FC_VI_READ1 = ":DATA:LAST?"                                   ; get the last frequency reading
Global Const $FC_VI_COUNT = ":DATA:POINts?"                                 ; get the current number of samples measured



Global $g_fc_iReadTimer, $g_fc_iRefreshInterval = 100                       ; loop timer


; GUI elements
Global $g_fc_hIpAddr, $g_fc_cScreenShot, $g_hMainGui, $g_fc_hDevID, $g_fc_hScreen, $g_fc_cCaptureButton, _
		$g_fc_cMean, $g_fc_cAllanDev, $g_fc_cCount, $g_fc_cFreq, $g_fc_cMax, $g_fc_cMin, $g_fc_cStdDev, $g_fc_cCount, _
		$g_fc_cRefreshInterval, $g_fc_cCountSpeed, $g_fc_cCountSpeedLbl, $g_fc_cCaptureCount, $g_fc_cCaptureInitCheck, _
		$g_fc_cPPM, $g_fc_iScreen = -1           ;, $g_fc_cCaptureData

Global $g_fc_bCommValid = False                                                                             ; IP address and/or communications are valid
Global $g_fc_iRunTimer, $g_fc_fCountSpeed, $g_fc_mode, $g_fc_iTimer, $g_hTabFC, $g_fc_iTabIdx, _
		$g_fc_bPicData, $g_fc_bPicDownloading = False, $g_fc_iScreen = -1


Global $g_fc_fbfreq, $g_fc_fbmean, $g_fc_fbmax, $g_fc_fbmin, $g_fc_fbsdev, $g_fc_fbcount, $g_fc_fbadev      ; mailboxes for receiving data
Global $g_fc_oDev, $g_fc_fbstats



;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
;---------------------------------------------------------------------------
; initialization functions


; called after gui window is shown during init/setup
Func fcTab_init()
	$g_fc_fCountSpeed = 0                                                                   ; calculated sample speed estimate
	$g_fc_mode = 2                                                                          ; 0 = monitor mode,
	fcTab_GoToIdleMode()                                                                    ; 1 = capture mode (wait for sample count to reach limit then pull the data)
	;                                           											; 2 = idle, done with capture, waiting
	$g_fc_iTimer = TimerInit()                                                              ; Track time for background polling (runs every 1500ms without freezing the GUI)
	$g_fc_oDev = fcTab_GetIP()
	$g_fc_iReadTimer = TimerInit()
	LoopRegister("fcTab_Loop")
EndFunc   ;==>fcTab_init





; called during the Tab control section of main gui window setup
Func fcTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	$g_fc_iTabIdx = $iTabIdx                                            ; save for later to determine if we are the selected tab

	Local $g_fc_cAllanDevUnits, $g_fc_cFreqUnits, $g_fc_cMaxUnits, $g_fc_cMinUnits, $g_fc_cMeanUnits, $g_fc_cPPMUnits, $g_fc_cStdDevUnits

	Local $w1 = 120
	Local $w2 = $w1 + $w1
	Local $sTip
	Local $x = 10
	Local $y = 5
	Local $x2

	GUICtrlCreateLabel("IP Address:", $x, $y + 3, 65, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_hIpAddr = GUICtrlCreateCombo("", $x + 65, $y, $w1 + 95, 22)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "fcTab_OnIpAddrOrRefresh")
	GUICtrlSetData(-1, "|192.168.0.17", "192.168.0.17")
	GUICtrlCreateButton($ICON_SEARCH, $x + $w1 + 160, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 20, 600)
	GUICtrlSetTip(-1, "Scan subnet 192.168.0.0 for possible VISA devices")
	GUICtrlSetOnEvent(-1, "fcTab_ScanNetwork")

	$x2 = $x + 135 + $w2
	GUICtrlCreateLabel("Device:", $x2, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_hDevID = GUICtrlCreateInput("", $x2 + 40, $y, $w2 + 65, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateButton($ICON_REFRESH, $x2 + 105 + $w2, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Reconnect to Frequency Counter")
	GUICtrlSetFont(-1, 17, 600)
	GUICtrlSetOnEvent(-1, "fcTab_OnIpAddrOrRefresh")
	$y = $y + 35

	; Frequency
	; Mean				Max
	; StdDev			Min
	; Count				Allan Deviation

	; reset counter button
	; capture screenshot button
	; capture data button
	; wait for minimum 1000 samples, then capture checkbox

	GUICtrlCreateLabel("Frequency Monitor", 10, $y + 1, $w2 + 60, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 11, 600)
	GUICtrlCreateButton("Configure FC", $w2 + 30, $y - 3, 80, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "fcTab_OnResetStats")
	GUICtrlSetTip(-1, "Reset the Frequency Counter and configure for measuring Allan Deviation")
	GUICtrlCreateButton($ICON_SCREENSHOT, $w1 + $w1 + 115, $y - 3, 25, 25, BitOR($GUI_SS_DEFAULT_BUTTON, $BS_CENTER, $SS_CENTERIMAGE))
	GUICtrlSetFont(-1, 16)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "fcTab_PicRefresh")
	$y = $y + 25

	GUICtrlCreateLabel("Freq:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "The current frequency measurement"
	GUICtrlSetTip(-1, $sTip)
	$g_fc_cFreq = GUICtrlCreateInput("---", 50, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	$g_fc_cFreqUnits = GUICtrlCreateLabel("Hz", $w1 + 50, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	GUICtrlCreateLabel("PPM:", $w1 + 80, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cPPM = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cPPMUnits = GUICtrlCreateLabel("Hz", $w2 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y = $y + 25

	GUICtrlCreateLabel("Mean:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cMean = GUICtrlCreateInput("---", 50, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cMeanUnits = GUICtrlCreateLabel("Hz", $w1 + 50, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Max:", $w1 + 80, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cMax = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cMaxUnits = GUICtrlCreateLabel("Hz", $w2 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y = $y + 25

	GUICtrlCreateLabel("StdDev:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cStdDev = GUICtrlCreateInput("---", 50, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cStdDevUnits = GUICtrlCreateLabel("Hz", $w1 + 50, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateLabel("Min:", $w1 + 80, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cMin = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cMinUnits = GUICtrlCreateLabel("Hz", $w2 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y = $y + 25

	GUICtrlCreateLabel("Count:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "Number of measurement samples collected"
	GUICtrlSetTip(-1, $sTip)
	$g_fc_cCount = GUICtrlCreateInput("---", 50, $y, $w1 - 40, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	GUICtrlCreateLabel("Allan Dev:", $w1 + 60, $y + 3, 60, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cAllanDev = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cAllanDevUnits = GUICtrlCreateLabel("Hz", $w2 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y = $y + 25

	$g_fc_cCountSpeedLbl = GUICtrlCreateLabel("Speed:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "Estimated Samples per Second being captured"
	GUICtrlSetTip(-1, $sTip)
	$g_fc_cCountSpeed = GUICtrlCreateInput("---", 50, $y, $w1 - 40, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	GUICtrlCreateLabel("Refresh Interval:", $w1 + 20, $y + 3, 100, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "Seconds between data captures" & @CRLF & "Each data capture resets the statistics."
	GUICtrlSetTip(-1, $sTip)
	$g_fc_cRefreshInterval = GUICtrlCreateInput("2", $w1 + 120, $y, 60, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	GUICtrlCreateLabel("seconds", $w1 + 183, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	$y = $y + 35

	GUICtrlCreateLabel("Capture", 10, $y + 1, 70, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 11, 600)
	GUICtrlCreateLabel("Preview signal above, then click button to measure.", 80, $y + 3, $w2 + 60, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, -1, 600)
	GUICtrlSetColor(-1, 0xFF0000)
	$y = $y + 25

	GUICtrlCreateLabel("Screen:", 10, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cScreenShot = GUICtrlCreateInput("...", 60, $y, $w2 + 30, 20, BitOR($GUI_SS_DEFAULT_INPUT, $GUI_SS_DEFAULT_INPUT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlCreateButton("...", $w2 + 90, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "fcTab_ScreenShotBrowse")
	GUICtrlSetTip(-1, "Browse for where to save the screen shot")

	GUICtrlCreateButton($ICON_SAVE, $w2 + 115, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 16)
	GUICtrlSetOnEvent(-1, "fcTab_OnScreenShotBtn")
	GUICtrlSetTip(-1, "Save screenshot and measurement data")
	;GUICtrlSetOnEvent(-1, "fcTab_OnScreenShotBtn")
	;GUICtrlSetTip(-1, "Save the screen shot that is shown here at the right")
	$y = $y + 25

	;GUICtrlCreateLabel("Data:", 10, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;$g_fc_cCaptureData = GUICtrlCreateInput("...", 60, $y, $w2 + 30, 20, BitOR($GUI_SS_DEFAULT_INPUT, $GUI_SS_DEFAULT_INPUT))
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlCreateButton("...", $w2 + 90, $y - 3, 25, 25)
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetOnEvent(-1, "fcTab_CaptureDataBrowse")
	;GUICtrlSetTip(-1, "Browse for where to save the measurement data")

	;GUICtrlCreateButton($ICON_SAVE, $w2 + 115, $y - 3, 25, 25)
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetFont(-1, 16)
	;GUICtrlSetOnEvent(-1, "fcTab_OnCaptureDataBtn")
	;GUICtrlSetTip(-1, "Save the measurement data shown here")
	;$y = $y + 25

	GUICtrlCreateLabel("Count >=", 10, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cCaptureCount = GUICtrlCreateInput("1000", 60, $y, $w1 - 30, 20, BitOR($GUI_SS_DEFAULT_INPUT, $GUI_SS_DEFAULT_INPUT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$g_fc_cCaptureButton = GUICtrlCreateButton("Run", $w1 + 35, $y - 3, 100, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetOnEvent(-1, "fcTab_OnCaptureButton")
	GUICtrlSetTip(-1, "Rotate thru Idle, Monitor, and Capture modes")

	$g_fc_cCaptureInitCheck = GUICtrlCreateCheckbox("Initialize", $w1 + 138, $y, 70, 20)
	GUICtrlSetState(-1, 0)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlCreateButton($ICON_SAVE, $w2 + 115, $y - 3, 25, 25)
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)
	;GUICtrlSetFont(-1, 16)
	;GUICtrlSetOnEvent(-1, "fcTab_OnCaptureAll")
	;GUICtrlSetTip(-1, "Save both measurement data and screenshot")
	$y = $y + 25

	Local $issHeight = 272                          ; expected dimensions of screenshot
	Local $issWidth = 480
	$x += 135 + $w2
	Local $y2 = 30

	$g_fc_hScreen = GUICtrlGetHandle(GUICtrlCreatePic("", $x, $y2, $issWidth, $issHeight))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$y2 += $issHeight + 5
	$y = _Max($y, $y2)
	$x = $x + $issWidth + 5

	Local $a[] = [$x, $y]
	Return $a
EndFunc   ;==>fcTab_GuiCreate





; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------


; ---------------------------------------------------------------------------
; GUI Event Handler Functions

Func fcTab_OnIpAddrOrRefresh()
	fcTab_GetID()
	If $g_fc_oDev = '' Then $g_fc_oDev = fcTab_GetIP()
	__viCmd($g_fc_oDev, 'sleep 200')
	fcTab_PicRefresh()
	__viCmd($g_fc_oDev, 'sleep 500')
	If GUICtrlRead($g_fc_cCaptureInitCheck) = $GUI_CHECKED Then __fc_Initialize()
EndFunc   ;==>fcTab_OnIpAddrOrRefresh

Func fcTab_OnResetStats()
	__fc_Initialize()
	;Local $ipAddr = fcTab_GetIP()
	;__viCmd($ipAddr, 'sleep 500')
	;fcTab_PicRefresh()
EndFunc   ;==>fcTab_OnResetStats

;Func fcTab_OnCaptureDataBtn()
;	If Not __IsFullPathSpecified(GUICtrlRead($g_fc_cCaptureData)) Then fcTab_CaptureDataBrowse()
;	__fc_SaveData()
;EndFunc   ;==>fcTab_OnCaptureDataBtn

;Func fcTab_OnCaptureAll()
;	fcTab_OnCaptureDataBtn()
;	fcTab_OnScreenShotBtn()
;EndFunc   ;==>fcTab_OnCaptureAll

Func fcTab_OnCaptureButton()
	If $g_fc_mode = 1 Then          ; cancelling or exiting capture mode
		fcTab_GoToIdleMode()
	ElseIf $g_fc_mode = 2 Then      ; idle to monitor mode
		fcTab_GoToMonitorMode()
	Else                            ; monitor to capture mode
		fcTab_GoToRunMode()
	EndIf
EndFunc   ;==>fcTab_OnCaptureButton

Func fcTab_PicRefresh()             ; download latest screenshot from FC and show in the gui
	Local $aCmds = [ _
			"flush", _
			"$=" & $VI_REQ_ERR, _
			"HCOPy:SDUMp:DATA:FORMat PNG", _
			"sleep 50", _
			"$g_fc_bPicData:=HCOPy:SDUMp:DATA?"]
	__viGuiPicRefresh($g_fc_bPicDownloading, $g_fc_bPicData, fcTab_GetIP(), $aCmds)
EndFunc   ;==>fcTab_PicRefresh







; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------
; ----------------------------





Func fcTab_GoToIdleMode()
	GUICtrlSetData($g_fc_cCaptureButton, "Stopped")
	GUICtrlSetBkColor($g_fc_cCaptureButton, $COLOR_RED)
	GUICtrlSetColor($g_fc_cCaptureButton, $COLOR_WHITE)
	GUICtrlSetData($g_fc_cCountSpeedLbl, "Speed:")
	$g_fc_mode = 2                                                                                  ; sit idle with the data on the screen
EndFunc   ;==>fcTab_GoToIdleMode



Func fcTab_GoToMonitorMode()
	GUICtrlSetData($g_fc_cCaptureButton, "Previewing")
	GUICtrlSetBkColor($g_fc_cCaptureButton, $COLOR_YELLOW)
	GUICtrlSetColor($g_fc_cCaptureButton, $COLOR_BLACK)
	GUICtrlSetData($g_fc_cCountSpeedLbl, "Speed:")
	$g_fc_mode = 0
	$g_fc_fCountSpeed = -1                                                                           ; reset speed calculation
	;__viCmd($g_fc_oDev,$FC_VI_INIT)
	;$g_fc_iTimer = TimerInit()
EndFunc   ;==>fcTab_GoToMonitorMode



Func fcTab_GoToRunMode()
	If GUICtrlRead($g_fc_cCaptureInitCheck) = $GUI_CHECKED Then __fc_Initialize()                   ; reinitialize to start a new run
	GUICtrlSetData($g_fc_cCaptureButton, "Running")
	GUICtrlSetBkColor($g_fc_cCaptureButton, $COLOR_GREEN)
	GUICtrlSetColor($g_fc_cCaptureButton, $COLOR_WHITE)
	GUICtrlSetData($g_fc_cCountSpeedLbl, "ETA:")
	$g_fc_iRunTimer = TimerInit()
	$g_fc_mode = 1
	__viCmd($g_fc_oDev, "flush")
	__viCmd($g_fc_oDev, "$=" & $VI_REQ_ERR)
EndFunc   ;==>fcTab_GoToRunMode



Func fcTab_ScreenShotBrowse()
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(GUICtrlRead($g_fc_cScreenShot), $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFolder = $sDrive & $sDir
	If Not FileExists($sFolder) Then $sFolder = @ScriptDir
	If StringLeft($sFileName, 1) = "." Then $sFileName = ""
	If $sFileName = "" Then $sFileName = "FreqCount"
	Local $sFile = FileSaveDialog("Screenshot Save File", $sFolder, "(*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $g_hMainGui)
	If Not ($sFile = "") And Not @error Then GUICtrlSetData($g_fc_cScreenShot, $sFile)
EndFunc   ;==>fcTab_ScreenShotBrowse


;Func fcTab_CaptureDataBrowse()
;	Local $sDrive, $sDir, $sFileName, $sExtension
;	_PathSplit(GUICtrlRead($g_fc_cCaptureData), $sDrive, $sDir, $sFileName, $sExtension)
;	Local $sFolder = $sDrive & $sDir
;	If Not FileExists($sFolder) Then $sFolder = @ScriptDir
;	If StringLeft($sFileName, 1) = "." Then $sFileName = ""
;	If $sFileName = "" Then $sFileName = "FreqCount"
;	Local $sFile = FileSaveDialog("Frequency Statistics Save File", $sFolder, "(*.txt)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $g_hMainGui)
;	If Not ($sFile = "") And Not @error Then GUICtrlSetData($g_fc_cCaptureData, $sFile)
;EndFunc   ;==>fcTab_CaptureDataBrowse






; ---------------------------------------------------------------------------
; Background Polling Subroutines

Func fcTab_Loop()
	If TimerDiff($g_fc_iReadTimer) < $g_fc_iRefreshInterval Then Return
	$g_fc_iReadTimer = TimerInit()

	Local $iRefreshInt = Int(Number(GUICtrlRead($g_fc_cRefreshInterval)) * 1000)
	If $iRefreshInt <= 0 Then $iRefreshInt = 10000
	Local $iTimeDiff = TimerDiff($g_fc_iTimer)
	;If $g_fc_oDev = '' Then $g_fc_oDev = fcTab_GetIP()
	Local $i, $j

	__viGuiPicLoop($g_fc_bPicDownloading, $g_fc_bPicData, $g_fc_iTabIdx, $g_fc_iScreen, $g_fc_hScreen)      ; check if any screen image was downloaded for the gui

	$j = $g_fc_fbfreq
	If $j <> '' Then
		$i = StringInStr($j, " ")
		If $i Then $j = StringLeft($j, $i - 1)
		GUICtrlSetData($g_fc_cFreq, Number(StringMid($j, StringInStr($j, "+")), $NUMBER_DOUBLE))
		$g_fc_fbfreq = ''
	EndIf

	$j = $g_fc_fbstats
	If $j <> '' Then
		Local $aTokens = StringSplit($j, ",")
		If $aTokens[0] >= 4 Then
			GUICtrlSetData($g_fc_cMean, Number($aTokens[1], $NUMBER_DOUBLE))
			GUICtrlSetData($g_fc_cStdDev, Number($aTokens[2], $NUMBER_DOUBLE))
			GUICtrlSetData($g_fc_cMin, Number($aTokens[3], $NUMBER_DOUBLE))
			GUICtrlSetData($g_fc_cMax, Number($aTokens[4], $NUMBER_DOUBLE))
		EndIf
		$g_fc_fbstats = ''
	EndIf

	$j = $g_fc_fbcount
	If $j <> '' Then
		Local $fAlpha = 0.8                                                                     ; for weighted average of samples per second calculation
		$j = Int($j)
		$g_fc_iTimer = TimerInit()
		GUICtrlSetData($g_fc_cCount, $j)
		Local $fCurrentSpeed = 1000 * $j / $iTimeDiff                                           ; current count speed in samples per second
		$g_fc_fCountSpeed = Number($g_fc_fCountSpeed)
		If $g_fc_fCountSpeed = -1 Then                                                          ; calculate a weighted average sample speed
			$g_fc_fCountSpeed = 0                                                               ; toss first measurement as the time delta does not match it
		ElseIf $g_fc_fCountSpeed = 0 Then
			$g_fc_fCountSpeed = $fCurrentSpeed
		Else
			$g_fc_fCountSpeed = $fCurrentSpeed * $fAlpha + $g_fc_fCountSpeed * (1 - $fAlpha)
		EndIf
		GUICtrlSetData($g_fc_cCountSpeed, StringFormat("%.1f", Number($g_fc_fCountSpeed)))      ; Display calculated samples per second data collection
		$g_fc_fbcount = ''
	EndIf

	$j = $g_fc_fbadev
	If $j <> '' Then
		$j = Number($j, $NUMBER_DOUBLE)
		GUICtrlSetData($g_fc_cAllanDev, $j)
		GUICtrlSetData($g_fc_cPPM, $j * 1000000 / Number(GUICtrlRead($g_fc_cMean), $NUMBER_DOUBLE))
		$g_fc_fbadev = ''
	EndIf


	If Not $g_fc_bCommValid Or $iTimeDiff < $iRefreshInt Then Return

	If $g_fc_mode = 0 Then                                                                  ; in monitor mode
		If GUICtrlRead($g_cTab) = $g_fc_iTabIdx Then                                        ;   only monitor if we are the visible tab
			;fcTab_PicRefresh()
			If __viIsIdle($g_fc_oDev) Then
				Local $aCmds[] = [ _
						"$g_fc_fbcount1=" & $FC_VI_COUNT, _
						"set $g_fc_fbcount $g_fc_fbcount1", _
						"if $g_fc_fbcount1 > 2", _
						$FC_VI_ABORT, _
						"sleep 100", _
						"$g_fc_fbfreq=" & $FC_VI_READ1, _
						"$g_fc_fbstats=" & $FC_VI_CALC_ALL, _
						"$g_fc_fbadev=" & $FC_VI_CALC_ADEV, _
						$FC_VI_INIT, _
						"end", _
						"sleep " & $iRefreshInt _
						]
				__viScript($g_fc_oDev, $aCmds)
			EndIf
		EndIf

	ElseIf $g_fc_mode = 1 Then                                                              ; in capture mode, let the frequency counter measure the signal and calculate the statistics
		fcTab_Run()

	EndIf

	$g_fc_iTimer = TimerInit()
EndFunc   ;==>fcTab_Loop



Func fcTab_Run()
	Local $iCountVal = __fc_ReadCount()
	If @error Then Return

	Local $iTimeDiffRun = TimerDiff($g_fc_iRunTimer)
	GUICtrlSetData($g_fc_cCount, $iCountVal)
	Local $iCaptureCount = Number(GUICtrlRead($g_fc_cCaptureCount))
	If $iCaptureCount = 0 Then $iCaptureCount = 1000
	Local $fCurrentSpeed = 1000 * $iCountVal / $iTimeDiffRun
	Local $iSec = Int(Abs($iCaptureCount - $iCountVal) / $fCurrentSpeed + 0.5) + Number(GUICtrlRead($g_fc_cRefreshInterval))
	Local $iMin = Int($iSec / 60)
	$iSec = Mod($iSec, 60)
	GUICtrlSetData($g_fc_cCountSpeed, StringFormat("%02d:%02d", $iMin, $iSec))
	If $iCountVal < $iCaptureCount Then Return

	fcTab_PicRefresh()
	fcTab_GoToIdleMode()
EndFunc   ;==>fcTab_Run






; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; frequency counter visa functions



Func __fc_ReadCount($ipAddr = fcTab_GetIP())                                  ; get the current realtime sample count
	If $g_fc_oDev = '' Then $g_fc_oDev = $ipAddr
	Return Int(__viReqBl($g_fc_oDev, $FC_VI_COUNT))
EndFunc   ;==>__fc_ReadCount



Func __fc_Initialize($ipAddr = fcTab_GetIP())
	Local $aCmds = [ _
			$FC_VI_ABORT, _                     ; abort any prior running functions
			$VI_RST, _                          ; reset settings
			$VI_CLS, _                          ; clear status
			":CONFigure:FREQuency (@1)", _      ; Establish base frequency measurement on Ch 1
			$VI_CLS, _                          ; clear status
			":INPut1:COUPling AC", _            ; Set coupling to AC (or DC depending on source)
			":INPut1:IMPedance 50", _           ; Set input impedance to 50 Ohms (or 1M Ohms)
			":INPut1:LEVel:AUTO OFF", _         ; Turn off auto-leveling to prevent measurement hiccups
			":INPut1:LEVel 0.0", _              ; Set an absolute trigger level (e.g., 0 Volts)
			":INPut1:NREJect OFF", _            ; turn off noise reject filter
			":SENSe:FREQuency:MODE RCON", _     ; CRITICAL: Set to Raw Continuous (pi-counting) mode for Allan Deviation
			":SENSe:FREQuency:GATE:TIME 0.1", _ ; Set your gate time / Tau interval (e.g., 100 ms)
			":SAMPle:COUNt 1000000", _          ; Set total samples per trigger batch (e.g., 1000 Samples)
			":TRIGger:COUNt 1", _               ; In continuous mode, Trigger Count must be exactly 1
			":TRIGger:DELay 0", _               ; set trigger delay to 0
			":CALCulate:STATe ON", _            ; Turn on the calculation subsystem
			":CALCulate:AVERage:STATe ON", _    ; Turn on data statistics (Mean, StdDev, Min, Max, Pk-Pk)
			$FC_VI_CALC_CLEAR, _                ; clear data statistics
			$FC_VI_INIT]                        ; start data collection
	__viScript($ipAddr, $aCmds, "", 1000, 100)
EndFunc   ;==>__fc_Initialize



Func __fc_ResetStats($ipAddr = fcTab_GetIP())
	Local $aCmds = [ _
			$FC_VI_ABORT, _                     ; abort any prior running functions
			$FC_VI_CALC_CLEAR, _                ; clear data statistics
			$FC_VI_INIT]                        ; start data collection
	__viScript($ipAddr, $aCmds)
EndFunc   ;==>__fc_ResetStats



; in:		$hField = gui element to put the measurement into
;			$sReq = request visa command to get data
Func __fc_GuiRead($hField, $sReq)
	If $g_fc_oDev = '' Then $g_fc_oDev = fcTab_GetIP()
	Local $fR = __viReqBl($g_fc_oDev, $sReq)
	If @error Then Return SetError(@error, @extended, -1)
	GUICtrlSetData($hField, Number($fR, $NUMBER_DOUBLE))
EndFunc   ;==>__fc_GuiRead



Func fcTab_GetIP()
	Return __viGUIGetIP($g_fc_hIpAddr)
	;Return "raw:" & __viGUIGetIP($g_fc_hIpAddr)
EndFunc   ;==>fcTab_GetIP



Func fcTab_GetID()
	__viGUIGetIDbg($g_fc_hDevID, $g_fc_hIpAddr, $g_fc_oDev, "g_fc_bCommValid") ;, "raw:") ???
	;	;__ConsolePrintVars("__fcTab_GetID, ", "hIpAddr", GUICtrlRead($g_fc_hIpAddr), "oDev", $g_fc_oDev)
	;	Local $sId = __viGUIGetID($g_fc_hDevID, $g_fc_hIpAddr, $g_fc_oDev, "g_fc_bCommValid", "raw:")
	;	;$g_fc_bCommValid = Not ($sId = "")
	;	Return $sId
EndFunc   ;==>fcTab_GetID



Func fcTab_FellOffline()
	$g_fc_bCommValid = 0
	__viGUISetID($g_fc_hDevID, "")
EndFunc   ;==>fcTab_FellOffline



Func fcTab_ScanNetwork()
	__viScanSubnet()
	;__viScanSubnet("192.168.0.0", $g_fc_hIpAddr, "Frequency Counter")
EndFunc   ;==>fcTab_ScanNetwork



; task:		Take a screen shot of the Frequency Counter and save it to file
Func __fc_ScreenShot($UX = 1, $ipAddr = fcTab_GetIP(), $sFile = GUICtrlRead($g_fc_cScreenShot))
	GUICtrlSetData($g_fc_cScreenShot, __FileNameAutoIncrement($sFile))
	Local $aCmds[] = [ _
			"flush", _
			"HCOPy:SDUMp:DATA:FORMat PNG", _
			"##HCOPy:SDUMp:DATA?'", _
			""]
	__viScript($ipAddr, $aCmds, $sFile)
	Local $sR = __viFlush($ipAddr)
	If $sR And $UX Then MsgBox($MB_ICONINFORMATION, "Success", "Screenshot successfully saved to: " & @CRLF & $sR)
	Return $sR
EndFunc   ;==>__fc_ScreenShot



Func fcTab_OnScreenShotBtn()
	If Not __IsFullPathSpecified(GUICtrlRead($g_fc_cScreenShot)) Then fcTab_ScreenShotBrowse()

	Local $sFile = GUICtrlRead($g_fc_cScreenShot)                                                           ; grab file path/name from gui
	Local $s, $sFreqName = StringTrimRight(__NumEgr(GUICtrlRead($g_fc_cMean)), 2)
	$sFile = StringReplace($sFile, "{freq}", $sFreqName)                                                    ; replace {freq} with the average frequency reading

	Local $hFile = 0
	Local $bData = __Canvas_GetCtrlPic($g_aCanvas[$g_fc_iTabIdx], $g_fc_iScreen, $g_fc_hScreen)             ; grab the picture data from the last download
	If IsBinary($bData) Then                                                                                ; if picture found then save it to file
		$s = __FileNameAutoIncrement($sFile)
		;$s = StringReplace($s, $sFreqName, "{freq}")
		GUICtrlSetData($g_fc_cScreenShot, $s)
		$hFile = FileOpen($sFile, BitOR($FO_BINARY, $FO_OVERWRITE))
		If $hFile > 0 Then
			FileWrite($hFile, $bData)
			FileClose($hFile)
		EndIf
	Else
		fcTab_PicRefresh()                                                                                  ; if no picture found then request one from the visa device
	EndIf

	$s = __fc_SaveData(0, $sFile)                                                                           ; save measurement data to same file name but with txt extension
	Local $iErr = @error

	MsgBox(($hFile <= 0 Or $iErr) ? $MB_ICONERROR : $MB_ICONINFORMATION, "Frequency Counter", _
			"Screen shot and measurements" & @CRLF & @CRLF _
			 & (($hFile > 0) ? "Successfully saved" : "ERROR saving") & " to " & @CRLF & $sFile & @CRLF & @CRLF _
			 & (($iErr = 0) ? "Successfully saved" : "ERROR saving") & " to " & @CRLF & $s & @CRLF & @CRLF _
			, ($hFile <= 0 Or $iErr) ? 0 : 5, $g_hMainGui)

	;__fc_ScreenShot()
EndFunc   ;==>fcTab_OnScreenShotBtn



Func __fc_SaveData($UX = 1, $sFile = GUICtrlRead($g_fc_cScreenShot))
	Local $sDrive, $sDir, $sName, $sExt                                                                     ; take file name and change extension to ".txt"
	_PathSplit($sFile, $sDrive, $sDir, $sName, $sExt)
	$sFile = _PathMake($sDrive, $sDir, $sName, ".txt")
	$sFile = StringReplace($sFile, "{freq}", StringTrimRight(__NumEgr(GUICtrlRead($g_fc_cMean)), 2))        ; replace {freq} with the average frequency reading

	Local Const $sTitle = "Frequency Counter Data File"
	Local $hFile = FileOpen($sFile, 1)         ; 1=append
	If $hFile < 0 Then
		If $UX Then MsgBox($MB_ICONERROR, $sTitle, "Error opening data log file.   Error=" & @error & @CRLF & @CRLF & $sFile)
		Return SetError($hFile, 0, $sFile)
	EndIf
	FileWriteLine($hFile, "")
	Local $fMean = GUICtrlRead($g_fc_cMean), $fAdev = GUICtrlRead($g_fc_cAllanDev)
	Local $aOut = [ _
			"Frequency", GUICtrlRead($g_fc_cFreq), _
			"Mean", $fMean, _
			"StdDev", GUICtrlRead($g_fc_cStdDev), _
			"Min", GUICtrlRead($g_fc_cMin), _
			"Max", GUICtrlRead($g_fc_cMax), _
			"Allan Deviation", $fAdev, _
			"Stability (ppm)", $fAdev * 1000000 / $fMean, _
			"Sample Count", GUICtrlRead($g_fc_cCount), _
			'']
	Local $i, $n = UBound($aOut) - 2, $w
	For $i = 0 To $n Step 2
		$w = _Max($w, StringLen($aOut[$i]))
	Next
	$w += 2
	For $i = 0 To $n Step 2
		FileWriteLine($hFile, StringFormat("%" & $w & "s: %37.18f", $aOut[$i], $aOut[$i + 1]))
	Next

	FileClose($hFile)
	If $UX Then MsgBox($MB_ICONINFORMATION, $sTitle, "Current readings/statistics saved to" & @CRLF & @CRLF & $sFile, 5)
	Return $sFile
EndFunc   ;==>__fc_SaveData







; ----------------------
; ----------------------
; ----------------------
; ----------------------
; ----------------------

; config file functions

Global $fcTab_ConfigSection = "FC"
Global $g_configFile



Func fcTab_ConfigWrite()
	;__ConsolePrintVars("fcTab_ConfigWrite, ", "g_fc_hIpAddr", GUICtrlRead($g_fc_hIpAddr))
	__viSaveIP($g_fc_hIpAddr, $fcTab_ConfigSection) 																					; ip address
	__IniWriteGui($g_fc_cCaptureCount, "CountRequired", $fcTab_ConfigSection)                                                           ; autocapture sample minimum count
	__IniWriteGui($g_fc_cRefreshInterval, "RefreshInterval", $fcTab_ConfigSection)                                                      ; refresh interval
	__IniWriteGui($g_fc_cScreenShot, "ScreenShotFile", $fcTab_ConfigSection)                                                            ; screen shot file
	__IniWriteGuiCheckbox($g_fc_cCaptureInitCheck, "CaptureInitialize", $fcTab_ConfigSection)                                           ; init checkbox

	;IniWrite($g_configFile, $fcTab_ConfigSection, "CountRequired", GUICtrlRead($g_fc_cCaptureCount))                                    ; autocapture sample minimum count
	;IniWrite($g_configFile, $fcTab_ConfigSection, "RefreshInterval", GUICtrlRead($g_fc_cRefreshInterval))                               ; refresh interval
	;IniWrite($g_configFile, $fcTab_ConfigSection, "ScreenShotFile", GUICtrlRead($g_fc_cScreenShot))                                     ; screen shot file
	;IniWrite($g_configFile, $fcTab_ConfigSection, "CaptureDataFile", GUICtrlRead($g_fc_cCaptureData))                                   ; data shot file
EndFunc   ;==>fcTab_ConfigWrite



Func fcTab_ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return
	__viLoadIP($g_fc_hIpAddr, $fcTab_ConfigSection) 																					; ip address
	__IniReadGui($g_fc_cCaptureCount, "CountRequired", $fcTab_ConfigSection)                                                            ; autocapture sample minimum count
	__IniReadGui($g_fc_cRefreshInterval, "RefreshInterval", $fcTab_ConfigSection)                                                       ; refresh interval
	__IniReadGui($g_fc_cScreenShot, "ScreenShotFile", $fcTab_ConfigSection)                                                             ; screen shot file
	__IniReadGuiCheckbox($g_fc_cCaptureInitCheck, "CaptureInitialize", $fcTab_ConfigSection)                                            ; init checkbox

	;GUICtrlSetData($g_fc_cCaptureCount, IniRead($g_configFile, $fcTab_ConfigSection, "CountRequired", GUICtrlRead($g_fc_cCaptureCount)))            ; autocapture sample minimum count
	;GUICtrlSetData($g_fc_cRefreshInterval, IniRead($g_configFile, $fcTab_ConfigSection, "RefreshInterval", GUICtrlRead($g_fc_cRefreshInterval)))    ; refresh interval
	;GUICtrlSetData($g_fc_cScreenShot, IniRead($g_configFile, $fcTab_ConfigSection, "ScreenShotFile", GUICtrlRead($g_fc_cScreenShot)))               ; screen shot file
	;GUICtrlSetData($g_fc_cCaptureData, IniRead($g_configFile, $fcTab_ConfigSection, "CaptureDataFile", GUICtrlRead($g_fc_cCaptureData)))            ; data shot file

	fcTab_OnIpAddrOrRefresh()
EndFunc   ;==>fcTab_ConfigRead




