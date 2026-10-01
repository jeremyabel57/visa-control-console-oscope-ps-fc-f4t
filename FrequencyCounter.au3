; todo:
;


; next steps:
;   add prefixes to all functions and variable names so that the entire set of 4 instrument controls can be added together into one
; main program.
; - use a tab in the main window
; - see if you can have it allow the separate tabs to undock from the main window and become their own window
; - add a settings tab that will have all the paths and ip addresses in it, complete with a scan network and auto populate
; - add a dashboard tab that will have
;   . chamber temperature and setpoint and on/off button
;   . power supply voltages, on/off status (grayed out if off, colored if on), and up/down sequence buttons
;   . oscope screen capture button that will have a minature of the picture shown in the dashboard after it is captured
;
;


; goal:
; reset counter button
; capture screenshot button
; capture allan deviation
; capture center frequency
; wait for minimum 1000 samples


#AutoIt3Wrapper_Icon=fc_frequencyCounter.ico
#AutoIt3Wrapper_UseX64=Y

;#include <Visa.au3>

#include "general.au3"

Global $hIpAddr, $refreshBtn, $findBtn, $hScreenShot, $hScreenShotBrosweBtn, $hScreenShotBtn, _
		$hCaptureData, $hCaptureDataBrosweBtn, $hCaptureDataBtn, $hMainGui, $hResetStatsBtn, _
		$hMean, $hAllanDev, $hCount, $hFreq, $hMax, $hMin, $hStdDev, $hRefreshInterval, $hCountSpeed, _
		$hCountSpeedLbl, $hCaptureButton, $hCaptureCount, $hCount, $hCaptureInitCheck

#include "fc_visadll.au3"
#include "fc_config_file.au3"


ProgressOn("Frequency Counter", "Starting Frequency Counter Remote", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
ProgressSet(0, "Initializing...")



Global $g_bCommValid = 0                      ; IP address and/or communications are valid
Opt("GUIDataSeparatorChar", "|")
Global $iReadIndex = -1

; Main window
MainGuiCreate()                             ; create main gui window, but do not show it yet
ProgressSet(50, "Reading Config....")
ConfigRead()                                ; read config file and update settings
MainGuiShow()                                ; show the main gui and register event handlers

ProgressSet(75, "Initializing the Counter...")
If GUICtrlRead($hCaptureInitCheck) = $GUI_CHECKED Then __fc_Initialize()                ; reinitialize to start a new run

ProgressSet(100)
ProgressOff()



Global $g_iRunTimer
Global $fCountSpeed = 0                     ; calculated sample speed estimate
Global $g_mode = 2                          ; 0 = monitor mode,
GoToIdleMode()                              ; 1 = capture mode (wait for sample count to reach limit then pull the data)
;                                           ; 2 = idle, done with capture, waiting


; Track time for background polling (runs every 1500ms without freezing the GUI)
Global $g_iTimer = TimerInit()


While 1
	; 1. Poll the Windows Message Queue
	Local $nMsg = GUIGetMsg()

	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			CloseApp()

		Case $hIpAddr, $refreshBtn
			GetID()
			If GUICtrlRead($hCaptureInitCheck) = $GUI_CHECKED Then __fc_Initialize()                ; reinitialize to start a new run

		Case $findBtn
			ScanNetwork()

			;Case $hTrig                                        ; click on trigger text
			;	__viExecOneShot(GetIP(), 0, "*TRG", -1)

		Case $hResetStatsBtn                            ; reset stats and restart measurements
			__fc_Initialize(GetIP())

		Case $hScreenShotBrosweBtn
			ScreenShotBrowse()

		Case $hScreenShotBtn
			If Not _IsFullPathSpecified(GUICtrlRead($hScreenShot)) Then ScreenShotBrowse()
			__fc_ScreenShot()

		Case $hCaptureDataBrosweBtn
			CaptureDataBroswe()

		Case $hCaptureDataBtn
			If Not _IsFullPathSpecified(GUICtrlRead($hCaptureData)) Then CaptureDataBroswe()
			__fc_SaveData()

		Case $hCaptureButton                                       ; let the counter run for the required number of captures, use the fCaptureSpeed measurement to estimate time
			If $g_mode = 1 Or $g_mode = 2 Then                     ; cancelling or exiting capture mode
				GoToMonitorMode()
			Else                                                   ; entering capture mode
				GoToRunMode()
			EndIf

	EndSwitch

	Local $iRefreshInt = Int(Number(GUICtrlRead($hRefreshInterval)) * 1000)
	If $iRefreshInt = 0 Then $iRefreshInt = 10000
	Local $iTimeDiff = TimerDiff($g_iTimer)
	If $g_bCommValid <> 0 And $iTimeDiff >= $iRefreshInt Then
		$g_iTimer = TimerInit()

		If $g_mode = 1 Then        ; in capture mode, let the frequency counter measure the signal and calculate the statistics
			Local $iCountVal = __fc_ReadCount()
			If Not @error Then
				Local $iTimeDiff = TimerDiff($g_iRunTimer)
				GUICtrlSetData($hCount, $iCountVal)
				Local $iCaptureCount = Number(GUICtrlRead($hCaptureCount))
				If $iCaptureCount = 0 Then $iCaptureCount = 1000
				Local $fCurrentSpeed = 1000 * $iCountVal / $iTimeDiff                                   ; current count speed in samples per second
				Local $iSec = Int(Abs($iCaptureCount - $iCountVal) / $fCurrentSpeed + 0.5) + Number(GUICtrlRead($hRefreshInterval))
				Local $iMin = Int($iSec / 60)
				$iSec = Mod($iSec, 60)
				GUICtrlSetData($hCountSpeed, StringFormat("%02d:%02d", $iMin, $iSec))
				If $iCountVal >= $iCaptureCount Then
					;ConsoleWrite("received enough data..." & @CRLF)
					__fc_ScreenShot(0)                            ; save screenshot
					;ConsoleWrite("Screen shot saved" & @CRLF)
					Local $iErrScreen = @error
					ReadStats()                                    ; read statistics
					;ConsoleWrite("Grabbed latest readings" & @CRLF)
					__fc_SaveData(0)                            ; save to data file
					;ConsoleWrite("Saved to log file" & @CRLF)
					Local $iErrData = @error
					GoToIdleMode()
					Local $sDataFile = GUICtrlRead($hCaptureData)
					Local $sScreenFile = GUICtrlRead($hScreenShot)
					Local $s = ($iErrScreen ? "ERROR saving screenshot" : "Screen shot saved") & " to:" & @CRLF & @CRLF & _
							$sScreenFile & @CRLF & @CRLF & _
							($iErrData ? "ERROR recording measurements" : "Measurement Statistics saved") & " to:" & @CRLF & @CRLF & _
							$sDataFile & @CRLF
					MsgBox($MB_OK, "Frequency Data Captured", $s)
				EndIf
			EndIf
		ElseIf $g_mode = 0 Then                        ; not in capture mode, in monitor mode
			ReadStats()
		EndIf
	EndIf

WEnd

CloseApp()
Exit



; ----------------------------



Func GoToIdleMode()
	$g_mode = 2                                                ; sit idle with the data on the screen
	GUICtrlSetData($hCaptureButton, "Stopped")
	GUICtrlSetBkColor($hCaptureButton, $COLOR_RED)
	GUICtrlSetColor($hCaptureButton, $COLOR_WHITE)
	GUICtrlSetData($hCountSpeedLbl, "Speed:")
EndFunc   ;==>GoToIdleMode



Func GoToMonitorMode()
	GUICtrlSetData($hCaptureButton, "Start")
	GUICtrlSetBkColor($hCaptureButton, $COLOR_GRAY)
	GUICtrlSetColor($hCaptureButton, $COLOR_BLACK)
	GUICtrlSetData($hCountSpeedLbl, "Speed:")
	$g_mode = 0
	$fCountSpeed = 0                                               ; reset speed calculation
EndFunc   ;==>GoToMonitorMode



Func GoToRunMode()
	If GUICtrlRead($hCaptureInitCheck) = $GUI_CHECKED Then __fc_Initialize()                ; reinitialize to start a new run
	GUICtrlSetData($hCaptureButton, "Running")
	GUICtrlSetBkColor($hCaptureButton, $COLOR_GREEN)
	GUICtrlSetColor($hCaptureButton, $COLOR_BLACK)
	GUICtrlSetData($hCountSpeedLbl, "ETA:")
	$g_iRunTimer = TimerInit()
	$g_mode = 1
EndFunc   ;==>GoToRunMode



Func ScreenShotBrowse()
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(GUICtrlRead($hScreenShot), $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFolder = $sDrive & $sDir
	If Not FileExists($sFolder) Then $sFolder = @ScriptDir
	If StringLeft($sFileName, 1) = "." Then $sFileName = ""
	If $sFileName = "" Then $sFileName = "FreqCount"
	;MsgBox(0, "hi", "drive=" & $sDrive & @CRLF & "dir=" & $sDir & @CRLF & "name=" & $sFileName & @CRLF & "ext=" & $sExtension & @CRLF & "folder=" & $sFolder & @CRLF)
	Local $sFile = FileSaveDialog("Screenshot Save File", $sFolder, "(*.png)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $hMainGui)
	If Not ($sFile = "") And Not @error Then GUICtrlSetData($hScreenShot, $sFile)
EndFunc   ;==>ScreenShotBrowse



Func CaptureDataBroswe()
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(GUICtrlRead($hCaptureData), $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFolder = $sDrive & $sDir
	If Not FileExists($sFolder) Then $sFolder = @ScriptDir
	If StringLeft($sFileName, 1) = "." Then $sFileName = ""
	If $sFileName = "" Then $sFileName = "FreqCount"
	Local $sFile = FileSaveDialog("Frequency Statistics Save File", $sFolder, "(*.txt)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $hMainGui)
	If Not ($sFile = "") And Not @error Then GUICtrlSetData($hCaptureData, $sFile)
EndFunc   ;==>CaptureDataBroswe




; ====================================================================================================
; Function Name:    _IsFullPathSpecified
; Description:      Evaluates if a path string contains a valid, absolute drive and folder structure.
; Parameter(s):     $sPath - The path string to evaluate.
; Return Value(s):  True  - It is a complete path (e.g., "C:\Folder\file.txt") -> Skip the dialog.
;                   False - It is a placeholder or filename only -> Show the dialog.
; ====================================================================================================
Func _IsFullPathSpecified($sPath)
	; 1. Filter out empty strings or default GUI placeholders
	If $sPath == "" Or $sPath == "..." Then Return False

	; 2. Deconstruct the path string components
	Local $sDrive, $sDir, $sName, $sExt
	_PathSplit($sPath, $sDrive, $sDir, $sName, $sExt)

	; 3. If there is a root drive (e.g., "C:") and a folder path (e.g., "\temp\"), it is an absolute path
	If $sDrive <> "" And $sDir <> "" And $sDir <> "\" Then Return True

	Return False
EndFunc   ;==>_IsFullPathSpecified




;				read the statistics from the frequency counter, resetting the data collection
Func ReadStats($ipAddr = GetIP())
	Local Const $fAlpha = 0.8            ; for weighted average of samples per second calculation
	Local $sF, $sStats, $sAllanDevVal
	Local $viSession = GetIP()
	If Not __viBegin($viSession) Then Return
	__viCmd($viSession, $FC_VI_ABORT)                                                           ; stop the current calculations so we can grab the data
	Sleep(100)

	Local $iCountVal = __viReq($viSession, $FC_VI_CALC_COUNT, 1000, $VI_NORETRY)                ; get the number of measurement samples
	If Not @error And $iCountVal > 2 Then
		$sF = __viReq($viSession, $FC_VI_READ1, 1500, $VI_NORETRY)                              ; get the most recent frequency measurement
		If @error Then $sF = ""
		$sStats = __viReq($viSession, $FC_VI_CALC_ALL, 1500, $VI_NORETRY)                       ; get the statistical calculations
		If @error Then $sStats = ""
		$sAllanDevVal = __viReq($viSession, $FC_VI_CALC_ADEV, 1000, $VI_NORETRY)                ; get the Allan Deviation
		If @error Then $sAllanDevVal = ""
		__viCmd($viSession, $FC_VI_INIT, $VI_NORETRY)                                           ; set the counter to taking new measurements
		$g_iTimer = TimerInit()

		Local $fCurrentSpeed = 1000 * $iCountVal / $iTimeDiff                                   ; current count speed in samples per second
		If $fCountSpeed = 0 Then                                                                ; calculate a weighted average sample speed
			$fCountSpeed = $fCurrentSpeed
		Else
			$fCountSpeed = $fCurrentSpeed * $fAlpha + $fCountSpeed * (1 - $fAlpha)
		EndIf

		If $sF <> "" Then _
				GUICtrlSetData($hFreq, Number(StringMid($sF, StringInStr($sF, "+")), $NUMBER_DOUBLE))
		If $sStats <> "" Then
			Local $aTokens = StringSplit($sStats, ",")
			If $aTokens[0] >= 4 Then
				GUICtrlSetData($hMean, Number($aTokens[1], $NUMBER_DOUBLE))
				GUICtrlSetData($hStdDev, Number($aTokens[2], $NUMBER_DOUBLE))
				GUICtrlSetData($hMin, Number($aTokens[3], $NUMBER_DOUBLE))
				GUICtrlSetData($hMax, Number($aTokens[4], $NUMBER_DOUBLE))
			EndIf
		EndIf
		If $sAllanDevVal <> "" Then _
				GUICtrlSetData($hAllanDev, Number($sAllanDevVal, $NUMBER_DOUBLE))               ; Displays live moving Allan Dev
		GUICtrlSetData($hCount, Number($iCountVal))                                             ; Displays live moving sample count
		GUICtrlSetData($hCountSpeed, StringFormat("%.1f", Number($fCountSpeed)))                ; Display calculated samples per second data collection
	EndIf

	__viEnd($viSession)
EndFunc   ;==>ReadStats



; ---------------------------- Main window functions



Func MainGuiCreate()

	Local Const $w1 = 120
	Global Const $V_WIDTH = $w1 + $w1 + 150
	Global Const $V_HEIGHT = 335
	$CANVAS_W = $V_WIDTH - 20
	$CANVAS_H = $V_HEIGHT - 20


	Global $hMainGui = GUICreate("Frequency Counter", $V_WIDTH, $V_HEIGHT, -1, -1, _
			BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX))

	Local $sTip
	Local $x = 10
	Local $y = 5

	Local $hAddrLbl = GUICtrlCreateLabel("IP Address:", 10, $y + 3, 55, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hIpAddr = GUICtrlCreateCombo("", 65, $y, 105, 22)
	GUICtrlSetData($hIpAddr, "|192.168.0.17", "192.168.0.17")
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $findBtn = GUICtrlCreateButton($ICON_GLASS, 170, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 14)
	GUICtrlSetTip(-1, "Scan subnet 192.168.0.0 for possible VISA devices")

	$y = $y + 25
	Global $hDevIDlbl = GUICtrlCreateLabel("Device:", 10, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hDevID = GUICtrlCreateInput("", 50, $y, $w1 + $w1 + 65, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $refreshBtn = GUICtrlCreateButton($ICON_REFRESH, 115 + $w1 + $w1, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, "Reconnect to Frequency Counter")
	GUICtrlSetFont(-1, 17, 600)

	; Frequency			Trig
	; Mean				Max
	; StdDev			Min
	; Count				Allan Deviation

	; reset counter button
	; capture screenshot button
	; capture data button
	; wait for minimum 1000 samples, then capture checkbox

	$y = $y + 35

	Local $hFrequencyLbl = GUICtrlCreateLabel("Frequency Monitor", 10, $y + 1, $w1 + $w1 + 60, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 11, 600)

	Global $hResetStatsBtn = GUICtrlCreateButton("Initialize", $w1 + $w1 + 80, $y - 3, 60, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)



	$y = $y + 25
	Local $hFlbl = GUICtrlCreateLabel("Freq:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "The current frequency measurement"
	GUICtrlSetTip(-1, $sTip)
	Global $hFreq = GUICtrlCreateInput("---", 50, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	Global $hFreqUnits = GUICtrlCreateLabel("Hz", $w1 + 50, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)

	;Global $hTrig = GUICtrlCreateLabel("     ", $w1 + 80, $y + 3, $w1 + 60, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))
	;GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$y = $y + 25
	Local $hMeanLbl = GUICtrlCreateLabel("Mean:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hMean = GUICtrlCreateInput("---", 50, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hMeanUnits = GUICtrlCreateLabel("Hz", $w1 + 50, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $hMaxLbl = GUICtrlCreateLabel("Max:", $w1 + 80, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hMax = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hMaxUnits = GUICtrlCreateLabel("Hz", $w1 + $w1 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$y = $y + 25
	Local $hStdDevLbl = GUICtrlCreateLabel("StdDev:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hStdDev = GUICtrlCreateInput("---", 50, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hStdDevUnits = GUICtrlCreateLabel("Hz", $w1 + 50, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $hMinLbl = GUICtrlCreateLabel("Min:", $w1 + 80, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hMin = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hMinUnits = GUICtrlCreateLabel("Hz", $w1 + $w1 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$y = $y + 25
	Local $hCountLbl = GUICtrlCreateLabel("Count:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "Number of measurement samples collected"
	GUICtrlSetTip(-1, $sTip)
	Global $hCount = GUICtrlCreateInput("---", 50, $y, $w1 - 40, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	Local $hAllanDevLbl = GUICtrlCreateLabel("Allan Dev:", $w1 + 60, $y + 3, 60, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hAllanDev = GUICtrlCreateInput("---", $w1 + 120, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hAllanDevUnits = GUICtrlCreateLabel("Hz", $w1 + $w1 + 120, $y + 3, 20, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$y = $y + 25
	Global $hCountSpeedLbl = GUICtrlCreateLabel("Speed:", 10, $y + 3, 40, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "Estimated Samples per Second being captured"
	GUICtrlSetTip(-1, $sTip)
	Global $hCountSpeed = GUICtrlCreateInput("---", 50, $y, $w1 - 40, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY, $WS_TABSTOP, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	Local $hRefreshIntervalLbl = GUICtrlCreateLabel("Refresh Interval:", $w1 + 20, $y + 3, 100, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$sTip = "Seconds between data captures" & @CRLF & "Each data capture resets the statistics."
	GUICtrlSetTip(-1, $sTip)
	Global $hRefreshInterval = GUICtrlCreateInput("2", $w1 + 120, $y, 60, 20, BitOR($GUI_SS_DEFAULT_INPUT, $ES_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)
	Local $hRefreshIntervalLbl2 = GUICtrlCreateLabel("seconds", $w1 + 183, $y + 3, 40, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetTip(-1, $sTip)

	$y = $y + 35
	Local $hCaptureLbl = GUICtrlCreateLabel("Capture", 10, $y + 1, 70, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 11, 600)
	Local $hCaptureLbl2 = GUICtrlCreateLabel("Verify signal above, then click Start to measure.", 80, $y + 3, $w1 + $w1 + 60, 17)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, -1, 600)
	GUICtrlSetColor(-1, 0xFF0000)

	$y = $y + 25
	Local $hScreenShotLbl = GUICtrlCreateLabel("Screen:", 10, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hScreenShot = GUICtrlCreateInput("...", 60, $y, $w1 + $w1 + 30, 20, BitOR($GUI_SS_DEFAULT_INPUT, $GUI_SS_DEFAULT_INPUT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hScreenShotBrosweBtn = GUICtrlCreateButton("...", $w1 + $w1 + 90, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hScreenShotBtn = GUICtrlCreateButton($ICON_SCREENSHOT, $w1 + $w1 + 115, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 16)

	$y = $y + 25
	Local $hCaptureDataLbl = GUICtrlCreateLabel("Data:", 10, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hCaptureData = GUICtrlCreateInput("...", 60, $y, $w1 + $w1 + 30, 20, BitOR($GUI_SS_DEFAULT_INPUT, $GUI_SS_DEFAULT_INPUT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hCaptureDataBrosweBtn = GUICtrlCreateButton("...", $w1 + $w1 + 90, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hCaptureDataBtn = GUICtrlCreateButton($ICON_SCREENSHOT, $w1 + $w1 + 115, $y - 3, 25, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	GUICtrlSetFont(-1, 16)

	$y = $y + 25
	Local $hCaptureCountLbl = GUICtrlCreateLabel("Count >=", 10, $y + 3, 50, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hCaptureCount = GUICtrlCreateInput("1000", 60, $y, $w1, 20, BitOR($GUI_SS_DEFAULT_INPUT, $GUI_SS_DEFAULT_INPUT))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hCaptureButton = GUICtrlCreateButton("Run", $w1 + 65, $y - 3, 70, 25)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Global $hCaptureInitCheck = GUICtrlCreateCheckbox("Initialize", $w1 + 138, $y, 70, 20)
	GUICtrlSetState(-1, 0)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

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






