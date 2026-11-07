#include-once

; goal:
; read from test profile ini and create tab


#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>
#include <UpDownConstants.au3>
#include <Math.au3>

#include "myconstants.au3"
#include "datatypes.au3"
#include "misc.au3"
#include "filemisc.au3"
#include "visascpi.au3"
#include "winmgmt.au3"


Global $g_oCanvas                                           ; currently select tab's oCanvas
Global $g_tp_iReadTimer, $g_tp_RefreshInterval = 490        ;
Global $g_sc_oDev                                           ; oscope device for visa/scpi commands
Global $g_sTPiniFile, $g_sTestProfile



; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; initialization functions



Func tpTab_init()
	;tpTab_GuiInfoWinCreate()
	LoopRegister("tpTab_Loop")
	$g_tp_iReadTimer = TimerInit()
EndFunc   ;==>tpTab_init







; in:
;		$g_sTestProfile = which test from in the ini file
;		$g_sTPiniFile = ini file to read the test profile information from.  defaults to script file name & "_testProfiles.ini"
Func tpTab_GuiCreate($iTabIdx, $oCanvas, $hCanvas)
	If $g_sTPiniFile = "" Then $g_sTPiniFile = StringTrimRight($g_configFile, 4) & "_testProfiles.ini"
	$oCanvas.Item('tp') = ''                                                    ; mark this canvas as a Test tab

	Local $i, $n, $j, $k, $m, $a, $s, $t

	$oCanvas.Item('bSetResize') = ""                                            ; flag that we want ZoomCatalog to do the GUICtrlSetResizing(.., $GUI_DOCKALL) for us
	; ??? enable this line later to bring the infowin feature
	;$oCanvas.Item('fZoomCatalogCB') = "tpTab_GuiInfoWinCreate"                  ; callback function for when ZoomCatalog is called

	Local $x = 10, $x1, $x2, $x3, $x4, $x5, $x6, $x7, $x8, $x9
	Local $w1, $w2, $w3
	Local $y = 5, $y2, $y3, $yMax

	GUICtrlCreateLabel($g_sTestProfile, $x, $y + 3, 100, 17)                    ; Test profile name
	GUICtrlSetFont(-1, -1, 600)
	$y += 30

	; Build measurement list
	$w1 = 60                                                                    ; Measurements (Column A)
	$y2 = $y + 3
	$x1 = $x
	GUICtrlCreateLabel("S", $x1, $y2, 15, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_LEFT))                       ; column A1: select checkbox
	GUICtrlSetFont(-1, -1, 600)
	$x2 = $x1 + 15
	GUICtrlCreateLabel("Measure", $x2, $y2, $w1, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))              ; column A2: measurement name/symbol
	GUICtrlSetFont(-1, -1, 600)
	$x3 = $x2 + $w1
	GUICtrlCreateLabel("Set", $x3, $y2, 30, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))                   ; column A3: set button to set up the scope for the measurement
	GUICtrlSetFont(-1, -1, 600)
	$x4 = $x3 + 32
	GUICtrlCreateLabel("V", $x4 - 2, $y2, 15, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))                 ; column A4: checkbox to wait for technician to verify measurement
	GUICtrlSetFont(-1, -1, 600)
	$x5 = $x4 + 15
	GUICtrlCreateLabel("Get", $x5, $y2, 30, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))                   ; column A5: button to grab the measurement from the scope
	GUICtrlSetFont(-1, -1, 600)
	$x6 = $x5 + 30
	$y2 += 17 + 2

	Dim $a[0]
	$a = __IniReadArray($a, "m", $g_sTestProfile, $g_sTPiniFile)                ; read list of measurments
	$n = UBound($a)
	Local $aMeas[0][6]
	If $n > 0 Then
		ReDim $aMeas[$n][6]
		$n -= 1
		For $i = 0 To $n
			$t = __StringSplitFirst($a[$i], ",")                                ; split symbol name from string tip if there is one
			$s = StringStripWS($t[0], 3)
			$t = StringStripWS($t[1], 3)
			$aMeas[$i][0] = $s                                                  ; [0] = symbol name being measured
			$aMeas[$i][1] = GUICtrlCreateCheckbox("", $x1, $y2, 13, 20)         ; [1] = select checkbox
			GUICtrlSetState(-1, $GUI_CHECKED)
			$aMeas[$i][2] = GUICtrlCreateLabel($s, $x2 + 2, $y2 + 4, $w1 - 2, 16) ; [2] = measurement symbol name / label
			If $t <> "" Then GUICtrlSetTip(-1, $t)                              ;       tip text
			$aMeas[$i][3] = GUICtrlCreateButton("Set", $x3, $y2, 30, 20)        ; [3] = setup scope button
			GUICtrlSetOnEvent(-1, "tpTab_SetBtn")
			$aMeas[$i][4] = GUICtrlCreateCheckbox("", $x4, $y2, 13, 20)         ; [4] = validate checkbox
			GUICtrlSetState(-1, $GUI_CHECKED)
			$aMeas[$i][5] = GUICtrlCreateButton("Get", $x5, $y2, 30, 20)        ; [5] = capture measurement from scope button
			GUICtrlSetOnEvent(-1, "tpTab_GetBtn")
			$y2 += 25
		Next
	EndIf
	$yMax = $y2
	$x7 = $x6 + 30


	; build signal list
	;                                                                           ; Signals (column B)
	Local $aSigs[0][5]                                                          ; storing temporary input here, it is processed into $a array next, then back into a rebuilt $aSigs
	$aSigs = __IniReadArray($aSigs, "s", $g_sTestProfile, $g_sTPiniFile)        ; read list of signals
	$n = UBound($aSigs)
	If $n > 0 Then
		Dim $a[$n][2]
		$n -= 1
		For $i = 0 To $n                                                        ; split signal name from string tip if there is one
			$t = __StringSplitFirst($aSigs[$i], ",")                            ;
			$a[$i][0] = $t[0]
			$a[$i][1] = $t[1]
		Next
		$n += 1

		Dim $aSigs[$n * 8 + 1][5]

		$w1 = 50                                                                ; width of column B1 (column B divided into 3)
		$w2 = 50                                                                ; width of column B2
		$w3 = 70                                                                ; width of column B3
		$x8 = $x7 + $w1
		$x9 = $x8 + $w2
		Local $w1a = 30, $w2a = 40, $w3a = 50, $w4a = 40                        ; width of columns B1a, B2a, B3a, B4a (column B divided into 4)
		Local $x8a = $x7 + $w1a, $x9a = $x8a + $w2a, $x10a = $x9a + $w3a        ;
		$y2 = $y

		GUICtrlCreateLabel("Buses", $x7, $y2 + 3, $w1 + $w2 + $w3, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))  ; column B: signal names and scope channels
		GUICtrlSetFont(-1, -1, 600)
		$y2 += 25

		$aSigs[0][0] = $n                                                       ; number of signals per bus/repetition
		GUICtrlCreateLabel("Select: ", $x7, $y2 + 3, $w1a, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
		$aSigs[0][1] = GUICtrlCreateInput("1", $x8a, $y2, $w2a, 20)             ; [0][1] = (input) currently selected bus number
		GUICtrlSetOnEvent(-1, "tpTab_BusSel")
		$aSigs[0][2] = GUICtrlCreateUpdown($aSigs[0][1], $UDS_SETBUDDYINT)      ; [0][2] = (up/down) up/down control for selected bus input field
		GUICtrlSetLimit(-1, 8, 1)                                               ; set limit of 8 for max number of busses (we are using MSO58 scope with max 8 probes)

		GUICtrlCreateLabel("Count: ", $x9a, $y2 + 3, $w3a, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
		$aSigs[0][3] = GUICtrlCreateInput("1", $x10a, $y2, $w4a, 20)            ; [0][3] = (input) number of buses to use for test run
		GUICtrlSetOnEvent(-1, "tpTab_BusNsel")
		$aSigs[0][4] = GUICtrlCreateUpdown($aSigs[0][3], $UDS_SETBUDDYINT)      ; [0][4] = (up/down) up/down control for bus count input field
		GUICtrlSetLimit(-1, 8, 1)                                               ; set limit of 8 for max number of busses (we are using MSO58 scope with max 8 probes)
		$y2 += 25

		GUICtrlCreateLabel("Bus", $x7, $y2 + 3, $w1, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))      ; column B1: bus name
		GUICtrlSetFont(-1, -1, 600)
		GUICtrlCreateLabel("Signal", $x8, $y2 + 3, $w2, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))   ; column B2: signal name
		GUICtrlSetFont(-1, -1, 600)
		GUICtrlCreateLabel("Channel", $x9, $y2 + 3, $w3, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_CENTER))  ; column B3: scope channel name
		GUICtrlSetFont(-1, -1, 600)
		$y2 += 25

		$k = 1
		$n -= 1
		For $j = 0 To 7
			$m = GUICtrlCreateEdit("P" & $j, $x7, $y2, $w1, 20)                 ; bus name/number
			;$y2 += 20
			For $i = 0 To $n
				$aSigs[$k][0] = $m                                              ; [0] = bus number (edit)
				$s = $a[$i][0]
				$aSigs[$k][1] = $s                                              ; [1] = signal name (string)
				$aSigs[$k][2] = "Ch " & $m                                      ; [2] = channel to use for signal name
				$aSigs[$k][3] = GUICtrlCreateLabel($s & ": ", $x8, $y2 + 3, _   ; [3] = label in gui
						$w2, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
				$aSigs[$k][4] = GUICtrlCreateCombo("", $x9, $y2, $w3, 20)       ; [4] = dropdown box in gui
				GUICtrlSetData(-1, "|CH1|CH2|CH3|CH4|CH5|CH6|CH7|CH8" & _
						"|MATH1|MATH2|MATH3|MATH4|MATH5|MATH6|MATH7|MATH8" & _
						"|BUS1|BUS2|BUS3|BUS4|BUS5|BUS6|BUS7|BUS8" & _
						"|REF1|REF2|REF3|REF4|REF5|REF6|REF7|REF8", "Ch " & $m)
				GUICtrlSetOnEvent(-1, "tpTab_SigChSel")
				$k += 1
				$y2 += 25
			Next
		Next
	EndIf
	$yMax = _Max($yMax, $y2)


	$x1 = $x
	$y2 = $yMax + 10

	GUICtrlCreateButton($ICON_PREV, $x1, $y2, 25, 25)
	GUICtrlSetOnEvent(-1, "tpTab_PrevBtn")
	$x1 += 25
	Local $cPlay = GUICtrlCreateButton($ICON_PLAY, $x1, $y2, 25, 25, $BS_DEFPUSHBUTTON)
	GUICtrlSetOnEvent(-1, "tpTab_PlayBtn")
	$x1 += 25
	GUICtrlCreateButton($ICON_NEXT, $x1, $y2, 25, 25)
	GUICtrlSetOnEvent(-1, "tpTab_NextBtn")
	$x1 += 25
	GUICtrlCreateButton($ICON_STOP, $x1, $y2, 25, 25)
	GUICtrlSetOnEvent(-1, "tpTab_StopBtn")
	$x1 += 25

	$y3 = $y2 + 5
	GUICtrlCreateLabel("Bus:", $x1, $y3, 30, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	$x1 += 30
	Local $cBus = GUICtrlCreateLabel("1", $x1, $y3, $w2, 17)
	$x1 += $w2
	GUICtrlCreateLabel("Meas:", $x1, $y3, 35, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	$x1 += 35
	Local $cMeas = GUICtrlCreateLabel("", $x1, $y3, $w2, 17)
	$x1 += $w2
	GUICtrlCreateLabel("T:", $x1, $y3, 25, 17, BitOR($GUI_SS_DEFAULT_LABEL, $SS_RIGHT))
	$x1 += 25
	Local $cTemp = GUICtrlCreateLabel("25C", $x1, $y3, $w1, 17)
	GUICtrlSetOnEvent(-1, "tpTab_GetTemp")
	$x1 += $w1
	$y2 += 25


	Local $oMeas = ObjCreate("Scripting.Dictionary")

	$oMeas.Item('aMeas') = $aMeas
	; $aMeas[i][j]:	$i = measurement number
	;   $j:	0=string	symbol name being measured
	;		1=checkbox  checked to include in run
	;		2=label		measurement symbol name
	;		3=button  	setup the scope for the measurement
	;		4=checkbox	checked to pause inbetween setup and capture for technician to validate measurement
	;		5=button	capture measurement from scope - grab screenshot, pull measurement from badge, write measurement to spreadsheet and link to screenshot

	$oMeas.Item('aSigs') = $aSigs
	; $aSigs[i][j]: list of buses/signals
	;   [0][0] = N = (int) number of signals per bus/repition
	;	[0][1] = b = (input box) current bus being tested
	;	[0][2] = (up/down) gui control to change b (currently selected bus)
	;   [0][3] = B = (input) total number of buses to test for this run (1-8)
	;   [0][4] = (up/down) gui control to change B
	;  [i][j]: i=b*N+k.  b=bus number 0 to B-1.  k=signal index number between 1 and N (skips over header row 0)
	;   [i][0] = (edit) bus number/label
	;   [i][1] = (string) signal name
	;	[i][2] = (string) oscilloscope channel to use for this signal
	;	[i][3] = (label) gui label for this signal (this bus copy)
	;	[i][4] = (combo) drop-down selector for the oscope channel to use for this signal

	$oMeas.Item('cBus') = $cBus             ; (label) current bus being measured
	$oMeas.Item('cMeas') = $cMeas           ; (label) current measurement symbol being measured
	$oMeas.Item('iMeasSym') = 0             ; (int) index in $aMeas of current measurement
	$oMeas.Item('iMeasStep') = 0
	$oMeas.Item('cTemp') = $cTemp           ; (label) current chamber temperature
	$oMeas.Item('cPlay') = $cPlay           ; (button) play/pause button
	$oMeas.Item('bPlay') = False            ; (boolean) true = running, false = paused
	$oMeas.Item('sTP') = $g_sTestProfile    ; (string) test profile name (I2C, SPI, Flash, SMBUS, Clock, ...)

	$oCanvas.Item('oMeas') = $oMeas
; ??? canvas size being returned might not be correct.  the canvas is being sized too big
	Local $a[] = [_Max($x9 + $w3, $x1), $y2]
	Return $a
EndFunc   ;==>tpTab_GuiCreate




; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; Measurement info window
;   a picture showing the timing diagram of how to take the measurement
;   a text box below that to tell how to take the measurement



Func tpTab_GuiInfoWinCreate($oCanvas, $aCtrls)      ; $aCtrls is passed in from TabCanvasCreate, but not needed here
	Local $oMeas = $oCanvas.Item('oMeas')
	Local $sTP = $oMeas.Item('sTP')
	Local $oInfoWin = FreeCanvasCreate($sTP & " measurement", "tpTab_GuiInfoWinCreateCB", $CANVASZOOMTYPE_MIN)
	$oMeas.Item('oInfoWin') = $oInfoWin
EndFunc   ;==>tpTab_GuiInfoWinCreate


Func tpTab_GuiInfoWinCreateCB($oCanvas, $hCanvas)
	Local $iW = $oCanvas.Item('iW')
	Local $iH = $oCanvas.Item('iH')
	Local $iCH = 100
	Local $cPic = GUICtrlCreatePic("", 0, 0, $iW, $iH - $iCH)
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	Local $cTxt = GUICtrlCreateEdit("", 0, $iH - $iCH, $iW, $iCH, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $WS_VSCROLL, $ES_READONLY))
	GUICtrlSetResizing(-1, $GUI_DOCKALL)

	$oCanvas.Item('cPic') = $cPic
	$oCanvas.Item('cTxt') = $cTxt
	$oCanvas.Item('iPic') = 0       ; index of cPic within aCanvasZoom array

	If $oCanvas.Exists('bZoomNeedCataloged') Then $oCanvas.Remove('bZoomNeedCataloged')
	Local $n = 2                                                                ; 2 controls in this window
	Local $aCtrls[$n + 1][6]                                                    ;
	$aCtrls[0][0] = $hCanvas                                                    ; window handle of the canvas
	$aCtrls[0][1] = $n                                                          ; number of controls in this array
	$aCtrls[0][2] = 0
	$aCtrls[0][3] = $iW                                                         ; canvas base/original width
	$aCtrls[0][4] = $iH                                                         ; canvas base/original height

	$aCtrls[1][0] = GUICtrlGetHandle($cPic)                                     ; window handle
	$aCtrls[1][1] = 0                                                           ; X
	$aCtrls[1][2] = 0                                                           ; Y
	$aCtrls[1][3] = $iW                                                         ; W
	$aCtrls[1][4] = $iH - $iCH                                                  ; H
	$aCtrls[1][5] = 0                                                           ; picture data

	$aCtrls[2][0] = GUICtrlGetHandle($cTxt)                                     ; window handle
	$aCtrls[2][1] = 0                                                           ; X
	$aCtrls[2][2] = $iH                                                         ; Y
	$aCtrls[2][3] = $iW                                                         ; W
	$aCtrls[2][4] = $iCH                                                        ; H
	$aCtrls[2][5] = __API_ControlGetFontSize($aCtrls[2][0])                     ; font size

	$oCanvas.Item('aCanvasCtrls') = $aCtrls
	$oCanvas.Item('fzScale') = 1.0

	Local $a[] = [600, 400]
	Return $a
EndFunc   ;==>tpTab_GuiInfoWinCreateCB



; task:			update Measurement Info Window with new picture and text caption
; in:			$oCanvas = info window canvas
; 				$sFile = file name without the extension to grab the picture and text caption
Func tpTab_GuiLoadInfoWin($oCanvas, $sFile)
	Local $sPicFile = $sFile & ".png"
	Local $sTxtFile = $sFile & ".txt"
	Local $bPicData = __viParsePicture(FileRead($sPicFile, $FO_BINARY))
	Local $sTxtData = FileRead($sTxtFile)

	Local $cTxt = $oCanvas.Item('cTxt')
	GUICtrlSetData($cTxt, $sTxtData)

	Local $aCtrl = $oCanvas.Item('aCanvasCtrls')
	$aCtrl[Int($oCanvas.Item('iPic'))][5] = $bPicData
	$oCanvas.Item('aCanvasCtrls') = $aCtrl
	__WinLockRepaint($oCanvas.Item('hViewport'))
	__Canvas_AdjZoom($oCanvas)                                          ; adjust the picture to the current zoom scale and put it in the gui
	__WinUnlockRepaint($oCanvas.Item('hViewport'))
EndFunc   ;==>tpTab_GuiLoadInfoWin





; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; loop



Func tpTab_Loop()
	If TimerDiff($g_tp_iReadTimer) < $g_tp_RefreshInterval Then Return  ; only run loop every refresh interval
	$g_tp_iReadTimer = TimerInit()                                      ; Reset background clock
	If Not __IsDictionary($g_oCanvas) Then Return                       ; only run if tpTab is selected/visible
	If Not $g_oCanvas.Exists('tp') Then Return                          ;

	Local $oMeas = tpTab_oMeas()                                        ; pull data variables from oCanvas
	If @error Then Return

	If Not $oMeas.Item('bPlay') Then Return                             ; if not in run/play mode then return

	Local $aMeas = tpTab_aMeas($oMeas)                                  ;
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)                                  ;
	If @error Then Return

	Local $iBus = Int(GUICtrlRead($aSigs[0][1]))                        ;
	Local $iSym = $oMeas.Item('iMeasSym')
	Local $iStep = $oMeas.Item('iMeasStep')
	Local $nSym = UBound($aMeas) - 1
	Local $nBus = Int(GUICtrlRead($aSigs[0][3]))

	$iBus = _Min(_Max($iBus, 1), $nBus)                                 ; sanitize $iBus
	$iSym = _Min(_Max($iSym, 0), $nSym)                                 ; sanitize $iSym
	$iStep = _Min(_Max($iStep, 0), 2)                                   ; sanitize $iStep

	If $iStep = 0 Then
		tpTab_SetBtn()                                                  ; setup scope
		$iStep = _                                                      ; move to next step
				__GuiCheckBox($aMeas[$iSym][4]) ? 1 : 2
	ElseIf $iStep = 1 Then
		$iStep = 2
	ElseIf $iStep = 2 Then
		tpTab_GetBtn()                                                  ; grab measurements from scope
		$iStep = 0                                                      ; move to next step
		If $iSym < $nSym Then
			$iSym += 1
		ElseIf $iBus < $nBus Then
			$iBus += 1
			$iSym = 0
		EndIf
	EndIf
	tpTab_SetMeasI($oMeas, $iSym, $iStep, $iBus, False)                 ; update gui
	If $iStep = 1 Then                                                  ; if checkbox checked for technician to review scope measurement then
		tpTab_PlayBtn()                                                 ;   pause test flow
;??? enable these lines later and debug
;		Local $hInfoWin = $oMeas.Item('oInfoWin')                       ;   make sure measurement window is visible, it should now show the
;		GUISetState($GUI_SHOW, $hInfoWin)                               ;   timing diagram and highlighted markers for how to do the measurement
	EndIf                                                               ; end if

EndFunc   ;==>tpTab_Loop




; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------


; gui event handlers




; launch visa/scpi script to setup the scope for the measurement
Func tpTab_SetBtn()
	Local $a = tpTab_SetGetBtnFind(3)                       ; find oMeas, aMeas, index, and other info based on what Set button was pushed
	If @error Then Return
	tpTab_SetupSigs($a[5])                                  ; set internal variables with names of the signals to the scope channels chosen for the currently selected bus so later the visa script can use them
	Local $aCmds = tpTab_readScript($a[0], $a[1], $a[2])    ; read the script file for the oscope setup commands
	__viScript($g_sc_oDev, $aCmds)                          ; send commands to scope
EndFunc   ;==>tpTab_SetBtn



; launch visa/scpi script to capture the scope data
Func tpTab_GetBtn()
	Local $a = tpTab_SetGetBtnFind(5)                       ; find oMeas, aMeas, index, and other info based on what Set button was pushed
	If @error Then Return
	tpTab_SetupSigs($a[5])                                  ; set internal variables with names of the signals to the scope channels chosen for the currently selected bus so later the visa script can use them
	Local $aCmds = tpTab_readScript($a[0], $a[1], $a[2])    ; read the script file for the oscope setup commands
	__viScript($g_sc_oDev, $aCmds)                          ; send commands to scope
EndFunc   ;==>tpTab_GetBtn



; task:			read signal to scope channel selection and set up internal variables for visa scripts
Func tpTab_SetupSigs($oMeas)
	; $aSigs[i][j]: list of buses/signals
	;   [0][0] = N = (int) number of signals per bus/repition
	;	[0][1] = b = (input box) current bus being tested
	;	[0][2] = (up/down) gui control to change b (currently selected bus)
	;   [0][3] = B = (input) total number of buses to test for this run (1-8)
	;   [0][4] = (up/down) gui control to change B
	;  [i][j]: i=b*N+k.  b=bus number 0 to B-1.  k=signal index number between 1 and N (skips over header row 0)
	;   [i][0] = (edit) bus number/label
	;   [i][1] = (string) signal name
	;	[i][2] = (string) oscilloscope channel to use for this signal
	;	[i][3] = (label) gui label for this signal (this bus copy)
	;	[i][4] = (combo) drop-down selector for the oscope channel to use for this signal

	Local $aSigs = tpTab_aSigs($oMeas)
	Local $iBus = Int(GUICtrlRead($aSigs[0][1]))
	If $iBus < 1 Or 8 < $iBus Then $iBus = 1
	Local $i = $aSigs[0][0]
	Local $iStart = $iBus * $i, $iEnd = $iStart + $i - 1
	For $i = $iStart To $iEnd
		Assign($aSigs[$i][1], $aSigs[$i][2], 2)                     ; assign global variable named <signal name> to <channel/math/bus/ref> selection
	Next                                                            ; visa scripts can later use this to reference the channel when setting up the scope for the measurement

EndFunc   ;==>tpTab_SetupSigs



; task:		get visa/scpi script for Set or Get action
; in:		$sMeasSym = (string) measurement symbol name
;			$sProfile = (string) test bus/profile name (I2C, SPI, Flash, Clock...)
;			$bGet = (int) False=Set, True=Get button/action
; out:		$aCmds = array of commands read from script file
Func tpTab_readScript($sMeasSym, $sProfile, $bGet)
	Local $sLine, $aCmds[0]
	Local $sFile = _PathFull("m_" & $sProfile & "_" & $sMeasSym & ".txt")
	Local $hFile = FileOpen($sFile, 0)
	If $hFile < 0 Then Return SetError(1, 0, $aCmds)
	Local $sSearch = $bGet ? "#get" : "#set"
	Local $bInside = False
	Local $n, $i = 0
	While 1
		$sLine = StringStripWS(FileReadLine($hFile), 3)
		If @error Then ExitLoop
		If StringLower($sLine) = $sSearch Then
			$bInside = Not $bInside
			$bGet = Not $bGet
			$sSearch = $bGet ? "#get" : "#set"
			ContinueLoop
		EndIf
		If $bInside And $sLine <> "" And StringLeft($sLine, 1) <> "#" Then
			$n = $i + 1
			ReDim $aCmds[$n]
			$aCmds[$i] = $sLine
			$i = $n
		EndIf
	WEnd
	FileClose($hFile)
	Return $aCmds
EndFunc   ;==>tpTab_readScript



; task:		given the index number of the measurement item, return the following
; in:		$i = index number, $bGet is returned as [2]
; out:		[0] = (string) measurement symbol name
;			[1] = (string) test bus/profile name (I2C, SPI, Flash, Clock...)
;			[2] = (int) False=Set, True=Get button/action
;			[3] = (int) $aMeas index for this measurement row
;			[4] = (array) $aMeas
;			[5] = (dict) $oMeas
Func tpTab_SetGetI($i, $bGet = False)
	Local $oMeas = tpTab_oMeas()
	If @error Then Return SetError(@error, 0, -1)
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return SetError(@error, 0, -1)
	If UBound($aMeas, 1) <= $i Then Return SetError(1, 0, -1)
	Local $a[] = [$aMeas[$i][0], $oMeas.Item('sTP'), $bGet, $i, $aMeas, $oMeas]
	Return $a
EndFunc   ;==>tpTab_SetGetI



; task:		find which "Set" or "Get" button was pushed
; in:		$c = column number of $aMeas list to search (3=Set button, 5=Get button)
; out:		[0] = (string) measurement symbol name
;			[1] = (string) test bus/profile name (I2C, SPI, Flash, Clock...)
;			[2] = (int) False=Set, True=Get button/action
;			[3] = (int) $aMeas index for this measurement row
;			[4] = (array) $aMeas
;			[5] = (dict) $oMeas
Func tpTab_SetGetBtnFind($c = 3)
	Local $oMeas = tpTab_oMeas()
	If @error Then Return SetError(@error, 0, -1)
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return SetError(@error, 0, -1)
	; $aMeas[i][j]:	i = measurement number
	;    j:	0=string	symbol name being measured
	;		1=checkbox  checked to include in run
	;		2=label		measurement symbol name
	;		3=button  	setup the scope for the measurement
	;		4=checkbox	checked to pause inbetween setup and capture for technician to validate measurement
	;		5=button	capture measurement from scope - grab screenshot, pull measurement from badge, write measurement to spreadsheet and link to screenshot
	Local $i, $n = UBound($aMeas) - 1
	For $i = 0 To $n
		If @GUI_CtrlId = $aMeas[$i][$c] Then ExitLoop
	Next
	If $i > $n Then Return SetError(1, 0, -1)
	Local $a[] = [$aMeas[$i][0], $oMeas.Item('sTP'), $c = 5, $i, $aMeas, $oMeas]
	Return $a
EndFunc   ;==>tpTab_SetGetBtnFind



; $aSigs[i][j]: list of buses/signals
;   [0][0] = N = (int) number of signals per bus/repition
;	[0][1] = b = (input box) current bus being tested
;	[0][2] = (up/down) gui control to change b (currently selected bus)
;   [0][3] = B = (input) total number of buses to test for this run (1-8)
;   [0][4] = (up/down) gui control to change B
;  [i][j]: i=b*N+k.  b=bus number 0 to B-1.  k=signal index number between 1 and N (skips over header row 0)
;   [i][0] = (edit) bus number/label
;   [i][1] = (string) signal name
;	[i][2] = (string) oscilloscope channel to use for this signal
;	[i][3] = (label) gui label for this signal (this bus copy)
;	[i][4] = (combo) drop-down selector for the oscope channel to use for this signal
Func tpTab_BusSel()
	return
;	Local $oMeas = tpTab_oMeas()
;	If @error Then Return
;	Local $aSigs = tpTab_aSigs($oMeas)
;	If @error Then Return
;	;GUICtrlSetData($oMeas.Item('cBus'), Int(GUICtrlRead($aSigs[0][1])))     ; update status field of which bus we are currently testing
;	tpTab_StopBtn()                                                         ; reset measurement item index

EndFunc   ;==>tpTab_BusSel


Func tpTab_BusNsel()
	Local $oMeas = tpTab_oMeas()
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return
	Local $nLimit = Int(GUICtrlRead($aSigs[0][3]))
	GUICtrlSetLimit($aSigs[0][2], $nLimit, 1)
	Local $i, $n = Int($aSigs[0][0]), $j, $k, $h, $bShow
	For $j = 0 To 7
		$k = $j * $n
		$bShow = ($j < $nLimit) ? $GUI_SHOW : $GUI_HIDE
		GUICtrlSetState($aSigs[$k + 1][0], $bShow)
		For $i = 1 To $n
			$h = $k + $i
			GUICtrlSetState($aSigs[$h][3], $bShow)
			GUICtrlSetState($aSigs[$h][4], $bShow)
		Next
	Next
	If Int(GUICtrlRead($aSigs[0][1])) > $nLimit Then
		GUICtrlSetData($aSigs[0][1], $nLimit)
		;tpTab_BusSel()
	EndIf
EndFunc   ;==>tpTab_BusNsel


Func tpTab_SigChSel()
	Local $a = tpTab_ChFind()
	If @error Then Return
	Local $oMeas = $a[2]
	Local $aSigs = $a[1]
	Local $i = $a[0]
	$aSigs[$i][2] = GUICtrlRead($aSigs[$i][4])
EndFunc   ;==>tpTab_SigChSel




; task:		find index of $aSigs for the channel select drop-down item that was active
; out:		[0] = $i
;			[1] = $aSigs
;			[2] = $oMeas
Func tpTab_ChFind()
	Local $oMeas = tpTab_oMeas()
	If @error Then Return SetError(@error, 0, 0)
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return SetError(@error, 0, 0)
	Local $i, $n = UBound($aSigs)
	For $i = 1 To $n
		If @GUI_CtrlId = $aSigs[$i][4] Then ExitLoop
	Next
	If $i > $n Then Return SetError(1, 0, 0)
	Local $a[] = [$i, $aSigs, $oMeas]
	Return $a
EndFunc   ;==>tpTab_ChFind




; task:		get oMeas and aMeas of currently visible tab
; out:		-1 and error if not found
;			$oMeas
Func tpTab_oMeas($oCanvas = $g_oCanvas)
	If __IsDictionary($oCanvas) Then
		If $oCanvas.Exists('oMeas') Then
			Local $oMeas = $oCanvas.Item('oMeas')
			If __IsDictionary($oMeas) Then
				If $oMeas.Exists('sTP') Then Return $oMeas
			EndIf
		EndIf
	EndIf
	Return SetError(1, 0, -1)
EndFunc   ;==>tpTab_oMeas



; task:		get aMeas from oMeas
Func tpTab_aMeas($oMeas)
	If $oMeas.Exists('aMeas') Then
		Local $aMeas = $oMeas.Item('aMeas')
		If IsArray($aMeas) Then
			If UBound($aMeas, 0) >= 2 Then
				If UBound($aMeas, 2) >= 6 Then Return $aMeas
			EndIf
		EndIf
	EndIf
	Return SetError(1, 0, -1)
EndFunc   ;==>tpTab_aMeas



; task:		get aSigs from oMeas
Func tpTab_aSigs($oMeas)
	If $oMeas.Exists('aSigs') Then
		Local $aSigs = $oMeas.Item('aSigs')
		If IsArray($aSigs) Then
			If UBound($aSigs, 0) >= 2 Then
				If UBound($aSigs, 2) >= 5 Then Return $aSigs
			EndIf
		EndIf
	EndIf
	Return SetError(1, 0, -1)
EndFunc   ;==>tpTab_aSigs


Global $g_tc_oDev

Func tpTab_GetTemp()                                        ; update temperature display with reading from chamber
	Local $oMeas = tpTab_oMeas()
	If @error Then Return
	Local $cMeas = $oMeas.Item('cMeas')
	GUICtrlSetData($cMeas, StringFormat("%.1f C", __F4Ttemperature($g_tc_oDev)))
EndFunc   ;==>tpTab_GetTemp


Func tpTab_GetMeasI($oMeas)                                 ; get the current measurement index number
	Return Int($oMeas.Item('iMeasSym'))
EndFunc   ;==>tpTab_GetMeasI



; task:		update the gui with new measurement index and/or bus
; in:		$iSym = measurement index ($aMeas[$i]...) for the measurement currently being taken
;			$iStep = which step on the measurement 0=Set, 1=Get, anything else will not update the data, but it will clear the highlighted gui button
;			$iBus = 1-8, which bus is currently being measured.  -1 = get bus from gui.  0 = do not change selection, but clear the highlighted bus field
;			$bClear = true to clear all highlighted fields
Func tpTab_SetMeasI($oMeas, $iSym = -1, $iStep = -1, $iBus = -1, $bClear = False)        ; set the measurement index number and update the gui
	Local $cMeas = $oMeas.Item('cMeas')
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return

	$bClear = Not $bClear                                       ; clear now = true to colorize the buttons and false to skip them
	If $iSym >= 0 Then
		$oMeas.Item('iMeasSym') = $iSym
		GUICtrlSetData($cMeas, $aMeas[$iSym][0])                ; update gui with measurement symbol selected
	Else
		$iSym = $oMeas.Item('iMeasSym')
	EndIf
	If $iSym < 0 Then $iSym = 0
	If $iSym >= UBound($aMeas) Then $iSym = UBound($aMeas) - 1
	If 0 <= $iStep And $iStep <= 2 Then $oMeas.Item('iMeasStep') = $iStep
	If $iStep < 0 Then $iStep = 0
	If 2 < $iStep Then $iStep = 2
	If $iBus < 1 Then $iBus = 1
	Local $nBus = Int(GUICtrlRead($aSigs[0][3]))
	If $nBus < $iBus Then $iBus = $nBus

	; colorize the button for the item currently being measured
	Local $j, $n = UBound($aMeas) - 1
	For $j = 0 To $n
		GUICtrlSetBkColor($aMeas[$j][3], ($iSym = $j And $iStep = 0 And $bClear) ? $COLOR_YELLOW : $COLOR_GRAY2)
		GUICtrlSetBkColor($aMeas[$j][4], ($iSym = $j And $iStep = 1 And $bClear) ? $COLOR_YELLOW : $COLOR_GRAY2)
		GUICtrlSetBkColor($aMeas[$j][5], ($iSym = $j And $iStep = 2 And $bClear) ? $COLOR_YELLOW : $COLOR_GRAY2)
	Next

	; colorize the bus currently being measured
	$n = $aSigs[0][0]
	If 1 <= $iBus And $iBus <= 8 Then
		GUICtrlSetData($aSigs[0][1], $iBus)
	ElseIf $iBus < 0 Then
		$iBus = Int(GUICtrlRead($aSigs[0][1]))
	EndIf
	$iBus -= 1
	For $j = 0 To 7
		GUICtrlSetBkColor($aSigs[$j * $n + 1][0], (($j = $iBus) And $bClear) ? $COLOR_YELLOW : $COLOR_WHITE)
	Next

	; update popout info window diagram and text to match the newly selected measurement symbol
	tpTab_GuiLoadInfoWin($oMeas.Item('oInfoWin'), "m_" & $oMeas.Item('sTP') & "_" & $aMeas[$iSym][0])

EndFunc   ;==>tpTab_SetMeasI




; Data available in $oMeas
;
; $aMeas[i][j]:	i = measurement number
;    j:	0=string	symbol name being measured
;		1=checkbox  checked to include in run
;		2=label		measurement symbol name
;		3=button  	setup the scope for the measurement
;		4=checkbox	checked to pause inbetween setup and capture for technician to validate measurement
;		5=button	capture measurement from scope - grab screenshot, pull measurement from badge, write measurement to spreadsheet and link to screenshot
;
; $aSigs[i][j]: list of buses/signals
;   [0][0] = N = (int) number of signals per bus/repition
;	[0][1] = b = (input box) current bus being tested
;	[0][2] = (up/down) gui control to change b (currently selected bus)
;   [0][3] = B = (input) total number of buses to test for this run (1-8)
;   [0][4] = (up/down) gui control to change B
;  [i][j]: i=b*N+k.  b=bus number 0 to B-1.  k=signal index number between 1 and N (skips over header row 0)
;   [i][0] = (edit) bus number/label
;   [i][1] = (string) signal name
;	[i][2] = (string) oscilloscope channel to use for this signal
;	[i][3] = (label) gui label for this signal (this bus copy)
;	[i][4] = (combo) drop-down selector for the oscope channel to use for this signal
;
; $cBus = (label) = current bus being measured
; $cMeas = (label) = current measurement symbol being measured
; $iMeas = (int) = index in $aMeas of current measurement symbol being measured
; $cTemp = (label) = current chamber temperature display
; $cPlay = (button) Play/pause button
; $sTP = test plan profile name string (I2C, SPI, Flash, SMBUS, ...)

Func tpTab_PlayBtn()                ;
	Local $oMeas = tpTab_oMeas()
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return

	Local $bPlay = $oMeas.Item('bPlay')
	$bPlay = Not $bPlay
	$oMeas.Item('bPlay') = $bPlay
	GUICtrlSetData($oMeas.Item('cPlay'), $bPlay ? $ICON_PAUSE : $ICON_PLAY)
EndFunc   ;==>tpTab_PlayBtn


Func tpTab_StopBtn()                ;
	Local $oMeas = tpTab_oMeas()
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return
	tpTab_SetMeasI($oMeas, 0, 0, 1, True)                   ; reset our place back to bus 1 step 0
EndFunc   ;==>tpTab_StopBtn


Func tpTab_PrevBtn()                ;
	Local $oMeas = tpTab_oMeas()
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return

	Local $iBus = Int(GUICtrlRead($aSigs[0][1]))
	Local $iSym = $oMeas.Item('iMeasSym')
	Local $iStep = $oMeas.Item('iMeasStep')
	Local $nSym = UBound($aMeas) - 1

	If $iStep > 0 Then
		$iStep = 0
	ElseIf $iSym > 0 Then
		$iSym -= 1
	ElseIf $iBus > 1 Then
		$iBus -= 1
		$iSym = $nSym
	EndIf
	tpTab_SetMeasI($oMeas, $iSym, $iStep, $iBus, False)      ;
EndFunc   ;==>tpTab_PrevBtn


Func tpTab_NextBtn()                ;
	Local $oMeas = tpTab_oMeas()
	If @error Then Return
	Local $aSigs = tpTab_aSigs($oMeas)
	If @error Then Return
	Local $aMeas = tpTab_aMeas($oMeas)
	If @error Then Return

	Local $iBus = Int(GUICtrlRead($aSigs[0][1]))
	Local $iSym = $oMeas.Item('iMeasSym')
	Local $iStep = $oMeas.Item('iMeasStep')
	Local $nSym = UBound($aMeas) - 1
	Local $nBus = Int(GUICtrlRead($aSigs[0][3]))

	$iStep = 0
	If $iSym < $nSym Then
		$iSym += 1
	ElseIf $iBus < $nBus Then
		$iBus += 1
		$iSym = 0
	EndIf
	tpTab_SetMeasI($oMeas, $iSym, $iStep, $iBus, False)      ;
EndFunc   ;==>tpTab_NextBtn






; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------


; ip address and connection







; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; -----------------  GUI event handler functions





; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------
; ---------------------------------

; ---------------------- config file functions



Global $tpTab_ConfigSection = ""
Global $g_configFile



Func tpTab_ConfigWrite($oCanvas)
	Local $oMeas = tpTab_oMeas()
	If @error Then Return

	If Not $oMeas.Exists('sTP') Then Return
	Local $sTP = "m_" & $oMeas.Item('sTP')

	; $aMeas[i][j]:	$i = measurement number
	;   $j:	0=string	symbol name being measured
	;		1=checkbox  checked to include in run
	;		2=label		measurement symbol name
	;		3=button  	setup the scope for the measurement
	;		4=checkbox	checked to pause inbetween setup and capture for technician to validate measurement
	;		5=button	capture measurement from scope - grab screenshot, pull measurement from badge, write measurement to spreadsheet and link to screenshot
	Local $aMeas = tpTab_aMeas($oMeas)
	If Not @error Then
		Local $i, $n = UBound($aMeas, 1) - 1
		For $i = 0 To $n
			__IniWriteGuiCheckbox($aMeas[$i][1], "m" & $i & ".1", $sTP, $g_sTPiniFile)
			__IniWriteGuiCheckbox($aMeas[$i][4], "m" & $i & ".4", $sTP, $g_sTPiniFile)
		Next
	EndIf

	; $aSigs[i][j]: list of buses/signals
	;   [0][0] = N = (int) number of signals per bus/repition
	;	[0][1] = b = (input box) current bus being tested
	;	[0][2] = (up/down) gui control to change b (currently selected bus)
	;   [0][3] = B = (input) total number of buses to test for this run (1-8)
	;   [0][4] = (up/down) gui control to change B
	;  [i][j]: i=b*N+k.  b=bus number 0 to B-1.  k=signal index number between 1 and N (skips over header row 0)
	;   [i][0] = (edit) bus number/label
	;   [i][1] = (string) signal name
	;	[i][2] = (string) oscilloscope channel to use for this signal
	;	[i][3] = (label) gui label for this signal (this bus copy)
	;	[i][4] = (combo) drop-down selector for the oscope channel to use for this signal
	Local $aSigs = tpTab_aSigs($oMeas)
	If Not @error Then
		__IniWriteGui($aSigs[0][1], "busi", $sTP, $g_sTPiniFile)
		__IniWriteGui($aSigs[0][3], "busn", $sTP, $g_sTPiniFile)
		Local $i, $n = Int($aSigs[0][0]), $j, $k, $h
		For $j = 0 To 7
			$k = $j * $n
			__IniWriteGui($aSigs[$k + 1][0], "b" & $k & "name", $sTP, $g_sTPiniFile)
			For $i = 1 To $n
				$h = $k + $i
				__IniWriteGui($aSigs[$h][3], "b" & $h & "sig", $sTP, $g_sTPiniFile)
				__IniWriteGui($aSigs[$h][4], "b" & $h & "ch", $sTP, $g_sTPiniFile)
			Next
		Next
	EndIf

EndFunc   ;==>tpTab_ConfigWrite



Func tpTab_ConfigRead($oCanvas)
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return

	Local $oMeas = tpTab_oMeas($oCanvas)
	If @error Then Return
	If Not $oMeas.Exists('sTP') Then Return
	Local $sTP = "m_" & $oMeas.Item('sTP')

	; $aMeas[i][j]:	$i = measurement number
	;   $j:	0=string	symbol name being measured
	;		1=checkbox  checked to include in run
	;		2=label		measurement symbol name
	;		3=button  	setup the scope for the measurement
	;		4=checkbox	checked to pause inbetween setup and capture for technician to validate measurement
	;		5=button	capture measurement from scope - grab screenshot, pull measurement from badge, write measurement to spreadsheet and link to screenshot
	Local $aMeas = tpTab_aMeas($oMeas)
	If Not @error Then
		Local $i, $n = UBound($aMeas, 1) - 1
		For $i = 0 To $n
			__IniReadGuiCheckbox($aMeas[$i][1], "m" & $i & ".1", $sTP, $g_sTPiniFile)
			__IniReadGuiCheckbox($aMeas[$i][4], "m" & $i & ".4", $sTP, $g_sTPiniFile)
		Next
	EndIf

	; $aSigs[i][j]: list of buses/signals
	;   [0][0] = N = (int) number of signals per bus/repition
	;	[0][1] = b = (input box) current bus being tested
	;	[0][2] = (up/down) gui control to change b (currently selected bus)
	;   [0][3] = B = (input) total number of buses to test for this run (1-8)
	;   [0][4] = (up/down) gui control to change B
	;  [i][j]: i=b*N+k.  b=bus number 0 to B-1.  k=signal index number between 1 and N (skips over header row 0)
	;   [i][0] = (edit) bus number/label
	;   [i][1] = (string) signal name
	;	[i][2] = (string) oscilloscope channel to use for this signal
	;	[i][3] = (label) gui label for this signal (this bus copy)
	;	[i][4] = (combo) drop-down selector for the oscope channel to use for this signal
	Local $aSigs = tpTab_aSigs($oMeas)
	If Not @error Then
		__IniReadGui($aSigs[0][1], "busi", $sTP, $g_sTPiniFile)
		__IniReadGui($aSigs[0][3], "busn", $sTP, $g_sTPiniFile)
		Local $i, $n = Int($aSigs[0][0]), $j, $k, $h
		For $j = 0 To 7
			$k = $j * $n
			__IniReadGui($aSigs[$k + 1][0], "b" & $k & "name", $sTP, $g_sTPiniFile)
			For $i = 1 To $n
				$h = $k + $i
				__IniReadGui($aSigs[$h][3], "b" & $h & "sig", $sTP, $g_sTPiniFile)
				__IniReadGui($aSigs[$h][4], "b" & $h & "ch", $sTP, $g_sTPiniFile)
			Next
		Next
	EndIf

EndFunc   ;==>tpTab_ConfigRead








