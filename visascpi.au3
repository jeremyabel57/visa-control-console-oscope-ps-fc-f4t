#include-once


#include "visascpiQueue.au3" ; need To be included before __viScanSubnetFunFirst as it sets up required Global variables

__viScanSubnetRunFirst()      ; must run before winmgmt.  catch callbacks for parallel visa IDN scanning




Global $g_aVisaDevices = 0    ; contains 2d array list of found IP addresses, id strings, and classification type
;Local $a = [["192.168.0.14", "TCPIP0::192.168.0.14::inst0::INSTR", "TEKTRONIX,MSO58B...", "Oscilloscope"], _
;		["192.168.0.15", "TCPIP::192.168.0.15::5025::SOCKET", "Watlow Electric,F4T...", "Chamber"], _
;		["192.168.0.16", "TCPIP0::192.168.0.16::inst0::INSTR", "Agilent Tech,N6705B...", "DC Power Supply"], _
;		["192.168.0.25", "TCPIP::192.168.0.25::5025::SOCKET", "Watlow Electric,F4T...", "Chamber"]]


Global Const $WS_SYSTEMMENU = 0x00080000

#include "myconstants.au3"
#include "winmgmt.au3"
#include "filemisc.au3"


;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------


__viInit()




; ==============================================================================
; init functions that execute when this module is included


Func __viInit()
	;TCPNameToIP("127.0.0.1")                                                           ; ensure TCP has been initialized
	;If @error = 10093 Then TCPStartup()

	LoopRegister("__viLoop")                                                            ; register main loop function for visa/scpi/modbus queues
	LoopRegister("__viLoopScan")                                                        ; register main loop function for network scan
	;_GUIRegisterMsg($WM_COMMAND, "__FocusComboBox_WM_COMMAND")                          ; catch IP address selection combo boxes and keep focus on begining of text

	OnAutoItExitRegister("__viExit")                                                    ; cleanup on exit
EndFunc   ;==>__viInit

Func __viExit()                                                                         ; call this before exiting main script
	If __IsDictionary($g_oViDevs) Then
		Local $oDev, $sKey
		For $sKey In $g_oViDevs
			$oDev = $g_oViDevs.Item($sKey)
			If Not __viIsInstrument($oDev) Then ContinueLoop
			$s = Int($oDev.Item('download'))
			If __IsFileHandle($s) Then FileClose($s)
			$s = Int($oDev.Item('upload'))
			If __IsFileHandle($s) Then FileClose($s)
			__viClose($oDev)
			__viMbClose($oDev)
		Next
	EndIf
	If __viIsResourceManagerValid($__vi_hRM) Then __viCloseHandle($__vi_hRM)            ; close resource manager session
	If __IsDllHandleValid($__vi_hDll) Then DllClose($__vi_hDll)                         ; close open visa dll handle
	TCPShutdown()                                                                       ; close TCP resources
EndFunc   ;==>__viExit


; --- end of main init




;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------




;-------------------------------------------------------------------
; GUI enter/select IP address of VISA/SCPI/Modbus instrument window
;
;  __viSelectDevice($sIP, $hParent = 0, $filter = "", $subnet = "192.168.0.0")
;	  opens the dialog box for selecting the visa device
;		$sIP = initial IP address in selection combo box
;		$hParent = window handle of main gui
;		$filter = visa device type filter (sc=Oscilloscope, dc=DC Power Supply, tc=Chamber, fc=Frequency Counter)
;		$subnet = subnet IP address to scan
;  __viSelectDeviceReturn()
;	  	checks for user answering the Select Device dialog box
;		returns false if the dialog is not closed yet or already closed and return value already given
;		returns array $sIP when the box is closed.  $sIP will be blank if user canceled.
;		after a return array is given, subsequent calls will return false
;


#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <WinAPISys.au3>
#include <GuiComboBox.au3>
#include <GuiEdit.au3>

; Global tracking variables for the Asynchronous OnEvent Selector Window
Global $__viSD_hGui = 0
Global $__viSD_hIpAddr = 0
Global $__viSD_hDevID = 0
Global $__viSD_hProgress = 0
Global $__viSD_sSubnet = "192.168.0.0"
Global $__viSD_sFilter = ""
Global $__viSD_bCompleted = False
Global $__viSD_bReturned = True
Global $__viSD_hParent = 0
Global $__viSD_sResultIP = ""
Global $__viSD_sResultListRef = ""


; ====================================================================================================
; Function Name:    __viSelectDevice
; Description:      Prompts the user to select or input a target VISA instrument IP address.
;                   Utilizes a non-blocking, true OnEvent structure and is safely bound by size matrices.
; ====================================================================================================
Func __viSelectDevice($sIP, $hParent = 0, $filter = "", $subnet = "192.168.0.0")
	Local Const $DWIDTH = 400
	Local Const $DHEIGHT = 120

	; Cache working parameters into global state containers
	$__viSD_sSubnet = $subnet
	$__viSD_sFilter = $filter
	$__viSD_bCompleted = False
	$__viSD_bReturned = False
	$__viSD_sResultIP = ""
	$__viSD_hParent = $hParent

	; Create the window layout
	$__viSD_hGui = GUICreate("Select VISA device", $DWIDTH, $DHEIGHT, -1, -1, BitOR($WS_CAPTION, $WS_SYSTEMMENU, $WS_THICKFRAME, $WS_MAXIMIZEBOX), -1, $hParent)
	GUISetOnEvent($GUI_EVENT_CLOSE, "__viSD_Cancel", $__viSD_hGui)                          ; Enforce the window to handle its internal elements natively via OnEvent\

	Local $w, $y = 10
	GUICtrlCreateLabel("IP:", 10, $y + 3, 15, 17)                                           ; IP address selection combo box
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$__viSD_hIpAddr = GUICtrlCreateCombo("", 25, $y, $DWIDTH - 65, 22)
	GUICtrlSetData(-1, "|" & $__viSD_sResultListRef, $sIP)
	GUICtrlSetOnEvent(-1, "__viSD_Refresh")
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKHEIGHT))
	$__viSD_sResultListRef = __viScanPopulateComboBox($__viSD_hIpAddr, $filter)
	If StringLeft($__viSD_sResultListRef, 1) = "|" Then $__viSD_sResultListRef = StringTrimLeft($__viSD_sResultListRef, 1)
	If StringRight($__viSD_sResultListRef, 1) = "|" Then $__viSD_sResultListRef = StringTrimRight($__viSD_sResultListRef, 1)

	GUICtrlCreateButton($ICON_SEARCH, $DWIDTH - 35, $y - 3, 25, 25)                         ; Scan network button
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKWIDTH, $GUI_DOCKHEIGHT))
	GUICtrlSetTip(-1, "Scan subnet " & $subnet & " for possible VISA devices")
	GUICtrlSetFont(-1, 20, 600)
	GUICtrlSetOnEvent(-1, "__viSD_Scan")

	$y += 30
	GUICtrlCreateLabel("ID:", 10, $y + 3, 15, 17)                                           ; Show ID of device at selected IP address
	GUICtrlSetResizing(-1, $GUI_DOCKALL)
	$__viSD_hDevID = GUICtrlCreateInput("", 25, $y, $DWIDTH - 65, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKHEIGHT))
	GUICtrlCreateButton($ICON_REFRESH, $DWIDTH - 35, $y - 3, 25, 25)                        ; Refresh ID string from device at selected IP address
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKWIDTH, $GUI_DOCKHEIGHT))
	GUICtrlSetTip(-1, "Read device ID to verify connection")
	GUICtrlSetFont(-1, 20, 600)
	GUICtrlSetOnEvent(-1, "__viSD_Refresh")

	$y += 30
	$__viSD_hProgress = GUICtrlCreateProgress(10, $y, $DWIDTH - 22, 14)                     ; Progress bar for network scan
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKHEIGHT))
	GUICtrlSetData(-1, 0)

	$y += 20
	$w = Int(($DWIDTH / 2 - 40))
	GUICtrlCreateButton("Cancel", 25, $y, $w, 25)                                           ; Cancel
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKLEFT, $GUI_DOCKTOP, $GUI_DOCKHEIGHT))
	GUICtrlSetOnEvent(-1, "__viSD_Cancel")
	GUICtrlCreateButton("OK", $DWIDTH - 50 - $w, $y, $w, 25)                                ; OK button to select IP address
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKTOP, $GUI_DOCKHEIGHT))
	GUICtrlSetOnEvent(-1, "__viSD_OK")

	GUISetState(@SW_SHOW, $__viSD_hGui)
	__viSD_Refresh()                        ; Initial active verification check

	If $hParent Then GUISwitch($hParent)
EndFunc   ;==>__viSelectDevice



; task:		scan the subnet from the SelectDevice dialog asynchronously
Func __viSD_Scan()
	__viScanSetProgress(10)
	__viScanSubnet($__viSD_sSubnet, $__viSD_hIpAddr, $__viSD_sFilter)
	_WinAPI_UpdateWindow($__viSD_hGui)
	$__viSD_sResultListRef = _GUICtrlComboBox_GetList($__viSD_hIpAddr)
	__viSD_Refresh()
EndFunc   ;==>__viSD_Scan



; task:		query visa device for its id asynchronously without blocking master windows
Func __viSD_Refresh()
	Local $sIP = StringStripWS(__viGUIGetIP($__viSD_hIpAddr), 3)
	If $sIP == "" Or $sIP == "0.0.0.0" Then Return

	GUICtrlSetData($__viSD_hDevID, "Checking...")
	_WinAPI_UpdateWindow($__viSD_hGui)

	Local $sId = StringReplace(__viGetID($sIP, 1500), '"', "")
	GUICtrlSetData($__viSD_hDevID, $sId)
	_GUICtrlEdit_SetSel($__viSD_hDevID, 0, 0)
	_WinAPI_UpdateWindow($__viSD_hGui)
EndFunc   ;==>__viSD_Refresh



Func __viSD_OK()
	$__viSD_sResultIP = GUICtrlRead($__viSD_hIpAddr)
	$__viSD_sResultListRef = _GUICtrlComboBox_GetList($__viSD_hIpAddr)
	__viSD_Cleanup()

	Local $s = __viTrimIP($__viSD_sResultIP)
	Local $i, $n = UBound($g_aVisaDevices) - 1
	For $i = 0 To $n
		If $g_aVisaDevices[$i][0] = $s Then ExitLoop
	Next
	If $i <= $n Then
		If $g_aVisaDevices[$i][0] <> $s Then
			$i = $n + 1
			ReDim $g_aVisaDevices[$i + 1]
			$g_aVisaDevices[$i][0] = $s
			Local $oDev = $s
			$g_aVisaDevices[$i][2] = __viGetID($oDev)
			If __viIsInstrument($oDev) Then
				$g_aVisaDevices[$i][1] = $oDev.Item['sAddr']
				$g_aVisaDevices[$i][3] = __viClassifyItem($g_aVisaDevices[$i][2])
			EndIf
		EndIf
	EndIf
EndFunc   ;==>__viSD_OK

Func __viSD_Cancel()
	$__viSD_sResultIP = ""
	__viSD_Cleanup()
EndFunc   ;==>__viSD_Cancel

Func __viSD_Cleanup()
	GUISetState(@SW_HIDE, $__viSD_hGui)
	GUIDelete($__viSD_hGui)
	$__viSD_hProgress = 0
	$__viSD_bCompleted = True
	If $__viSD_hParent Then WinActivate($__viSD_hParent)
EndFunc   ;==>__viSD_Cleanup




;		returns 0 if dialog box not opened or return value already picked up from this function
;		returns 1 if dialog box still open
;		returns "" if user clicked cancel
;		returns IP string if user clicked ok
Func __viSelectDeviceReturn()                           ; checks for device selection dialog to be closed and returns the results.
	If $__viSD_bReturned Then Return 0                  ; if client already picked up the return value then return 0 (idle)
	If Not $__viSD_bCompleted Then Return 1             ; if dialog box still open then return 1
	$__viSD_bReturned = True                            ; set flag so next call to this function returns 0
	Return $__viSD_sResultIP                            ; return the IP selected (or empty if user clicked cancel)
EndFunc   ;==>__viSelectDeviceReturn






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------





; ---------------------------------------
; Scan network for VISA devices functions





;			__viScanSubnetRunFirst
; task:		This must be called at the beining of the main script.  It allows for parallel visa scanning by
;			calling the script and running just the getID function
Func __viScanSubnetRunFirst()
	If $CmdLine[0] >= 2 Then
		If $CmdLine[1] = ":getidn:" Then

			$g_viPrintQueuePop = 0                                              ; turn off all debug outputs on the console so we can send our scan results
			$g_viPrintQueuePush = 0
			$g_viPrintpQue = 0
			$g_viPrintpQueCond = 0
			$g_viPrintCmds = 0
			$g_viPrintReadBuf = 0
			$g_viPrintCondCmds = 0
			$g_viPrintLoopRead = 0
			$g_viPrintReplies = 0
			$g_mbPrint = 0
			$g_mbPrintDecode = 0
			$g_mbPrintDecodeString = 0
			$g_F4T_PrintResolv = 0

			Local $aResult = __viScanID(StringRegExpReplace($CmdLine[2], '^[\x22\x27]|[\x22\x27]$', ''))
			ConsoleWrite($aResult[0] & @CRLF & $aResult[1] & @CRLF)             ; this is likely the only NON-DEBUG ConsoleWrite statement
			Exit
		EndIf
	EndIf
EndFunc   ;==>__viScanSubnetRunFirst



Func __viScanSetProgress($iProgress)
	If $__viSD_hProgress <> 0 Then
		GUICtrlSetData($__viSD_hProgress, $iProgress)
	Else
		If $iProgress <= 0 Then __WinTitleNote("")
		If 0 < $iProgress And $iProgress < 100 Then __WinTitleNote("Subnet Search " & $iProgress & "%", 10000)
		If 100 <= $iProgress Then __WinTitleNote("Subnet Search Complete", 3000)
	EndIf
EndFunc   ;==>__viScanSetProgress






Global $g_tc_hIpAddr, $g_dc_hIpAddr, $g_fc_hIpAddr, $g_sc_hIpAddr, $g_dg_hIpAddr        ; all the ip address selection combo boxes





;			__viScanSubnet
; task:		scan a subnet and return a list of found VISA instruments/devices
; in:		subnet IP address - default 192.168.0.0/24
;			optionally the combobox handle to populate with filtered results
;			optionally the filter for the results going to the combobox
; out:		it only scans the 255 IP addresses of the last number in the IP address
;			2d array of items, one row for each found VISA device
;				column 0 = IP address
;				column 1 = full IP address string in the form [raw:]IP:port, to include protocol mode and port number
;				column 2 = IDN response string
;				column 3 = device type initials (sc, tc, dc, fc)
;				column 4 = classification of device type (sc=Oscilloscope, tc=Chamber, dc=DC Power Supply, fc=Frequency Counter)
Func __viScanSubnet($sSubnet = "192.168.0.0", $cIpAddr = 0, $sFilter = '')
	__viScanSubnetBg($sSubnet)
EndFunc   ;==>__viScanSubnet

Func __viScanSubnetFg($sSubnet = "192.168.0.0", $cIpAddr = 0, $sFilter = '')
	__viScanSetProgress(5)
	Local $aIpList = __PingScan($sSubnet)               ; scan network for active IP addresses
	__viScanMergeIPlist($aIpList, $g_aVisaDevices)      ; merge previous scan with this one
	$g_aVisaDevices = __viScanList($aIpList)            ; query visa *IDN? to see which IP addresses are VISA instruments
	__viClassifyList($g_aVisaDevices)                   ; classify each found VISA instrument
	__viScanSetProgress(0)
	If $cIpAddr <> 0 And $cIpAddr <> '' Then            ; if specified then populate a given combo box with the results
		__viScanPopulateComboBox($cIpAddr, $sFilter)
	Else
		__viScanDistribute()
	EndIf
	Return $g_aVisaDevices                              ; return the list

	;	[ [ '192.168.0.14',      '192.168.0.14:inst0', 'TEKTRONIX,MSO58B,B028134,CF:91.1CT FV:2.26.13-release.58', 'Oscilloscope' ]
	;     [ '192.168.0.15',  'raw:192.168.0.15:5025',  '"Watlow Electric","F4T1L2EAA2E1017",39468,"4.08"',         'Chamber' ]
	;     [ '192.168.0.16',      '192.168.0.16:inst0', 'Agilent Technologies,N6705B,MY53000443,D.02.15',           'DC Power Supply' ]
	;     [ '192.168.0.25',  'raw:192.168.0.25:5025',  '"Watlow Electric","F4T1L2EAA2E1017",15930,"4.07"',         'Chamber' ]
	;     [ '192.168.0.1',   'raw:192.168.0.1:5025',   '',                                                         '' ]
	;     [ '192.168.0.217', 'raw:192.168.0.217:5025', '',                                                         '' ] ]
EndFunc   ;==>__viScanSubnetFg



Func __viScanDistribute()
	If $g_tc_hIpAddr <> '' Then __viScanPopulateComboBox($g_tc_hIpAddr, "tc")
	If $g_dc_hIpAddr <> '' Then __viScanPopulateComboBox($g_dc_hIpAddr, "dc")
	If $g_fc_hIpAddr <> '' Then __viScanPopulateComboBox($g_fc_hIpAddr, "fc")
	If $g_sc_hIpAddr <> '' Then __viScanPopulateComboBox($g_sc_hIpAddr, "sc")
	If $g_dg_hIpAddr <> '' Then __viScanPopulateComboBox($g_dg_hIpAddr, "", True)
	;If $__viSD_hIpAddr <> '' And $__viSD_hIpAddr <> 0 Then __viScanPopulateComboBox($__viSD_hIpAddr, "")
EndFunc   ;==>__viScanDistribute



;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;
; subnet scan functions - background edition


Global $g_iViScanStage = 0                                                  ; 0 = idle stage, no scan in progress
Global $g_sViScanSubnet, $g_aViScanPIDs, $g_iViScanI, $g_iViScanN, $g_iViScanStageI, $g_iViScanStageN, $g_iViScanStageM
Global $g_iViScanTimer = TimerInit()

Func __viScanSubnetBg($sSubnet = "192.168.0.0")
	$g_sViScanSubnet = $sSubnet                                             ; set subnet to be scanned
	$g_iViScanStage = 1                                                     ; kick off the scan by putting it into stage 1 - ping
EndFunc   ;==>__viScanSubnetBg



Func __viLoopScan()
	If TimerDiff($g_iViScanTimer) < 500 Then Return                         ; reduce compute load by only checking on background every so often
	$g_iViScanTimer = TimerInit()

	If $g_iViScanStage = 1 Then __PingScanBgBegin()
	If $g_iViScanStage = 2 Then __PingScanBgLaunch()
	If $g_iViScanStage = 3 Then $g_iViScanStage = 5
	If $g_iViScanStage = 5 Then __PingScanBgGatherBegin()
	If $g_iViScanStage = 6 Then __PingScanBgGather()
	If $g_iViScanStage = 7 Then $g_iViScanStage = 10

	If $g_iViScanStage = 10 Then __VisaScanBgBegin()
	If $g_iViScanStage = 11 Then __VisaScanBgLaunch()
	If $g_iViScanStage = 12 Then __VisaScanBgProg1()
	If $g_iViScanStage = 13 Then __VisaScanBgGatherBegin()
	If $g_iViScanStage = 14 Then __VisaScanBgGather()
	If $g_iViScanStage = 15 Then $g_iViScanStage = 20

	If $g_iViScanStage = 20 Then __VisaScanBgClassifyList()
	If $g_iViScanStage = 21 Then $g_iViScanStage = 0

EndFunc   ;==>__viLoopScan



; PING scan ----------------------------------------------------------------

Func __PingScanBgBegin()
	Dim $g_aViScanPIDs[255]
	$g_sViScanSubnet = StringRegExpReplace($g_sViScanSubnet, "\d+$", "")    ; remove last number, but keep the dot
	__viScanSetProgress(5)
	$g_iViScanStage += 1
	$g_iViScanStageI = 0
	$g_iViScanStageN = 32
	$g_iViScanStageM = Ceiling(256 / $g_iViScanStageN)
EndFunc   ;==>__PingScanBgBegin

Func __PingScanBgLaunch()
	Local $iStart = $g_iViScanStageI * $g_iViScanStageM + 1
	Local $iEnd = _Min($iStart + $g_iViScanStageM, 254)
	For $i = $iStart To $iEnd                                               ; Launch 254 hidden, concurrent pings
		Local $sIP = $g_sViScanSubnet & $i
		; Run a fast, single-echo ping (-n 1) with a 750ms timeout (-w 750).
		; We ask cmd to echo "ONLINE" only if the ping succeeds.
		$g_aViScanPIDs[$i] = Run(@ComSpec & ' /c ping -n 1 -w 2000 ' & $sIP & ' | findstr "TTL=" && echo ONLINE', @TempDir, @SW_HIDE, $STDOUT_CHILD)
		If Mod($i, 10) = 0 Then __viScanSetProgress(Int($i / 254 * 20) + 5)
		Sleep(1)
	Next
	$g_iViScanStageI += 1
	If $g_iViScanStageI >= $g_iViScanStageN Then $g_iViScanStage += 1
	;__ConsolePrintVars("__PingScanBgGatherBegin, ", "stage", $g_iViScanStage, "iEnd", $iEnd)
EndFunc   ;==>__PingScanBgLaunch


Func __PingScanBgGatherBegin()
	__viScanSetProgress(25)
	Local $i
	$g_iViScanI = 0
	$g_iViScanN = 0
	For $i = 1 To 254
		If $g_aViScanPIDs[$i] <> 0 Then $g_iViScanN += 1
	Next
	$i = 1
	If IsArray($g_aVisaDevices) Then
		If UBound($g_aVisaDevices, 0) = 2 Then
			If UBound($g_aVisaDevices, 2) >= 5 Then $i = 0
		EndIf
	EndIf
	If $i Then Dim $g_aVisaDevices[0][5]
	$g_iViScanStage += 1
	;__ConsolePrintVars("__PingScanBgGatherBegin, ", "stage", $g_iViScanStage, "aDevs", $g_aVisaDevices)
	$g_iViScanStageI = 0
	$g_iViScanStageN = 32
	$g_iViScanStageM = Ceiling(256 / $g_iViScanStageN)
EndFunc   ;==>__PingScanBgGatherBegin

Func __PingScanBgGather()
	Local $iStart = $g_iViScanStageI * $g_iViScanStageM + 1
	Local $iEnd = _Min($iStart + $g_iViScanStageM, 254)
	For $i = $iStart To $iEnd                                               ; Harvest results asynchronously
		Local $sIP = $g_sViScanSubnet & $i
		If $g_aViScanPIDs[$i] <= 0 Then ContinueLoop
		If ProcessExists($g_aViScanPIDs[$i]) Then ContinueLoop
		Local $sOutput = StdoutRead($g_aViScanPIDs[$i])                     ;   Read the standard output of the hidden window
		$g_aViScanPIDs[$i] = 0                                              ;   mark out the PID in the array so we don't process this again
		$g_iViScanI += 1                                                    ;   increment progress counter
		If Mod($g_iViScanI, 10) = 0 Then _                                  ;   update the progress bar
				__viScanSetProgress(Int($g_iViScanI / $g_iViScanN * 25) + 25)
		If Not StringInStr($sOutput, "ONLINE") Then ContinueLoop            ;
		Local $nC = UBound($g_aVisaDevices, 2)                              ;   If the window text output includes "ONLINE" keyword, it's alive!
		Local $iV, $nV = UBound($g_aVisaDevices, 1) - 1                     ;
		For $iV = 0 To $nV                                                  ;   Check if IP address is alread in the main list
			If $sIP = $g_aVisaDevices[$iV][0] Then ExitLoop
		Next
		If $iV <= $nV Then ContinueLoop                                     ;
		$nV += 1                                                            ;   if not in the list, then add it at the end
		ReDim $g_aVisaDevices[$nV + 1][$nC]
		$g_aVisaDevices[$nV][0] = $sIP
	Next
	$g_iViScanStageI += 1
	If $g_iViScanStageI >= $g_iViScanStageN Then
		$g_iViScanStageI = 0
		If $g_iViScanI >= $g_iViScanN Then                                  ;   if all background processes are done then
			__viScanSetProgress(50)                                         ;     set progress indicator to 50%
			$g_iViScanStage += 1                                            ;     move to next scan stage
		EndIf
	EndIf
	;__ConsolePrintVars("__PingScanBgGather, ", "stage", $g_iViScanStage, "stageI", $g_iViScanStageI, @CRLF & "aDevs", $g_aVisaDevices)
EndFunc   ;==>__PingScanBgGather



; VISA IDN scan ------------------------------------------------------------

Func __VisaScanBgBegin()
	;__viScanSetProgress(50)                                                 ; update progress
	Local $i, $n = UBound($g_aVisaDevices, 1) - 1
	For $i = 0 To $n                                                        ; copy IP addresses into output array
		$g_aVisaDevices[$i][1] = ''                                         ; address string with port and mode ("raw:")
		$g_aVisaDevices[$i][2] = ''                                         ; IDN
		$g_aVisaDevices[$i][3] = ''                                         ; classification initials
		$g_aVisaDevices[$i][4] = ''                                         ; classification name
		$g_aViScanPIDs[$i] = 0                                              ; PID of background process
	Next
	$g_iViScanStage += 1
	;__ConsolePrintVars("__VisaScanBgBegin, ", "stage", $g_iViScanStage, @CRLF & "aDevs", $g_aVisaDevices)
EndFunc   ;==>__VisaScanBgBegin

Func __VisaScanBgLaunch()
	Local $i, $n = UBound($g_aVisaDevices, 1) - 1, $s
	Local $sPre = ''
	If Not @Compiled Then $sPre &= '"' & @AutoItExe & '" '
	$sPre &= '"' & @ScriptFullPath & '" :getidn: "'
	For $i = 0 To $n                                                        ; Spawn all worker processes simultaneously (Non-blocking Parallel Launch)
		$s = $sPre & $g_aVisaDevices[$i][0] & '"'
		$g_aViScanPIDs[$i] = Run($s, @TempDir, @SW_HIDE, $STDOUT_CHILD)
		;__ConsolePrintVars("__VisaScanBgLaunch, ", "cmd", $s)
	Next
	__viScanSetProgress(50)                                                 ; update progress bar
	$g_iViScanStage += 1
	;__ConsolePrintVars("__VisaScanBgLaunch, ", "stage", $g_iViScanStage, @CRLF & "aDevs", $g_aVisaDevices)
	$g_iViScanStageI = 50                                                   ; prep for Prog1
	$g_iViScanStageN = 75
	$g_iViScanStageM = TimerInit()
	$g_iViScanN = Int(12500 / ($g_iViScanStageN - $g_iViScanStageI))        ; show progress bar movement over 10 seconds
	$g_iViScanI = $g_iViScanN
EndFunc   ;==>__VisaScanBgLaunch

Func __VisaScanBgProg1()
	If TimerDiff($g_iViScanStageM) < $g_iViScanN Then Return
	$g_iViScanI += $g_iViScanN
	$g_iViScanStageI += 1
	__viScanSetProgress($g_iViScanStageI)
	If $g_iViScanStageI >= $g_iViScanStageN Then $g_iViScanStage += 1
EndFunc   ;==>__VisaScanBgProg1


Func __VisaScanBgGatherBegin()
	__viScanSetProgress(75)                                                 ; update progress bar
	Local $i, $n = UBound($g_aVisaDevices) - 1
	$g_iViScanI = 0
	$g_iViScanN = 0
	For $i = 0 To $n
		If $g_aViScanPIDs[$i] <> 0 Then $g_iViScanN += 1
	Next
	$g_iViScanStage += 1
	;__ConsolePrintVars("__VisaScanBgGatherBegin, ", "stage", $g_iViScanStage, @CRLF & "aDevs", $g_aVisaDevices)
EndFunc   ;==>__VisaScanBgGatherBegin


Func __VisaScanBgGather()
	Local $i, $n = UBound($g_aVisaDevices) - 1, $sOut, $sAddr, $aLine
	For $i = 0 To $n                                                        ; Harvest results asynchronously
		If $g_aViScanPIDs[$i] <= 0 Then ContinueLoop
		If ProcessExists($g_aViScanPIDs[$i]) Then ContinueLoop
		$sOut = StdoutRead($g_aViScanPIDs[$i])                              ; Read the standard output of the hidden window
		If @error Then $sOut = ""
		$g_aViScanPIDs[$i] = 0
		$g_iViScanI += 1
		__viScanSetProgress(75 + Int(($g_iViScanI / $g_iViScanN) * 25))     ; update progress bar
		If $sOut = "" Then ContinueLoop                                     ; parse output: [raw:]IP[:port] @CRLF IDN_string
		If StringInStr($sOut, @LF) Then
			$aLine = StringSplit($sOut, @LF, 1)
			If $aLine[0] >= 2 Then
				$sAddr = StringStripWS($aLine[1], 3)
				$sOut = $aLine[2]
				If StringLeft($sOut, 1) = """" Then $sOut = StringReplace($sOut, """", "")
			ElseIf $aLine[0] = 1 Then
				$sAddr = ''
				$sOut = $aLine[1]
			EndIf
			$sOut = StringStripWS($sOut, 3)
		EndIf
		$g_aVisaDevices[$i][2] = $sOut
		$g_aVisaDevices[$i][1] = $sAddr
	Next
	;__ConsolePrintVars("__VisaScanBgGather, ", "stage", $g_iViScanStage, @CRLF & "aDevs", $g_aVisaDevices)
	If $g_iViScanI >= $g_iViScanN Then $g_iViScanStage += 1                 ; if all of the background ping process have finished then move to next stage
EndFunc   ;==>__VisaScanBgGather


Func __VisaScanBgClassifyList()
	;__ConsolePrintVars("__VisaScanBgClassifyList, ", "stage", $g_iViScanStage, @CRLF & "aDevs", $g_aVisaDevices)
	__viScanSetProgress(100)                                                ; update progress bar
	$g_aViScanPIDs = ''
	Local $i, $n = UBound($g_aVisaDevices) - 1
	Local $j, $k = 0, $t
	For $i = 0 To $n                                                        ;
		If $g_aVisaDevices[$i][2] = "" Then ContinueLoop                    ; move blank IDNs to the bottom
		If $k <> $i Then
			For $j = 0 To 3
				$t = $g_aVisaDevices[$k][$j]
				$g_aVisaDevices[$k][$j] = $g_aVisaDevices[$i][$j]
				$g_aVisaDevices[$i][$j] = $t
			Next
		EndIf
		$t = __viClassifyItem($g_aVisaDevices[$k][2])                       ; classify the visa device by its IDN description
		$j = StringInStr($t, " ")
		If $j Then
			$g_aVisaDevices[$k][3] = StringLeft($t, $j - 1)
			$t = StringTrimLeft($t, $j)
		EndIf
		$g_aVisaDevices[$k][4] = $t
		$k += 1                                                             ; increment k to the next spot for identified IPNs
	Next
	__viScanDistribute()                                                    ; distribute results to all of the device selection boxes
	;__ConsolePrintVars("__VisaScanBgClassifyList, ", "stage", $g_iViScanStage, @CRLF & "aDevs", $g_aVisaDevices)
	$g_iViScanStage += 1
EndFunc   ;==>__VisaScanBgClassifyList





;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;
; subnet scan functions - foreground edition



;			PingScan
; task:		scan subnet for active IP addresses
; in:		subnet IP prefix
; out:		array of found IP addresses
Func __PingScan($sSubnetBase = "192.168.0.0")
	Local $aPIDs[255]                                                                                       ; Properly declared array size
	Local $aActiveIPs[0]
	Local $iFoundCount = 0
	Local $iProgressStep0 = 5
	Local $iProgressStep1 = 25
	Local $iProgressStep1delta = $iProgressStep1 - $iProgressStep0
	Local $iProgressStep2 = 50 - $iProgressStep1

	$sSubnetBase = StringRegExpReplace($sSubnetBase, "\d+$", "")                                            ; remove last number, but keep the dot
	__viScanSetProgress(5)
	For $i = 1 To 254                                                                                       ; 1. Launch 254 hidden, concurrent pings
		Local $sIP = $sSubnetBase & $i
		; Run a fast, single-echo ping (-n 1) with a 750ms timeout (-w 750).
		; We ask cmd to echo "ONLINE" only if the ping succeeds.
		$aPIDs[$i] = Run(@ComSpec & ' /c ping -n 1 -w 750 ' & $sIP & ' | findstr "TTL=" && echo ONLINE', @TempDir, @SW_HIDE, $STDOUT_CHILD)
		LoopExec()
		If Mod($i, 10) = 0 Then __viScanSetProgress(Int(($i / 254) * $iProgressStep1delta + $iProgressStep0))
		Sleep(50)
	Next

	__viScanSetProgress($iProgressStep1)
	Local $iDoneN = 0, $iDoneCount = 0, $bDelta
	For $i = 1 To 254
		If $aPIDs[$i] <> 0 Then $iDoneN += 1
	Next
	Do
		$bDelta = False
		For $i = 1 To 254                                           ; 2. Harvest results asynchronously
			Local $sIP = $sSubnetBase & $i
			If $aPIDs[$i] > 0 Then
				If Not ProcessExists($aPIDs[$i]) Then
					Local $sOutput = StdoutRead($aPIDs[$i])         ; Read the standard output of the hidden window
					If StringInStr($sOutput, "ONLINE") Then         ; If the window text output includes "ONLINE" keyword, it's alive!
						$iFoundCount += 1
						ReDim $aActiveIPs[$iFoundCount]
						$aActiveIPs[$iFoundCount - 1] = $sIP
					EndIf
					$aPIDs[$i] = 0
					$iDoneCount += 1
					$bDelta = True
				EndIf
			EndIf
			If $bDelta Then
				If Mod($iDoneCount, 10) = 0 Then _                  ; update the progress bar
						__viScanSetProgress($iProgressStep1 + Int(($iDoneCount / $iDoneN) * $iProgressStep2))
			EndIf
		Next
		LoopExec()                                                  ; run main background loop
		Sleep(50)
	Until $iDoneCount >= $iDoneN

	Return $aActiveIPs
EndFunc   ;==>__PingScan



Func __viScanMergeIPlist(ByRef $aIpList, $aVisaList)
	If Not IsArray($aIpList) Or Not IsArray($aVisaList) Then Return
	If UBound($aVisaList, 0) <> 2 Then Return
	Local $iP, $iV, $nP = UBound($aIpList) - 1, $nV = UBound($aVisaList, 1) - 1
	For $iV = 0 To $nV
		For $iP = 0 To $nP
			If $aIpList[$iP] = $aVisaList[$iV][0] Then ExitLoop
		Next
		If $iP <= $nP Then ContinueLoop
		$nP += 1
		ReDim $aIpList[$nP + 1]
		$aIpList[$nP] = $aVisaList[$iV][0]
	Next
EndFunc   ;==>__viScanMergeIPlist



; 			VisaScan (parallel mode)
; task:		query each given IP address to get its ID string
; in:		list of IP addresses
; out:		ip addresses with their corresponding IDN string
;	[ [ '192.168.0.14',      '192.168.0.14:inst0', 'TEKTRONIX,MSO58B,B028134,CF:91.1CT FV:2.26.13-release.58', 'sc', 'Oscilloscope' ]
;     [ '192.168.0.15',  'raw:192.168.0.15:5025',  '"Watlow Electric","F4T1L2EAA2E1017",39468,"4.08"',         'tc', 'Chamber' ]
;     [ '192.168.0.16',      '192.168.0.16:inst0', 'Agilent Technologies,N6705B,MY53000443,D.02.15',           'dc', 'DC Power Supply' ]
;     [ '192.168.0.25',  'raw:192.168.0.25:5025',  '"Watlow Electric","F4T1L2EAA2E1017",15930,"4.07"',         'tc', 'Chamber' ]
;     [ '192.168.0.1',   'raw:192.168.0.1:5025',   '',                                                         '',   '' ]
;     [ '192.168.0.217', 'raw:192.168.0.217:5025', '',                                                         '',   '' ] ]
Func __viScanList($aIpList)

	Local Const $iRetries = 1
	Local $iCount = UBound($aIpList)
	Local $iN = $iCount - 1
	Local $aPIDs[$iCount]                   ; To track process IDs
	Local $aDevs[$iCount][5]                ; resulting list
	Local $i, $j, $k                        ; counter
	Local $iProgressStep1 = 50
	Local $iProgressStep2 = 60
	Local $iProgressStep3 = 75
	Local $iProgressStep1delta = $iProgressStep2 - $iProgressStep1
	Local $iProgressStep2delta = $iProgressStep3 - $iProgressStep2
	Local $iProgressStep3delta = 100 - $iProgressStep3

	For $i = 0 To $iN                       ; copy IP addresses into output array
		$aDevs[$i][0] = $aIpList[$i]        ; IP address
		$aDevs[$i][1] = ''                  ; address string with port and mode ("raw:")
		$aDevs[$i][2] = ''                  ; IDN
		$aDevs[$i][3] = ''                  ; classification initials
		$aDevs[$i][4] = ''                  ; classification name
		$aPIDs[$i] = 0                      ; PID of background process
	Next

	For $j = 1 To $iRetries
		__viScanSetProgress($iProgressStep1)                                            ; update progress
		For $i = 0 To $iN                                                               ; 1. Spawn all worker processes simultaneously (Non-blocking Parallel Launch)
			If $aDevs[$i][2] = "" Then                                                  ; if we do not have IDN yet, then spawn a process to ask for it
				If @Compiled Then                                                       ; If compiled, call the current EXE directly with the argument
					$aPIDs[$i] = Run('"' & @ScriptFullPath & '" :getidn: "' & _
							$aIpList[$i] & '"', @TempDir, @SW_HIDE, $STDOUT_CHILD)
				Else                                                                    ; If uncompiled, call the AutoIt interpreter, pass the script path, then the argument
					$aPIDs[$i] = Run('"' & @AutoItExe & '" "' & @ScriptFullPath & _
							'" :getidn: "' & $aIpList[$i] & '"', @TempDir, @SW_HIDE, $STDOUT_CHILD)
				EndIf
			Else
				$aPIDs[$i] = 0
			EndIf
			LoopExec()
			__viScanSetProgress($iProgressStep1 + _
					Int(($i / $iCount) * $iProgressStep1delta))                         ; update the progress bar
			Sleep(10)                                                                   ; a short pause between deployments of the visa IDN requests
		Next

		__viScanSetProgress($iProgressStep2)                                            ; update progress bar
		Local $iProgressStep2delta2 = Int(240 / $iProgressStep2delta)
		For $i = 1 To $iProgressStep2delta
			__viScanSetProgress($iProgressStep2 + $i)
			For $k = 1 To $iProgressStep2delta2
				LoopExec()
				Sleep(50)
			Next
		Next

		Local $iDoneN = 0, $iDoneCount = 0, $bDelta
		For $i = 0 To $iN
			If $aPIDs[$i] <> 0 Then $iDoneN += 1
		Next
		Do
			$bDelta = False
			For $i = 0 To $iN                                                           ; 2. Harvest results asynchronously
				If $aPIDs[$i] > 0 Then
					If Not ProcessExists($aPIDs[$i]) Then
						Local $sOut = StdoutRead($aPIDs[$i])                            ; Read the standard output of the hidden window
						If @error Then $sOut = ""
						If $sOut <> "" Then                                             ; parse output: [raw:]IP[:port] @CRLF IDN_string
							Local $sAddr
							If StringInStr($sOut, @LF) Then
								Local $aLine = StringSplit($sOut, @LF, 1)
								If $aLine[0] >= 2 Then
									$sAddr = StringStripWS($aLine[1], 3)
									$sOut = $aLine[2]
									If StringLeft($sOut, 1) = """" Then $sOut = StringReplace($sOut, """", "")
								ElseIf $aLine[0] = 1 Then
									$sAddr = ''
									$sOut = $aLine[1]
								EndIf
								$sOut = StringStripWS($sOut, 3)
							EndIf
							$aDevs[$i][2] = $sOut
							$aDevs[$i][1] = $sAddr
						EndIf
						$aPIDs[$i] = 0
						$iDoneCount += 1
						$bDelta = True
					EndIf
				EndIf
				If $bDelta Then _
						__viScanSetProgress($iProgressStep3 + _
						Int(($iDoneCount / $iDoneN) * $iProgressStep3delta))            ; update progress bar
			Next
			LoopExec()
			Sleep(50)
		Until $iDoneCount >= $iDoneN

		Sleep(100)                                                                      ; give things time to settle
	Next

	For $i = 0 To $iN                                                                   ; parse IDN response
		If Not StringInStr($aDevs[$i][2], @LF) Then ContinueLoop                        ; in:  [ IPaddr, '', sAddr @CRLF IDNresponse ]
		Local $aLine = StringSplit($aDevs[$i][2], @CRLF, 1)                             ; out: [ IPaddr, [raw:]IP:port, IDN ]
		$aDevs[$i][2] = ""
		If $aLine[0] >= 1 Then $aDevs[$i][1] = StringStripWS($aLine[1], 3)
		If $aLine[0] >= 2 Then
			Local $idn = StringStripWS($aLine[2], 3)
			If StringLeft($idn, 1) = """" Then $idn = StringReplace($idn, """", "")
			$aDevs[$i][2] = $idn
		EndIf
	Next

	Local $t, $iFinished = 0                                                            ; soft list, moving blank IDNs to the bottom
	For $i = 0 To $iN                                                                   ;
		If $aDevs[$i][2] = "" Then ContinueLoop
		If $iFinished <> $i Then
			For $j = 0 To 3
				$t = $aDevs[$iFinished][$j]
				$aDevs[$iFinished][$j] = $aDevs[$i][$j]
				$aDevs[$i][$j] = $t
			Next
		EndIf
		$iFinished += 1
	Next

	Return $aDevs
EndFunc   ;==>__viScanList



Func __viClassifyList(ByRef $aTable)
	If Not IsArray($aTable) Then Return
	If UBound($aTable, 0) <> 2 Then Return
	If UBound($aTable, 2) < 4 Then Return
	Local $i, $iN = UBound($aTable, 1) - 1, $j, $s
	For $i = 0 To $iN
		$s = __viClassifyItem($aTable[$i][2])
		$j = StringInStr($s, " ")
		If $j Then
			$aTable[$i][3] = StringLeft($s, $j - 1)
			$s = StringTrimLeft($s, $j)
		EndIf
		$aTable[$i][4] = $s
	Next
EndFunc   ;==>__viClassifyList




;			__viScanID
; task:		try various protocols to communicate with instrument and get its ID
; in:		$ipAddr = the IP address of the instrument
; out:		[0] = full visa address including which protocol to use to communicate with this instrument in the future
;			[1] = response string from VISA *IDN? request
Func __viScanID($ipAddr)
	Local $aR[2]
	$aR[1] = __viGetID($ipAddr, 1100)
	$aR[0] = $ipAddr.Item('sAddr')
	Return $aR
EndFunc   ;==>__viScanID



; task:		populate an IP address selection box from the list of found Visa devices in $g_aVisaDevices
; in:		$cIpAddr = gui control handle for combo box
;			$filter = filter string, one of the following
;				Chamber
;				DC Power Supply
;				Oscilloscope
;				Frequency Counter
;				blank to include everything
; out:		combo box populated with list
;			the list of items in the combo box
Func __viScanPopulateComboBox($cIpAddr, $sFilter = "", $bInclUnk = False)
	;If Not __IsComboBox($cIpAddr) Then Return
	If Not IsArray($g_aVisaDevices) Then Return
	If UBound($g_aVisaDevices, 0) <> 2 Then Return
	If UBound($g_aVisaDevices, 2) < 4 Then Return

	Local $sSep = Opt("GUIDataSeparatorChar")
	Local $s = "", $st, $su, $a, $bFound = False
	Local $ss = __viTrimIP(GUICtrlRead($cIpAddr))
	Local $i, $t, $n = UBound($g_aVisaDevices, 1) - 1
	For $i = 0 To $n
		$t = $g_aVisaDevices[$i][3]
		If ($t = $sFilter) Or (($t = "") And $bInclUnk) Or ($sFilter = "") Then
			$st = $g_aVisaDevices[$i][0]
			$su = $g_aVisaDevices[$i][2]
			If $su <> '' Then
				$a = StringSplit($su, ",")
				If $a[0] >= 3 Then $su = $a[3]
				$su = StringReplace($su, '"', '')
				$su = "   " & $su
			EndIf
			$su = StringReplace($st & $su, $sSep, "_")
			If $st = $ss Or $ss = "" Then
				$bFound = True
				$ss = $su
			EndIf
			$s &= $sSep & $su
		EndIf
	Next
	If Not $bFound Then $s = $sSep & $ss & $s                                   ; if existing selected option is not in the list, then add it to the list
	GUICtrlSetData($cIpAddr, $s, $ss)                                           ; leading sep character erases any prior data in the combobox
	_GUICtrlComboBox_SetEditSel($cIpAddr, 0, 0)
	$s = StringTrimLeft($s, 1)                                                  ; remove leading sep character for use in calling function

	;__FocusComboBox_Register($cIpAddr)  										 ; register the combobox to have its leading text kept visible
	Return $s
EndFunc   ;==>__viScanPopulateComboBox



Func __viAddFoundVisaDevice($sIpAddr)                               ; Add IP address to the list of found devices
	$sIpAddr = __viTrimIP($sIpAddr)
	Local $a[0][4]
	If Not IsArray($g_aVisaDevices) Then $g_aVisaDevices = $a
	If UBound($g_aVisaDevices, 0) <> 2 Then $g_aVisaDevices = $a
	If UBound($g_aVisaDevices, 2) < 4 Then $g_aVisaDevices = $a
	Local $i, $n = UBound($g_aVisaDevices, 1) - 1, $m = UBound($g_aVisaDevices, 2)
	For $i = 0 To $n
		If $g_aVisaDevices[$i][0] = $sIpAddr Then Return       ; if found in list then done, nothing to add
	Next
	$n += 1                                                         ; if not found in list then add it to the list
	ReDim $g_aVisaDevices[$n + 1][$m]
	$g_aVisaDevices[$n][0] = $sIpAddr
EndFunc   ;==>__viAddFoundVisaDevice


; ------------------------------------
; ------------------------------------
; ------------------------------------
; ------------------------------------
; ------------------------------------
; misc gui visa related functions
;



Func __viGUIGetIP($cIpAddr)                                            ; get the selected ip address from a combo box
	Return __viTrimIP(GUICtrlRead($cIpAddr))
EndFunc   ;==>__viGUIGetIP
Func __viTrimIP($sIpAddr)                                           ; trim extra information from tail end of ip address - anything after the first space
	$sIpAddr = StringStripWS($sIpAddr, 3)
	Local $iPos = StringInStr($sIpAddr, ' ')
	If $iPos > 0 Then $sIpAddr = StringLeft($sIpAddr, $iPos - 1)
	Return $sIpAddr
EndFunc   ;==>__viTrimIP



;Func __viGUISetID($cDevID, $sId)
;	GUICtrlSetData($cDevID, $sId)
;	_GUICtrlEdit_SetSel($cDevID, 0, 0)
;EndFunc   ;==>__viGUISetID



Func __viGUIGetID($hDevID, $hIpAddr, ByRef $oDev, $sbCommValid, $sPre = '')
	_GUICtrlComboBox_SetEditSel($hIpAddr, 0, 0)
	If $hDevID <> "" Then GUICtrlSetData($hDevID, "Checking...")
	$oDev = $sPre & __viGUIGetIP($hIpAddr)
	Local $sId = __viGetID($oDev)
	If $hDevID <> "" Then __viGUISetID($hDevID, ($sId = '') ? 'Not Found' : $sId)
	If $sbCommValid <> "" Then Assign($sbCommValid, Not ($sId = ""), 2)
	Return $sId
EndFunc   ;==>__viGUIGetID



Func __viGUIGetIDbg($hDevID, $hIpAddr, ByRef $oDev, $sbCommValid, $sPre = '')
	_GUICtrlComboBox_SetEditSel($hIpAddr, 0, 0)
	If $hDevID <> "" Then GUICtrlSetData($hDevID, "Checking...")
	$oDev = $sPre & __viGUIGetIP($hIpAddr)
	If Not __viResolveInstrument($oDev) Then Return
	If $hDevID <> "" Then $oDev.Item('hDevID') = $hDevID
	$oDev.Item('bCommValid') = $sbCommValid
	__viGetIDbg($oDev, "")
EndFunc   ;==>__viGUIGetIDbg




Global $g_configFile

Func __viSaveIP($cIpAddr, $configSection)                                                                   ; Save ip address to config file
	__viAddFoundVisaDevice(__viGUIGetIP($cIpAddr))                                                          ; ensure selected ip is in the global list
	__IniWriteGuiComboBox($cIpAddr, "IpAddr", $configSection)
EndFunc   ;==>__viSaveIP

Func __viLoadIP($cIpAddr, $configSection)                                                                   ; Load ip address from config file
	__IniReadGuiComboBox($cIpAddr, "IpAddr", $configSection)
EndFunc   ;==>__viLoadIP



Func __viGuiPicLoop(ByRef $bDownloadingFlag, ByRef $bPicData, $iTabIdx, ByRef $iScreen, $hScreen)
	If $bDownloadingFlag Then                                                           ; when screenshot download is received then update the gui
		If IsBinary($bPicData) Then
			__viParsePicture($bPicData)
			Local $oCanvas = $g_aCanvas[$iTabIdx]
			If $oCanvas.Exists('bZoomNeedCataloged') Then __Canvas_ZoomCatalog($oCanvas)
			If $iScreen < 0 Or $iScreen = '' Then $iScreen = __Canvas_ZoomFind($oCanvas, $hScreen)
			;__ConsolePrintVar("__viGuiPicLoop", "bDownloading", $bDownloadingFlag, "bPicData", $bPicData, "oCanvas", $oCanvas)
			;__ConsolePrintVar("__viGuiPicLoop", "iScreen", $iScreen, "hScreen", $hScreen)
			If $iScreen >= 0 Then
				Local $aCtrl = $oCanvas.Item('aCanvasCtrls')
				$aCtrl[$iScreen][5] = $bPicData
				$oCanvas.Item('aCanvasCtrls') = $aCtrl
				If GUICtrlRead($g_cTab) = $iTabIdx Then
					__WinLockRepaint()
					__Canvas_AdjZoom($oCanvas)      ; adjust the picture to the current zoom scale and put it in the gui
					__WinUnlockRepaint()
				EndIf
				$bPicData = 0
			EndIf
			$bDownloadingFlag = False
		EndIf
	EndIf
EndFunc   ;==>__viGuiPicLoop


Func __viGuiPicRefresh(ByRef $bDownloadingFlag, ByRef $bPicData, $viSession, $aCmds)         ; start request for screen shot or other picture from visa device
	$bDownloadingFlag = True                    ; set downloading flag to true
	$bPicData = ''                              ; clear the picture data
	If $viSession = '' Then Return              ; skip bad input
	__viScript($viSession, $aCmds, "", 5000)    ; enque the script commands
EndFunc   ;==>__viGuiPicRefresh





; ------------------------------------
; ------------------------------------
; ------------------------------------
; ------------------------------------
; ------------------------------------
; hook to keep text at front visible in combo boxes
;



; Register the WM_COMMAND message to catch the focus event
Global $g_focusComboBoxes = ObjCreate("Scripting.Dictionary")

Func __FocusComboBox_Register($hCtrl)
	$g_focusComboBoxes.Item(String(GUICtrlGetHandle($hCtrl))) = $hCtrl
EndFunc   ;==>__FocusComboBox_Register

Func __FocusComboBox_Unregister($hCtrl)
	Local $s = String(GUICtrlGetHandle($hCtrl))
	If $g_focusComboBoxes.Exists($s) Then $g_focusComboBoxes.Remove($s)
EndFunc   ;==>__FocusComboBox_Unregister


Func __FocusComboBox_WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
	If $hWnd <> $g_hMainGui Then Return $GUI_RUNDEFMSG
	Local $nNotifyCode = BitShift($wParam, 16)                                      ; High Word: Notification
	Local $nID = BitAND($wParam, 0xFFFF)                                            ; Low Word: Control ID
	If $nNotifyCode <> 3 Then Return $GUI_RUNDEFMSG                                 ; $CBN_SETFOCUS = 3 (Triggered the millisecond the ComboBox gets focus)
	If Not $g_focusComboBoxes.exists(String($lParam)) Then Return $GUI_RUNDEFMSG    ; Check if the event belongs to your ComboBox
	_GUICtrlComboBox_SetEditSel($lParam, 0, 0)                                        ; Force the selection/cursor to the very front (Start: 0, End: 0)
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FocusComboBox_WM_COMMAND
