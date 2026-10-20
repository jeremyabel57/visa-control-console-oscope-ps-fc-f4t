#include-once


Global $g_aFoundVisaDevices = 0                            ; contains 2d array list of found IP addresses, id strings, and classification type
;Local $a = [["192.168.0.14", "TCPIP0::192.168.0.14::inst0::INSTR", "TEKTRONIX,MSO58B...", "Oscilloscope"], _
;		["192.168.0.15", "TCPIP::192.168.0.15::5025::SOCKET", "Watlow Electric,F4T...", "Chamber"], _
;		["192.168.0.16", "TCPIP0::192.168.0.16::inst0::INSTR", "Agilent Tech,N6705B...", "DC Power Supply"], _
;		["192.168.0.25", "TCPIP::192.168.0.25::5025::SOCKET", "Watlow Electric,F4T...", "Chamber"]]




Global Const $WS_SYSTEMMENU = 0x00080000

#include "visascpi_queue.au3"
#include "winmgmt.au3"
#include "myconstants.au3"


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
	__viScanSubnetRunFirst()                                                            ; catch callbacks for parallel visa IDN scanning
	TCPNameToIP("127.0.0.1")                                                            ; ensure TCP has been initialized
	If @error = 10093 Then TCPStartup()

	LoopRegister("__viLoop")                                                            ; register the main loop function

	OnAutoItExitRegister("__viExit")                                                    ; cleanup on exit
EndFunc   ;==>__viInit

Func __viExit()                                                                         ; call this before exiting main script
	If __IsDictionary($g_oViInstruments) Then
		Local $oDev, $sKey
		For $sKey In $g_oViInstruments
			$oDev = $g_oViInstruments.Item($sKey)
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
;		$filter = visa device type filter (Oscilloscope, DC Power Supply, Chamber, Frequency Counter)
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
	Local $sIP = StringStripWS(__viGetIP($__viSD_hIpAddr), 3)
	If $sIP == "" Or $sIP == "0.0.0.0" Then Return

	GUICtrlSetData($__viSD_hDevID, "Checking...")
	_WinAPI_UpdateWindow($__viSD_hGui)

	Local $sid = StringReplace(__viGetID($sIP, 1500), '"', "")
	GUICtrlSetData($__viSD_hDevID, $sid)
	_GUICtrlEdit_SetSel($__viSD_hDevID, 0, 0)
	_WinAPI_UpdateWindow($__viSD_hGui)
EndFunc   ;==>__viSD_Refresh



Func __viSD_OK()
	$__viSD_sResultIP = __viGetIP($__viSD_hIpAddr)
	$__viSD_sResultListRef = _GUICtrlComboBox_GetList($__viSD_hIpAddr)
	__viSD_Cleanup()

	Local $i, $N = UBound($g_aFoundVisaDevices) - 1
	For $i = 0 To $N
		If $g_aFoundVisaDevices[$i][0] = $__viSD_sResultIP Then ExitLoop
	Next
	If $g_aFoundVisaDevices[($i > $N) ? $N : $i][0] <> $__viSD_sResultIP Then
		$i = $N + 1
		ReDim $g_aFoundVisaDevices[$i + 1]
		$g_aFoundVisaDevices[$i][0] = $__viSD_sResultIP
		Local $oDev = $__viSD_sResultIP
		$g_aFoundVisaDevices[$i][2] = __viGetID($oDev)
		If __viIsInstrument($oDev) Then
			$g_aFoundVisaDevices[$i][1] = $oDev.Item['sAddr']
			$g_aFoundVisaDevices[$i][3] = __viClassifyItem($g_aFoundVisaDevices[$i][2])
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

			$g_viPrintQueuePop = False                                          ; turn off all debug outputs on the console so we can send our scan results
			$g_viPrintQueuePush = False
			$g_viPrintpQue = False
			$g_viPrintpQueCond = False
			$g_viPrintCmds = False
			$g_viPrintReadBuf = False

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
		If $iProgress > 0 Then __WinTitleNote("Subnet Search " & $iProgress & "%")
	EndIf
EndFunc   ;==>__viScanSetProgress



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
;				column 3 = classification of device type (Oscilloscope, Chamber, DC Power Supply, Frequency Counter)
Func __viScanSubnet($sSubnet = "192.168.0.0", $cIpAddr = 0, $sFilter = '')
	__viScanSetProgress(10)
	Local $aIpList = __PingScan($sSubnet)                   ; scan network for active IP addresses
	__viScanMergeIPlist($aIpList, $g_aFoundVisaDevices)     ; merge previous scan with this one
	$g_aFoundVisaDevices = __viScanList($aIpList)           ; query visa *IDN? to see which IP addresses are VISA instruments
	__viClassifyList($g_aFoundVisaDevices)                  ; classify each found VISA instrument
	__viScanSetProgress(0)
	If $cIpAddr <> 0 And $cIpAddr <> '' Then _              ; if specified then populate a given combo box with the results
			__viScanPopulateComboBox($cIpAddr, $sFilter)
	Return $g_aFoundVisaDevices                             ; return the list

	;	[ [ '192.168.0.14',      '192.168.0.14:inst0', 'TEKTRONIX,MSO58B,B028134,CF:91.1CT FV:2.26.13-release.58', 'Oscilloscope' ]
	;     [ '192.168.0.15',  'raw:192.168.0.15:5025',  '"Watlow Electric","F4T1L2EAA2E1017",39468,"4.08"',         'Chamber' ]
	;     [ '192.168.0.16',      '192.168.0.16:inst0', 'Agilent Technologies,N6705B,MY53000443,D.02.15',           'DC Power Supply' ]
	;     [ '192.168.0.25',  'raw:192.168.0.25:5025',  '"Watlow Electric","F4T1L2EAA2E1017",15930,"4.07"',         'Chamber' ]
	;     [ '192.168.0.1',   'raw:192.168.0.1:5025',   '',                                                         '' ]
	;     [ '192.168.0.217', 'raw:192.168.0.217:5025', '',                                                         '' ] ]
EndFunc   ;==>__viScanSubnet



;			PingScan
; task:		scan subnet for active IP addresses
; in:		subnet IP prefix
; out:		array of found IP addresses
Func __PingScan($sSubnetBase = "192.168.0.0")
	Local $aPIDs[255]                                                                                       ; Properly declared array size
	Local $aActiveIPs[0]
	Local $iFoundCount = 0
	Local $iProgressStep1 = 25
	Local $iProgressStep2 = 100 - $iProgressStep1

	$sSubnetBase = StringRegExpReplace($sSubnetBase, "\d+$", "")                                            ; remove last number, but keep the dot
	__viScanSetProgress(0)
	For $i = 1 To 254                                                                                       ; 1. Launch 254 hidden, concurrent pings
		Local $sIP = $sSubnetBase & $i
		; Run a fast, single-echo ping (-n 1) with a 750ms timeout (-w 750).
		; We ask cmd to echo "ONLINE" only if the ping succeeds.
		$aPIDs[$i] = Run(@ComSpec & ' /c ping -n 1 -w 750 ' & $sIP & ' | findstr "TTL=" && echo ONLINE', @TempDir, @SW_HIDE, $STDOUT_CHILD)
		LoopExec()
		If Mod($i, 10) = 0 Then __viScanSetProgress(Int(($i / 254) * 25))
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
	Local $bFound
	For $iV = 0 To $nV
		$bFound = False
		For $iP = 0 To $nP
			If $aIpList[$iP] = $aVisaList[$iV][0] Then
				$bFound = True
				ExitLoop
			EndIf
		Next
		If $bFound Then ContinueLoop
		$nP += 1
		ReDim $aIpList[$nP + 1]
		$aIpList[$nP] = $aVisaList[$iV][0]
	Next
EndFunc   ;==>__viScanMergeIPlist



; 			VisaScan (parallel mode)
; task:		query each given IP address to get its ID string
; in:		list of IP addresses
; out:		ip addresses with their corresponding IDN string
;	[ [ '192.168.0.14',      '192.168.0.14:inst0', 'TEKTRONIX,MSO58B,B028134,CF:91.1CT FV:2.26.13-release.58', 'Oscilloscope' ]
;     [ '192.168.0.15',  'raw:192.168.0.15:5025',  '"Watlow Electric","F4T1L2EAA2E1017",39468,"4.08"',         'Chamber' ]
;     [ '192.168.0.16',      '192.168.0.16:inst0', 'Agilent Technologies,N6705B,MY53000443,D.02.15',           'DC Power Supply' ]
;     [ '192.168.0.25',  'raw:192.168.0.25:5025',  '"Watlow Electric","F4T1L2EAA2E1017",15930,"4.07"',         'Chamber' ]
;     [ '192.168.0.1',   'raw:192.168.0.1:5025',   '',                                                         '' ]
;     [ '192.168.0.217', 'raw:192.168.0.217:5025', '',                                                         '' ] ]
Func __viScanList($aIpList)

	Local Const $iRetries = 1
	Local $iCount = UBound($aIpList)
	Local $iN = $iCount - 1
	Local $aPIDs[$iCount]                   ; To track process IDs
	Local $aDevs[$iCount][4]                ; resulting list
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
		$aDevs[$i][3] = ''                  ; classification
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
	Local $i, $iN = UBound($aTable, 1) - 1
	For $i = 0 To $iN
		$aTable[$i][3] = __viClassifyItem($aTable[$i][2])
	Next
EndFunc   ;==>__viClassifyList



Func __viClassifyItem($sid)
	Local $stype = ""
	If StringInStr($sid, ",MSO") Or StringInStr($sid, ",DPO") Then
		$stype = "Oscilloscope"
	ElseIf StringInStr($sid, ",F4T") Or StringInStr($sid, ",F4T") Then
		$stype = "Chamber"
	ElseIf StringInStr($sid, ",5323") Or StringInStr($sid, ",5313") Then
		$stype = "Frequency Counter"
	ElseIf StringInStr($sid, ",N670") Or StringInStr($sid, ",E363") Then
		$stype = "DC Power Supply"
	EndIf
	Return $stype
EndFunc   ;==>__viClassifyItem




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



; task:		populate an IP address selection box from the list of found Visa devices in $g_aFoundVisaDevices
; in:		$cIpAddr = gui control handle for combo box
;			$filter = filter string, one of the following
;				Chamber
;				DC Power Supply
;				Oscilloscope
;				Frequency Counter
;				blank to include everything
; out:		combo box populated with list
;			the list of items in the combo box
Func __viScanPopulateComboBox($cIpAddr, $sFilter)
	;If Not __IsComboBox($cIpAddr) Then Return
	If Not IsArray($g_aFoundVisaDevices) Then Return
	If UBound($g_aFoundVisaDevices, 0) <> 2 Then Return
	If UBound($g_aFoundVisaDevices, 2) < 4 Then Return

	Local $s = "", $sf = "", $st
	Local $i, $t, $N = UBound($g_aFoundVisaDevices, 1) - 1
	For $i = 0 To $N
		$t = $g_aFoundVisaDevices[$i][3]
		If ($t = $sFilter) Or ($t = "") Or ($sFilter = "") Then
			$st = $g_aFoundVisaDevices[$i][0] & " " & $g_aFoundVisaDevices[$i][2]
			If $sf = "" Then $sf = $st
			$s &= "|" & $st
		EndIf
	Next
	$st = GUICtrlRead($cIpAddr)
	If $st = '' Then $st = $sf
	GUICtrlSetData($cIpAddr, $s, $sf)
	Return $s
EndFunc   ;==>__viScanPopulateComboBox



Func __viAddFoundVisaDevice($sIpAddr)                               ; Add IP address to the list of found devices
	Local $a[0][4]
	If Not IsArray($g_aFoundVisaDevices) Then $g_aFoundVisaDevices = $a
	If UBound($g_aFoundVisaDevices, 0) <> 2 Then $g_aFoundVisaDevices = $a
	If UBound($g_aFoundVisaDevices, 2) < 4 Then $g_aFoundVisaDevices = $a
	Local $i, $N = UBound($g_aFoundVisaDevices, 1) - 1, $m = UBound($g_aFoundVisaDevices, 2)
	For $i = 0 To $N
		If $g_aFoundVisaDevices[$i][0] = $sIpAddr Then Return       ; if found in list then done, nothing to add
	Next
	$N += 1                                                         ; if not found in list then add it to the list
	ReDim $g_aFoundVisaDevices[$N + 1][$m]
	$g_aFoundVisaDevices[$N][0] = $sIpAddr
EndFunc   ;==>__viAddFoundVisaDevice



Func __viGetIP($cIpAddr)                                            ; get the selected ip address from a combo box
	;If Not __IsComboBox($cIpAddr) Then Return ''
	Local $sIpAddr = GUICtrlRead($cIpAddr)
	Local $iPos = StringInStr($sIpAddr, " ")
	If $iPos > 0 Then $sIpAddr = StringLeft($sIpAddr, $iPos - 1)
	Return $sIpAddr
EndFunc   ;==>__viGetIP


Global $g_configFile

Func __viSaveIP($cIpAddr, $configSection)                                                                   ; Save ip address to config file
	__viAddFoundVisaDevice(__viGetIP($cIpAddr))                                                             ; ensure selected ip is in the global list
	IniWrite($g_configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($cIpAddr))               ; IP address list
	IniWrite($g_configFile, $configSection, "IpAddr", GUICtrlRead($cIpAddr))                                ; IP address of VISA device
EndFunc   ;==>__viSaveIP

Func __viLoadIP($cIpAddr, $configSection)                                                                   ; Load ip address from config file
	GUICtrlSetData($cIpAddr, "|" & _
			IniRead($g_configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($cIpAddr)), _     ; IP address list
			IniRead($g_configFile, $configSection, "IpAddr", GUICtrlRead($cIpAddr)))                        ; IP address list
EndFunc   ;==>__viLoadIP




Func __viGUISetID($cDevID, $sid)
	GUICtrlSetData($cDevID, $sid)
	_GUICtrlEdit_SetSel($cDevID, 0, 0)
EndFunc   ;==>__viGUISetID



Func __viGUIGetID($cDevID, $cIpAddr, $sPre = '')
	GUICtrlSetData($cDevID, "Checking...")
	Local $viSession = $sPre & __viGetIP($cIpAddr)
	Local $sid = __viGetID($viSession)
	__viGUISetID($cDevID, ($sid = '') ? 'Not Found' : $sid)
	Return $sid
EndFunc   ;==>__viGUIGetID


