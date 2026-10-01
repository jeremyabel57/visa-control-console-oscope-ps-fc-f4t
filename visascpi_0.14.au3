#include-once

#comments-start

visa library usage

visa ip address format:
   [raw:]ip[:port]
   if port not given, then it will be replaced with 5025 or instr depending on the protocol
   specify "raw:" prefix to use raw socket instead of visa32.dll VXI-11 protocol

functions:
	__viReq($viSession, $sReq, $iTimeoutMS=1000)
		$viSession = ip address or a session handle variable
			if this is just an ip address, then a session is opened, communication commences, and the session is closed
			if this is a session handle, then the communication is performed but the session connection is left open
		$sReq = visa/scpi request/command string
		$iTimeoutMS = timeout in milliseconds to wait for response (-1 = do not wait)
		returns response string or binary data from visa device, otherwise returns empty string ("")
	__viCmd($viSession, $sCmd)
		same as __viReq except do not wait for a response ($iTimeoutMS = -1)

	__viBegin($viSession)
		starts a visa session, or confirms one is open
		$viSession = ip address or a session handle
		returns 1 if successful, 0 if failure
	__viEnd($viSession)
		if the close flag of the vSession is set, then
			close a visa session
			converts $viSession from a session handle back to the ip address string




#comments-end
Global $g_visa_debug = 0
;$g_visa_debug = 1

;#include <Debug.au3>


Global $g_visa_timeout = 30000                        ; default 30 seconds timeout for visa

#include "general.au3"


; ==============================================================================
; SCPI/VISA functions
;


; README:
;
;  * include this before your main routine, it has a function that must be called before anything else
;

#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <StringConstants.au3>
#include <AutoItConstants.au3>
#include <Array.au3>
;#include <GuiScrollBars.au3>
;#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>
;#include <File.au3>
;#include <WinAPISys.au3>
;#include <WinAPIGdi.au3>
;#include <Visa.au3>

Global Const $WS_SYSTEMMENU = 0x00080000

Global Const $VI_NOWAIT = -1        ; tell __viReq that we do not need a response

Global Const $VI_MODE_VXI = 0        ; use VXI-11 communications
Global Const $VI_MODE_RAW = 1        ; use raw socket communications

Global Const $VI_NORETRY = 0        ; do not retry
Global Const $VI_RETRY = 1            ; do retry

; visa session handle object (array)
Global Const $_VIipAddr = 0         ; [0] = IP address
Global Const $_VIipPort = 1         ; [1] = port
Global Const $_VImode = 2           ; [2] = mode/protocol (0=VXI-11, 1=raw socket)
Global Const $_VIaddr = 3           ; [3] = VISA address format:  TCPIP0::ipAddress::portNumber::mode   (mode: INSTR=VXI-11, SOCKET=raw)
Global Const $_VIhSession = 4       ; [4] = session handle if VXI-11, or socket handle if raw
Global Const $_VIstate = 5          ; [5] = session state (0=closed, 1=open)
Global Const $_VIrm = 6             ; [6] = session/resource manager handle
Global Const $_VIdll = 7            ; [7] = handle to the visa.dll file (DllOpen, DllClose)
Global Const $_VIclose = 8            ; [8] = 1 if this handle was originally an ip address and is to be closed when done, otherwise 0 to leave it open
Global Const $_VIsize = 9           ; number of items in this array

Global $g_hVisaResourceManager = 0    ; handle of visa resource manager


Global Const $VISAERR = ":SYST:ERR?"
Global Const $VI_REQ_ERR = ":SYST:ERR?"
Global Const $VI_IDN = "*IDN?"
Global Const $VI_CLS = "*CLS"
Global Const $VI_RST = "*RST"



#include "vi_script.au3"


; ==============================================================================
; VISA functions that call the dll directly
;
; this includes functions to open the Resource Manager






__viScanSubnetRunFirst()                                ; catch callbacks for parallel visa IDN scanning

TCPNameToIP("127.0.0.1")                                ; ensure TCP has been initialized
If @error = 10093 Then TCPStartup()


OnAutoItExitRegister("__viExit")                        ; cleanup on exit


Func __viExit()                                            ; call this before exiting main script
	If $g_hVisaResourceManager <> 0 Then __viCloseRM($g_hVisaResourceManager)    ; close resource manager session
	TCPShutdown()                                       ; close TCP resources
EndFunc   ;==>__viExit


; --- end of main init


;-------------------------------------
; VISA/SCPI functions


Global $g_bCommValid = 0        ; flag to indicate last visa communications were good







;------------------------------------------------
; visa begin, end, request, and command functions





;			update global flag when visa communications fail
Func __viFellOffline()
	$g_bCommValid = 0
EndFunc   ;==>__viFellOffline



;			__viBegin
; task:		start a visa transaction with a network device
; in:		$viSession = ip address [: port number]
;				prefix with "raw:" to use raw socket mode instead of vxi-11 communication protocol
;			$viSession can be an already existing session handle, in which case it attempts to ensure it is open
; out:		$viSession will be replaced with an visa session handle (array)
;			return 1 if successful, 0 if failed
Func __viBegin(ByRef $viSession)
	$g_bCommValid = 1
	If $g_visa_debug > 1 Then ConsoleWrite("__viBegin(" & $viSession & ")" & @CRLF)
	If IsArray($viSession) Then Return __viConfirmOpen($viSession)    ; if $viSession is an array, then assume it is an existing session handle
	If __viOpen($viSession, 1) Then
		If $g_visa_debug > 1 Then __viConsoleWriteArray("__viBegin: viSession", $viSession)
		Return 1                          ; otherwise open a new session with the ip address, set close flag=1
	EndIf
	__viFellOffline()
	Return SetError(-1, 0, 0)
EndFunc   ;==>__viBegin



;			close a visa session
Func __viEnd(ByRef $viSession)
	If Not IsArray($viSession) Then Return
	If Not $viSession[$_VIclose] Then Return
	__viClose($viSession)                             ; close session
	;__viConsoleWriteArray("__viEnd: viSession", $viSession)
	__viBreakHandle($viSession)
EndFunc   ;==>__viEnd




;			__viReq
; task:		send a request  and get response
; in:		$viSession = session handle or ip address/port/raw
;			$sReq = request to send
;			$iTimeoutMS = timeout when waiting for response
;				if timeout is -1 then do not wait for, nor read a response
;			$retry = true to retry on error
; out:		response string received
Func __viReq(ByRef $viSession, $sReq, $iTimeoutMS = 1500, $retry = 1)
	Local $sRet, $iErr
	If Not __viBegin($viSession) Then Return SetError(-1, 0, "")
	If ($iTimeoutMS > 0) And Not $viSession[$_VImode] Then __viSetTimeout($viSession, $iTimeoutMS)
	If Not __viReqSend($viSession, $sReq, $iTimeoutMS, $retry) Then Return SetError(-1, @error, "")
	Sleep(10)        ; give time for visa device to start processing command and return response
	If $iTimeoutMS <= 0 Then Return ""            ; no response required, do not wait for one
	$sRet = __viRead($viSession, -1, $iTimeoutMS)
	$iErr = @error
	If $g_visa_debug Then ConsoleWrite("__viReq req=" & $sReq & ", resp=" & $sRet & @CRLF)
	If $iErr Then
		If $retry Then
			__viClose($viSession)
			Sleep(50)
			Return __viReq($viSession, $sReq, $iTimeoutMS, $VI_NORETRY)
		Else
			__viEnd($viSession)
			Return SetError($iErr, 0, "")
		EndIf
	EndIf
	__viEnd($viSession)
	Return $sRet
EndFunc   ;==>__viReq

; task:		helper function for __viReq - write request to visa target
Func __viReqSend(ByRef $viSession, $sReq, $iTimeoutMS = 1500, $retry = 1)
	__viWrite($viSession, $sReq)                                     ; send request
	If @error Then
		If $retry Then
			__viClose($viSession)                                        ; attempt to close and reopen the tcp socket
			Sleep(50)
			Return __viReqSend($viSession, $sReq, $iTimeoutMS, $VI_NORETRY)
		Else
			Return SetError(@error, 0, 0)
		EndIf
	EndIf
	Return 1
EndFunc   ;==>__viReqSend


;			__viCmd - send a command and do not wait for a response
; out:		returns 0 if successful, or @error
Func __viCmd(ByRef $viSession, $sCmd, $retry = 1)
	__viReq($viSession, $sCmd, $VI_NOWAIT, $retry)
	Return @error
EndFunc   ;==>__viCmd

Func __viExecCommand(ByRef $viSession, $sReq, $iTimeoutMS = 1500, $retry = 1)            ; legacy function name
	Local $sRet = __viReq($viSession, $sReq, $iTimeoutMS, $retry)
	If @error Then Return SetError(@error, @extended, $sRet)
	Return $sRet
EndFunc   ;==>__viExecCommand







; ------------------------------------------------
; screen shot and picture parsing functions




;			__viSaveScreenShot
; task:		grab screenshot and save it to file
; in:		$viSession = ipAddr or visa session handle
;			$sFile = path and name of destination file
;			$aCmds = commands to send visa device in order to start the download
;				each command is [ $sCmd, $iTimeout ]
;			$iTimeoutMS = timeout
;			$UX = true to display any message boxes, 0 = no user interaction, quiet
; out:		1 if successful, 0 if error
Func __viSaveScreenShot(ByRef $viSession, ByRef $sFile, $aCmds, $iTimeoutMS = 15000, $UX = 1)
	$sFile = __FileNameAutoIncrement($sFile)                            ; $sFile is also modified (passed byref)
	If Not __viBegin($viSession) Then Return SetError(-1, @error, 0)      ; open visa session
	__viSetTimeout($viSession, $iTimeoutMS)
	Local $i
	For $i = 0 To UBound($aCmds) - 1                                      ; send commands to device
		If $g_visa_debug Then ConsoleWrite("__viSaveScreenShot: cmd=" & $aCmds[$i][0] & ", timeout=" & $aCmds[$i][1] & @CRLF)
		__viReq($viSession, $aCmds[$i][0], $aCmds[$i][1])
		Sleep(200)
	Next
	Local $bData = __viReadBinary($viSession, -1, 20000)                            ; download the file data from the device
	__viEnd($viSession)

	If $g_visa_debug > 1 Then ConsoleWrite("__viSaveScreenShot: received bData len=" & BinaryLen($bData) & @CRLF)

	Local $sExt = ".dat"
	$bData = __viParsePicture($bData, $sExt)                                ; strip any remaining header from file data and identify the file extension

	If $g_visa_debug > 1 Then ConsoleWrite("__viSaveScreenShot: parsed bData len=" & BinaryLen($bData) & @CRLF)

	Local $sDrive, $sDir, $sName, $sExt                                        ; Write the clean binary stream out to file
	_PathSplit($sFile, $sDrive, $sDir, $sName, $sExt)
	Local $sSaveFile = $sDrive & $sDir & $sName & $sExt
	Local $hFile = FileOpen($sSaveFile, 2 + 16)
	If $hFile < 0 Then
		If $UX Then MsgBox(64, "Error", "Something went wrong, did not save screen shot to " & @CRLF & @CRLF & $sSaveFile)
		Return SetError($hFile, 0, 0)
	EndIf

	FileWrite($hFile, $bData)
	FileClose($hFile)
	$sFile = $sSaveFile

	Return 1
EndFunc   ;==>__viSaveScreenShot



; task:		strip header from data stream leaving only the picture file
; in:		$bData = binary data stream
;			$sExt = variable to store file name extension return
; out:		binary data of just the picture file, or the original buffer
;			$sExt = file extension (.png or .gif).  or unchanged if no png or gif found in data
Func __viParsePicture($bData, ByRef $sExt)
	Local $iByteStartOffset = 0

	; 1. Convert to a standard text string representation for accurate character indexing
	Local $sHexText = String($bData)

	Local $iGifPos = StringInStr($sHexText, "474946383761", 1) ; Hex for GIF87a
	Local $iPngPos = StringInStr($sHexText, "89504E47", 1) ; Hex for PNG
	Local $iBmpPos = StringInStr($sHexText, "424D", 1) ; Hex for BM - BMP files

	; 2. Correct the offset calculation from Hex String text length to raw Byte length
	If $iGifPos > 0 Then
		$sExt = ".gif"
		; Formula: Remove the "0x" (2 chars), divide text characters by 2 to get bytes, add 1 for 1-based index
		$iByteStartOffset = (($iGifPos - 3) / 2) + 1
	ElseIf $iPngPos > 0 Then
		$sExt = ".png"
		$iByteStartOffset = (($iPngPos - 3) / 2) + 1
	ElseIf $iBmpPos > 0 Then
		$sExt = ".bmp"
		$iByteStartOffset = (($iBmpPos - 3) / 2) + 1
	EndIf

	; 3. Safely slice the binary data using the true byte index position
	If $iByteStartOffset > 0 Then $bData = BinaryMid($bData, $iByteStartOffset)

	Return $bData
EndFunc   ;==>__viParsePicture





; -----------------------------
; visa read ID (*IDN?)



;			__viReadIDprot
; task:		try various protocols to communicate with instrument and get its ID
; in:		$viSession = the IP address of the instrument or a viSession handle
; out:		response string from VISA *IDN? request
;			if $viSession is just the IP address, then it is changed to a viSession handle,
;			 the successful protocol is stored in $viSession[$_VImode] and $viSession[$_VIaddr], and
;			 the session is closed
Func __viReadIDprot(ByRef $viSession, $iTimeoutMS = 1100)
	Local $sRet, $sAddr, $sTaddr, $iErr

	If $g_visa_debug > 1 Then ConsoleWrite("__viReadIDprot" & @CRLF)
	If IsArray($viSession) Then                                                    ; if visession handle given then do the *IDN? request
		;If $g_visa_debug Then ConsoleWrite("__viReadIDprot: __viFlushInputBuffer" & @CRLF)
		__viFlushInputBuffer($viSession)
		;If $g_visa_debug Then ConsoleWrite("__viReadIDprot: __viReq(..., *IDN?, ...)" & @CRLF)
		$sRet = __viReq($viSession, $VI_IDN, $iTimeoutMS, $VI_NORETRY)
		If Not @error Then Return $sRet
		$viSession[$_VImode] = 1 - $viSession[$_VImode]                                ; otherwise toggle communication protocol mode and try again
		$sRet = __viReq($viSession, $VI_IDN, $iTimeoutMS, $VI_NORETRY)
		If Not @error Then Return $sRet
		Return SetError(@error, @extended, $sRet)
	EndIf

	If $g_visa_debug > 1 Then ConsoleWrite("__viReadIDprot: __viBegin(" & $viSession & ")" & @CRLF)
	$iErr = Not __viBegin($viSession)
	$viSession[$_VIclose] = 0                                                        ; reset close flag to 0
	If Not $iErr Then                                                            ; if open VXI-11 worked, then do IDN querry
		__viFlushInputBuffer($viSession)
		$sRet = __viReq($viSession, $VI_IDN, $iTimeoutMS, $VI_NORETRY)                ; attempt to use VXI-11 protocol
		$iErr = @error
		If Not $iErr Then
			__viClose($viSession)
			Return $sRet                                                                ; if successful then return response
		EndIf
	EndIf

	;If $g_visa_debug > 1 Then __viConsoleWriteArray("__viReadIDprot: __viToggleMode viSession", $viSession)
	__viToggleMode($viSession)                                                ; try the other protocol mode
	;If $g_visa_debug > 1 Then __viConsoleWriteArray("__viReadIDprot: __viToggleMode viSession", $viSession)

	$iErr = Not __viOpen($viSession)
	If Not $iErr Then
		$sRet = __viReq($viSession, $VI_IDN, $iTimeoutMS, $VI_NORETRY)                ; attempt to use raw socket protocol
		$iErr = @error
		__viClose($viSession)
	EndIf
	If $iErr Then Return SetError(-1, 0, "")
	Return $sRet
EndFunc   ;==>__viReadIDprot



;			__viReadID
; task:		send *IDN? request and return results
Func __viReadID(ByRef $viSession, $iTimeoutMS = 1000)
	If Not __viBegin($viSession) Then Return SetError(-1, 0, "")
	Local $sRet = __viReq($viSession, $VI_IDN, $iTimeoutMS, $VI_NORETRY)                ; attempt to use VXI-11 protocol
	Local $iErr = @error
	__viEnd($viSession)
	If $iErr Then Return SetError($iErr, 0, "")
	Return $sRet
EndFunc   ;==>__viReadID



;			__viGetID
; task:		read ID from visa device using just the IP address, try both raw socket and VXI-11 protocols
; in:		$sIpAddr
; out:		ID string or empty if error
Func __viGetID($sIpAddr)
	;Local $sIP = $sIpAddr
	If $g_visa_debug > 1 Then ConsoleWrite("__viGetID: " & $sIpAddr & @CRLF)
	Local $sR = __viReadIDprot($sIpAddr)
	Local $iErr = @error
	If $g_visa_debug > 1 Then ConsoleWrite("__viGetID: " & $sIpAddr & @CRLF)
	$sIpAddr[$_VIclose] = 1
	__viEnd($sIpAddr)
	If $iErr Then Return SetError($iErr, 0, $sR)
	Return $sR
EndFunc   ;==>__viGetID




; ------------------------------------
; parsing functions




; ====================================================================================================
; Function Name:    __viParseAddress
; Description:      Parses a VISA descriptor string using pure string manipulation and arrays.
; Parameter(s):     $sVisaString - The raw VISA string (e.g. "TCPIP0::192.168.1.100::5025::SOCKET")
; Return Value(s):  Success - Returns a 1D array with 5 elements:
;                             [0] = Interface Type (e.g., TCPIP0)
;                             [1] = Address / IP / Hostname
;                             [2] = Port / Secondary Address (Returns "Default" if missing)
;                             [3] = Resource Type (e.g., SOCKET, INSTR)
;                             [4] = Is Raw Socket? (True / False boolean)
;                   Failure - returns the original string in element 0 of the result array
; ====================================================================================================
Func __viParseVisaAddress($sVisaString)
	; Split the string using the "::" delimiter tokens
	Local $aSplit = StringSplit($sVisaString, "::", 1 + 2)     ; 1 = case sensitive, 2 = disable count element
	Local $iCount = UBound($aSplit)
	Local $aOutput[5]                ; Create a fixed 5-element output array to return the standardized structure
	If $iCount >= 4 Then            ; Standard VISA strings with an explicit port (like raw sockets) split into 4 pieces
		$aOutput[0] = $aSplit[0]     ; Interface
		$aOutput[1] = $aSplit[1]     ; Address/IP
		$aOutput[2] = $aSplit[2]     ; Port
		$aOutput[3] = $aSplit[3]     ; Resource Type
	ElseIf $iCount == 3 Then        ; Standard VISA strings without an explicit port (like VXI-11 INSTR) split into 3 pieces
		$aOutput[0] = $aSplit[0]     ; Interface
		$aOutput[1] = $aSplit[1]     ; Address/IP
		$aOutput[2] = "5025"          ; No port specified, use default
		$aOutput[3] = $aSplit[2]     ; Resource Type
	Else                            ; not able to parse
		$aOutput[0] = $sVisaString
		$aOutput[1] = ""
		$aOutput[2] = ""
		$aOutput[3] = ""
	EndIf
	$aOutput[4] = (StringUpper($aOutput[3]) == "SOCKET")    ; Evaluate whether the target connection utilizes raw sockets
	Return $aOutput
EndFunc   ;==>__viParseVisaAddress



;			_viParseIPaddress
; task:		parse IP address and port number from input
;			IP:Port
; in:		$ipAddr = IP address and Port number separated by a colon :
;			$defPort = default port to use if no port number found in $ipAddr
; out:		[0] = IP address
;			[1] = port number or default if not specified
;			[3] = 1 if "raw:" prefix found, or 0
Func __viParseIPaddress($ipAddr, $defPort = 0)
	Local $aIP[3]
	$aIP[2] = (StringLower(StringLeft($ipAddr, 4)) = "raw:") ? 1 : 0
	If $aIP[2] Then $ipAddr = StringTrimLeft($ipAddr, 4)
	Local $iPos = StringInStr($ipAddr, ":")
	If $iPos Then
		$aIP[0] = StringLeft($ipAddr, $iPos - 1)
		$aIP[1] = StringMid($ipAddr, $iPos + 1)
	Else
		$aIP[0] = $ipAddr
		$aIP[1] = $defPort
	EndIf
	Return $aIP
EndFunc   ;==>__viParseIPaddress



;			__viMakeAddress
; task:		generate VISA device address from an IP address
; in:		$ipAddr = IP address
;			$iMode = mode (0 = standard VXI-11, 1 = raw socket)
;			$iPort = port number to use for raw socket mode
; out:		VISA address string (TCPIP0::...)
Func __viMakeAddress($ipAddr, $iMode = 0, $iPort = "")
	If $iMode Then
		Return "TCPIP::" & $ipAddr & "::" & (($iPort = "") ? "5025" : $iPort) & "::SOCKET"
	Else
		Return "TCPIP0::" & $ipAddr & "::" & (($iPort = "") ? "inst0" : $iPort) & "::INSTR"
	EndIf
EndFunc   ;==>__viMakeAddress




; ------------------------------------
; open/close functions




;			___viOpenDefaultRM
; task:		initialize the VISA Resource Manager
; in:		$viSession = visa session array handle
; out:		1 if successful, 0 if error
Func ___viOpenDefaultRM(ByRef $viSession)
	;_ArrayDisplay($aSession)
	If Not (Number($viSession[$_VIrm]) = 0) Then __viCloseRM($viSession)
	__viCheckDLLhandle($viSession)
	Local $aResult = DllCall($viSession[$_VIdll], "long", "viOpenDefaultRM", "ulong*", 0)
	If @error Then
		ConsoleWrite("ERROR: 'visa32.dll' not found. Ensure NI-VISA runtime is installed." & @CRLF)
		Return SetError(@error, 0, 0)
	EndIf
	Local $iStatus = $aResult[0]
	If $iStatus < 0 Then
		ConsoleWrite("ERROR: Could not open Default Resource Manager. Status: 0x" & Hex($iStatus) & @CRLF)
		Return SetError($iStatus, 0, 0)
	EndIf
	$viSession[$_VIrm] = $aResult[1]
	$g_hVisaResourceManager = $viSession[$_VIrm]
	Return 1
EndFunc   ;==>___viOpenDefaultRM



;			__viCloseRM
; task:		close session manager
; in:		$viSession = visa session handle (array) or RM handle (number)
; out:		none
Func __viCloseRM(ByRef $viSession)
	Local $hRM
	If IsArray($viSession) Then
		$hRM = $viSession[$_VIrm]
	Else
		$hRM = $viSession
	EndIf
	If $hRM = 0 Then Return 1
	DllCall("visa32.dll", "long", "viClose", "ulong", $hRM)
	;If @error Then Return SetError(@error, @extended, 0)
	If $hRM = $g_hVisaResourceManager Then $g_hVisaResourceManager = 0
	If IsArray($viSession) Then
		$viSession[$_VIrm] = 0
	Else
		$viSession = 0
	EndIf
	Return 1
EndFunc   ;==>__viCloseRM




;			__viMakeHandle
; task:		if needed, convert $viSession from an ip address to a session array handle
; in:		$viSession = session handle or ip address/port
;			ip address string format: [raw:]IP[:port]
Func __viMakeHandle(ByRef $viSession, $bClose = 0)
	If IsArray($viSession) Then Return
	Local $sIpAddr = $viSession
	Local $iMode = $VI_MODE_VXI
	If StringLower(StringLeft($sIpAddr, 4)) = "raw:" Then
		$iMode = $VI_MODE_RAW
		$sIpAddr = StringTrimLeft($sIpAddr, 4)
	EndIf
	Local $a1 = __viParseIPaddress($sIpAddr, "")                                    ; parse IP address for port number
	$sIpPort = $a1[1]
	$sIpAddr = $a1[0]
	If $sIpPort = "" Then $sIpPort = ($iMode ? 5025 : "inst0")

	; create $viSession structure
	Local $aSession[$_VIsize]
	$aSession[$_VIipAddr] = $sIpAddr                                             ; IP address
	$aSession[$_VIipPort] = $sIpPort                                             ; IP port
	$aSession[$_VImode] = $iMode                                                 ; protocol VXI-11 or raw
	$aSession[$_VIaddr] = __viMakeAddress($sIpAddr, $iMode, $sIpPort)            ; VISA address string
	$aSession[$_VIhSession] = 0                                                  ; session handle
	$aSession[$_VIstate] = 0                                                     ; connection state
	$aSession[$_VIrm] = $g_hVisaResourceManager                                     ; resource manager
	$aSession[$_VIdll] = 0                                                       ; handle for the dll file
	$aSession[$_VIclose] = $bClose                                               ; flag to close session when done or leave it open
	$viSession = $aSession
EndFunc   ;==>__viMakeHandle



;			__viBreakHandle
; task:		convert session handle back into ip adddress string
Func __viBreakHandle(ByRef $viSession)
	If Not IsArray($viSession) Then Return
	Local $sP = $viSession[$_VIipPort]                ; convert $viSession back into an ip address string
	Local $sIP = $viSession[$_VIipAddr]
	Local $raw = ($viSession[$_VImode] ? "raw:" : "")
	If StringLower(StringLeft($sIP, 4)) = "raw:" Then $sIP = StringTrimLeft($sIP, 4)
	If StringLower($sP) = "inst0" Or $sP = "5025" Then $sP = ""
	If Not $sP = "" Then $sP = ":" & $sP
	$viSession = $raw & $sIP & $sP
EndFunc   ;==>__viBreakHandle



;			__viToggleMode
; task:		toggle between raw and vxi-11 mode
; in:		$viSession = session handle or ip address
;			if $viSession is an ip address it will be changed to a session handle
Func __viToggleMode(ByRef $viSession)
	__viMakeHandle($viSession)                                                                  ; ensure $viSession is a handle array
	If $viSession[$_VIstate] Or $viSession[$_VIhSession] Then __viClose($viSession)             ; if session is open, then close it
	Local $iMode = 1 - $viSession[$_VImode]                                                     ; toggle communication protocol mode
	$viSession[$_VImode] = $iMode
	Local $sIpPort = $viSession[$_VIipPort]                                                     ; toggle port number between inst0 and 5025, unless custom port number specified
	If $iMode Then
		If Not StringIsDigit($sIpPort) Then $sIpPort = 5025
	Else
		If $sIpPort = 5025 Then $sIpPort = "inst0"
	EndIf
	$viSession[$_VIipPort] = $sIpPort
	$viSession[$_VIaddr] = __viMakeAddress($viSession[$_VIipAddr], $iMode, $sIpPort)            ; VISA address string
EndFunc   ;==>__viToggleMode




;			__viOpen
; task:		open the connection to the VISA instrument
;			if it is already open, then close it and reopen
; in:		$viSession = visa session handle to store the session information or a string with the ip address
;			$bClose = close flag, 1=close when done, 0 = keep open
; out:		1 if successful, 0 if failure
Func __viOpen(ByRef $viSession, $bClose = 0, $retry = 1)
	If Not IsArray($viSession) Then        ; $viSession is already a session handle
		__viMakeHandle($viSession, $bClose)
		If $g_visa_debug Then __viConsoleWriteArray("__viOpen: viSession", $viSession)
		;MsgBox(0, "hi", "hi")
		If Not $viSession[$_VImode] Then                                                ; if using visa32.dll then initialize a few things
			__viSetEOLchar($viSession, 0x0A)
			__viSetEOLenable($viSession, 1)
			__viSetTimeout($viSession, $g_visa_timeout)
		EndIf
	EndIf

	If $viSession[$_VIstate] Or $viSession[$_VIhSession] Then                                                      ; if previous session open, then close it
		__viClose($viSession)
		Sleep(50)
	EndIf
	If $viSession[$_VImode] Then                                                         ; if raw socket mode then
		If $viSession[$_VIipPort] = "inst0" Then $viSession[$_VIipPort] = 5025
		Local $hSocket = TCPConnect($viSession[$_VIipAddr], $viSession[$_VIipPort])       ; Connect to the raw TCP Socket
		If @error = 10093 Then
			TCPStartup()                                                                ; if tcp not started yet, then start it and try to connect again
			Sleep(50)
			$hSocket = TCPConnect($viSession[$_VIipAddr], $viSession[$_VIipPort])
		EndIf
		If @error Then Return SetError(@error, @extended, 0)                            ; return 0 if error
		$viSession[$_VIhSession] = $hSocket
	Else                                                                                ; else we are using VXI-11 protocol
		__viCheckRMhandle($viSession)
		Local $aResult = __viOpenDllCall($viSession)
		Local $iStatus = $aResult[0]
		If $g_visa_debug Then __viConsoleWriteArray("__viOpenVXI: viSession", $viSession)
		If $g_visa_debug Then __viConsoleWriteArray("__viOpenVXI: viOpenDllCall", $aResult)
		If $iStatus = 0xBFFF000E Then                                                            ; if error is RM not opened, then
			__viCheckRMhandle($viSession)
			$aResult = __viOpenDllCall($viSession)                                                ; retry opening the visa session
			$iStatus = $aResult[0]
			If $g_visa_debug Then __viConsoleWriteArray("BFFF000E __viOpenVXI: viSession", $viSession)
			If $g_visa_debug Then __viConsoleWriteArray("BFFF000E __viOpenVXI: viOpenDllCall", $aResult)
		EndIf
		If $g_visa_debug Then
			If $iStatus = 0xBFFF003C Then ConsoleWrite("__viOpen: VI_ERROR_ALLOC " & Hex($iStatus) & " out of resources" & @CRLF)
			If $iStatus = 0xBFFF000E Then ConsoleWrite("__viOpen: VI_ERROR_INV_OBJECT " & Hex($iStatus) & " invalid object " & @CRLF)
		EndIf
		If $iStatus < 0 Then Return SetError($iStatus, 0, 0)                              ; return 0 if error
		$viSession[$_VIhSession] = $aResult[5]                                               ; Index 5 corresponds to the final pointer parameter
	EndIf
	$viSession[$_VIstate] = 1                                                            ; successfully connected the session
	Return 1
EndFunc   ;==>__viOpen

Func __viOpenDllCall($viSession)
	; ViStatus viOpen(ViSession rm_session, ViRsrc rsrcName, ViAccessMode accessMode, ViUInt32 timeout, ViSession *vi_session);
	Local $aRet = DllCall($viSession[$_VIdll], "long", "viOpen", _               ; _viOpen dll call
			"ulong", $viSession[$_VIrm], _                                       ; Resource Manager Handle
			"str", $viSession[$_VIaddr], _                                       ; VISA address Resource String
			"ulong", 0, _                                                       ; Access Mode (0 = Default)
			"ulong", 0, _                                                       ; Timeout (0 = Default)
			"ulong*", 0)                                                        ; Dereferenced variable pointer to receive the Device Handle
	If @error Then Return SetError(@error, @extended, $aRet)
	Return $aRet
EndFunc   ;==>__viOpenDllCall



; task:		check RM and dll handles in viSession
;			if handles are 0 or expired, then reopen
Func __viCheckDLLhandle(ByRef $viSession)
	If $viSession[$_VImode] Then Return                                 ; does not apply to raw socket communication protocol
	If __WinAPI_IsDllHandleValid($viSession[$_VIdll]) Then Return       ; if valid then no further action needed
	$viSession[$_VIdll] = DllOpen("visa32.dll")
	If @error Then $viSession[$_VIdll] = "visa32.dll"
EndFunc   ;==>__viCheckDLLhandle

Func __viCheckRMhandle(ByRef $viSession)
	__viCheckDLLhandle($viSession)
	If __viIsResourceManagerValid($viSession[$_VIrm]) Then Return       ; if valid then no further action needed
	If $viSession[$_VIrm] <> $g_hVisaResourceManager Then               ; if not the same as the global RM handle then
		$viSession[$_VIrm] = $g_hVisaResourceManager                    ;   try the global RM handle
		If __viIsResourceManagerValid($viSession[$_VIrm]) Then Return   ;   if valid then no further action needed
	EndIf                                                               ; endif
	___viOpenDefaultRM($viSession)                                      ; open the Resource Manager
EndFunc   ;==>__viCheckRMhandle



;			__viConfirmOpen
; task:		confirm if $aSession is connected/open
; in:		$viSession = visa session handle
; out:		1 if it is open
;			0 if it is not open and we could not reopen it - error
Func __viConfirmOpen(ByRef $viSession)                                  ; check if session is open, reopen if no
	If $viSession[$_VIstate] Then Return 1
	If $g_visa_debug Then ConsoleWrite("__viConfirmOpen(...)" & @CRLF)
	__viOpen($viSession)
	Return ($viSession[$_VIstate] = 0) ? 0 : 1
EndFunc   ;==>__viConfirmOpen



;			__viClose
; task:		close VISA instrument session or Resource Manager session
; in:		$viSession = session handle (array) or file/resource handle (number)
; out:		none
Func __viClose(ByRef $viSession)
	If IsArray($viSession) Then
		If $viSession[$_VIhSession] Then
			If $viSession[$_VImode] Then                                                ; close the socket or visa session handle
				TCPCloseSocket($viSession[$_VIhSession])
			Else
				DllCall($viSession[$_VIdll], "long", "viClose", "ulong", $viSession[$_VIhSession])
			EndIf
		EndIf
		$viSession[$_VIhSession] = 0
		$viSession[$_VIstate] = 0
		If $g_visa_debug Then __viConsoleWriteArray("__viClose: viSession", $viSession)
		If $viSession[$_VIdll] Then                                                    ; close visa32.dll handle
			DllClose($viSession[$_VIdll])
			$viSession[$_VIdll] = 0
		EndIf
	Else                                                                                ; else if not a vSession handle, then
		If $viSession = 0 Then Return 1
		DllCall("visa32.dll", "long", "viClose", "ulong", $viSession)                ;   close given handle by number
		If @error Then Return SetError(@error, @extended, 0)
		$viSession = 0
	EndIf
	Return 1
EndFunc   ;==>__viClose



; ====================================================================================================
; Function Name:    __WinAPI_IsDllHandleValid
; Description:      Queries kernel32.dll directly to check if a DllOpen handle is live and active.
; Parameter(s):     $hDll - The handle returned from DllOpen() to test
; Return Value(s):  True  - The handle is open and valid.
;                   False - The handle is dead, closed, or corrupted.
; ====================================================================================================
Func __WinAPI_IsDllHandleValid($hDll)
	If $hDll = "" Or $hDll = True Or $hDll = False Then Return False            ; sanity checks
	If Number($hDll) = 0 Then Return False
	Local $aRet = DllCall("kernel32.dll", "dword", "GetModuleFileNameW", _      ; Call GetModuleFileNameW. It returns the path string length on success, or 0 on failure.
			"handle", $hDll, _                                                  ;    We provide a tiny 2-character buffer because we only care about the success/failure return status code.
			"wstr", "", _
			"dword", 2)
	If @error Then Return False                                                 ; The DLL call itself failed entirely
	Return ($aRet[0] > 0)                                                       ; If the return value is greater than 0, the handle is valid!
EndFunc   ;==>__WinAPI_IsDllHandleValid



; ====================================================================================================
; Function Name:    _viIsResourceManagerValid
; Description:      Queries visa32.dll to verify if a specific Resource Manager handle is live.
; Parameter(s):     $hRM   - The Resource Manager handle variable to test.
;                   $hDll  - Optional. The opened DLL handle context (or "visa32.dll" string).
; Return Value(s):  True   - The Resource Manager handle is recognized and active.
;                   False  - The handle is closed, invalid, or fake.
; ====================================================================================================
Func __viIsResourceManagerValid($hRM, $hDll = "visa32.dll")
	If $hRM = 0 Or $hRM = "" Or $hRM = True Or $hRM = False Then Return False           ; 1. Early exit if the variable is empty or a structural boolean flag
	If Number($hRM) = 0 Then Return False
	Local Const $VI_ATTR_RSRC_CLASS = 0xBFFF0001                                        ; 2. Define the Resource Class attribute lookup constant (Universally supported read-only query)
	Local $tBuffer = DllStructCreate("char[256]")                                       ; Local buffer allocation to hold string metadata
	Local $aResult = DllCall($hDll, "long:cdecl", "viGetAttribute", _                   ; 3. Call viGetAttribute: Pass the RM handle, requested attribute ID, and output destination buffer
			"ulong", $hRM, _
			"ulong", $VI_ATTR_RSRC_CLASS, _
			"struct*", $tBuffer)
	If @error Then Return False                                                         ; 4. If the call failed structurally (e.g., DLL missing or bad signature structure), fail immediately
	Return ($aResult[0] = 0)                                                            ; 5. Element [0] holds the C function return ViStatus.
	;																					;    Status 0 (VI_SUCCESS) means the VISA backend successfully authenticated the object handle.
EndFunc   ;==>__viIsResourceManagerValid




; -----------------
; debug


Func __viConsoleWriteArray($sName, $a)
	Local $i, $n = UBound($a)
	ConsoleWrite($sName & "[" & $n & "]= [ ")
	If $n > 0 Then
		ConsoleWrite($a[0])
		For $i = 1 To $n - 1
			ConsoleWrite(", " & $a[$i])
		Next
	EndIf
	ConsoleWrite(" ]" & @CRLF)
EndFunc   ;==>__viConsoleWriteArray




; ----------------------------
; visa read/write functions




;			__viWrite
; task:		send data to the VISA instrument
; in:		$viSession = visa session handle
;			$sReq = request/command/data to send
; out:		1 if successful, 0 if error
Func __viWrite(ByRef $viSession, $sReq)
	If Not __viConfirmOpen($viSession) Then Return SetError(-1, 0, 0)
	If Not IsBinary($sReq) Then $sReq &= @CR & @LF                              ; append termination characters
	Local $sR = __viWriteBuf($viSession, $sReq)
	Sleep(1) ; Give the SCPI VISA device time to process the incomming data
	Return $sR
EndFunc   ;==>__viWrite
Func __viWriteBuf(ByRef $viSession, $sReq)
	If $g_visa_debug Then
		ConsoleWrite("__viWrite OUT : '" & $sReq & "', mode=" & $viSession[$_VImode] & @CRLF)
		;__viConsoleWriteArray("viSession", $viSession)
	EndIf

	If $viSession[$_VImode] Then                                                ; raw socket mode
		TCPSend($viSession[$_VIhSession], $sReq)                                ; Send the query over the socket stream
		If @error = 10093 Then
			TCPStartup()    ; start TCP service
			Sleep(50)
			TCPSend($viSession[$_VIhSession], $sReq)
		EndIf
		If @error Then
			__viOpen($viSession)                                                ; reopen session
			TCPSend($viSession[$_VIhSession], $sReq)                            ; Send the query over the socket stream
			If @error Then
				Local $iErr = @error
				__viClose($viSession)
				Sleep(50)
				Return SetError($iErr, 0, 0)
			EndIf
		EndIf

	Else                                                                        ; VXI-11 mode
		Local $iLen = IsBinary($sReq) ? BinaryLen($sReq) : StringLen($sReq)
		Local $tWriteBuffer = DllStructCreate("byte[" & $iLen + 1 & "]")        ; write buffer
		DllStructSetData($tWriteBuffer, 1, $sReq)
		Local $aRet = __viWriteDll($viSession, $tWriteBuffer, $iLen)            ; send $sReq
		Local $iStatus = -1
		If IsArray($aRet) Then $iStatus = $aRet[0]
		If $iStatus < 0 Then                                                    ; if failed to write, then close and reopen the session and try again
			__viOpen($viSession)
			$aRet = __viWriteDll($viSession, $tWriteBuffer, $iLen)
			Local $iStatus = -1
			If IsArray($aRet) Then $iStatus = $aRet[0]
			If $iStatus < 0 Then
				__viClose($viSession)
				Return SetError($iStatus, 0, 0)
			EndIf
		EndIf
	EndIf

	Return 1
EndFunc   ;==>__viWriteBuf

Func __viWriteDll(ByRef $viSession, ByRef $tBuf, $iLen)
	; ViStatus viWrite(ViSession vi, ViBuf buf, ViUInt32 count, ViPUInt32 retCount);
	Local $aRet = DllCall($viSession[$_VIdll], "long", "viWrite", _
			"ulong", $viSession[$_VIhSession], _
			"struct*", $tBuf, _
			"ulong", $iLen, _
			"ulong*", 0)     ; Number of bytes actually written (ignored here)
	If @error Then Return SetError(@error, @extended, $aRet)
	Return $aRet
EndFunc   ;==>__viWriteDll







;			__viRead
; task:		blocking read of response from visa device
; in:		$viSession = session handle
;			$iMaxLen = max number of bytes to read
;			$iTimeoutMS = timeout in milliseconds
;			$bBinary = 0 to return a string response (stripping EOL and white spaces)
;					   1 to return raw binary data
; out:		if response is a EOL terminated string (default) then the string (with EOL stripped) is returned
;			if response begins with #Lnnnn... (IEEE 488.2) then the binary block of data is fully read and returned as a binary object
Func __viRead(ByRef $viSession, $iMaxLen = 10 * 1024 * 1024, $iTimeoutMS = 1000, $bBinary = 0)
	If $iMaxLen < 0 Then $iMaxLen = 10 * 1024 * 1024                        ; default max length
	Local $iBufN = 65536 ; Increase chunk size to 64KB for drastically faster multi-megabyte file transfers
	Local $VI_SUCCESS = 0
	Local $VI_SUCCESS_MAX_CNT = 0x3FFF0006
	Local $iTimeout = TimerInit()
	Local $sBufAcc = Binary("")
	Local $aRet
	Local $iStatus = 0
	Local $iRetCount = 0
	Local $iReadCount = 0
	Local $tBuf
	Local $bHeaderParsed = False                        ; for IEEE488.2 data block length header
	Local $iExpectedTotalBytes = -1                     ; for IEEE488.2 data block length header

	If $g_visa_debug Then ConsoleWrite("__viRead($viSession, iMaxlen=" & $iMaxLen & ", timeoutMS=" & $iTimeoutMS & ")  mode=" & $viSession[$_VImode] & " " & @CRLF)
	Local $iMode = $viSession[$_VImode]

	If $bBinary Then __viSetEOLenable($viSession, 0)                                   ; disable EOL termination in the data stream

	While True
		$aRet = __viReadBuf($viSession, $iBufN)
		$iStatus = $aRet[0]
		$tBuf = $aRet[1]
		$iRetCount = BinaryLen($tBuf)
		If $iRetCount > 0 Then
			$sBufAcc = Binary($sBufAcc & $tBuf)
			$iReadCount += $iRetCount
			$iTimeout = TimerInit()

			; DYNAMIC PARSING: Calculate expected file completion boundaries mid-stream (IEEE 488.2 header)
			If Not $bHeaderParsed And $iReadCount >= 10 Then
				Local $sCheck = BinaryToString(BinaryMid($sBufAcc, 1, 2), 1)
				If StringLeft($sCheck, 1) == "#" Then
					Local $iDigits = Int(StringRight($sCheck, 1))
					Local $sLenStr = BinaryToString(BinaryMid($sBufAcc, 3, $iDigits), 1)
					Local $iPayloadSize = Int($sLenStr)
					$iExpectedTotalBytes = 1 + 1 + $iDigits + $iPayloadSize                ; Total block footprint = '#' symbol (1) + digit counter (1) + size digits + raw payload
				EndIf
				$bHeaderParsed = True
			EndIf

		EndIf
		If $iReadCount >= $iMaxLen Then
			If $g_visa_debug Then ConsoleWrite("!> __viRead: Warning - Bounded buffer hit Max Length limit." & @CRLF)
			ExitLoop
		EndIf
		If TimerDiff($iTimeout) > $iTimeoutMS Then
			If $g_visa_debug Then ConsoleWrite("!> __viRead: Warning - timeout" & @CRLF)
			Return SetError(-3, 0, $sBufAcc)          ; timeout
		EndIf
		If $iStatus < 0 Then                ; Error check: If status code is negative, the hardware connection threw an exception
			If $g_visa_debug Then
				ConsoleWrite("!> __viRead: VISA Driver error status = 0x" & Hex($iStatus) & @CRLF)
				If $iStatus = 0xBFFF0015 Then ConsoleWrite("!> __viRead: visa timeout" & @CRLF)
			EndIf
			Return SetError($iStatus, 0, $sBufAcc)
		EndIf
		If $bHeaderParsed And ($iExpectedTotalBytes >= 0) And ($iReadCount >= $iExpectedTotalBytes) Then ExitLoop        ; SUCCESS EXIT: Cleanly break the socket loop the instant we match the binary footer layout!
		If $iMode Then        ; success check: tcp raw socket
			Local $iLFpos = StringInStr(BinaryToString($sBufAcc), @LF)
			If $iLFpos And ($iExpectedTotalBytes < 0) Then ExitLoop        ; if no IEEE488.2 header, then stop when we receive LF
		Else                ; Success Check: VISA returns VI_SUCCESS (0) when it has successfully cleared out the final packet block
			If $g_visa_debug Then ConsoleWrite("__viRead: $iStatus = " & $iStatus & @CRLF)
			If $iStatus = $VI_SUCCESS Then
				;If $g_visa_debug Then ConsoleWrite("__viRead: $iStatus = $VI_SUCCESS" & @CRLF)
				ExitLoop
			EndIf
			;If $iStatus = $VI_SUCCESS_MAX_CNT Then
			;	If $g_visa_debug Then ConsoleWrite("__viRead: $iStatus = $VI_SUCCESS_MAX_CNT" & @CRLF)
			;	ExitLoop
			;EndIf
		EndIf
	WEnd
	If $bBinary Then __viSetEOLenable($viSession, 1)                                   ; reenable EOL termination in the data stream

	If $g_visa_debug > 1 Then ConsoleWrite("__viRead: received $sBufAcc len = " & BinaryLen($sBufAcc) & @CRLF)

	If $iExpectedTotalBytes >= 0 Then                    ; if we received an IEEE 488.2 header, then strip it off
		; 4. Parse the IEEE 488.2 Definite Length Arbitrary Block Header
		; Format: #<num_digits_of_length><length_bytes><raw_png_data>
		; Example: #535240... means a 5-digit number specifies the length, which is 35,240 bytes.
		If $g_visa_debug Then ConsoleWrite("__viRead: IEEE 488.2 header found, parsing." & @CRLF)
		Local $sHeaderCheck = BinaryToString(BinaryMid($sBufAcc, 1, 2), 1)
		If StringLeft($sHeaderCheck, 1) = "#" Then
			Local $iNumDigitsOfLength = Int(StringRight($sHeaderCheck, 1))
			If 0 < $iNumDigitsOfLength And $iNumDigitsOfLength <= 9 Then
				Local $iPayloadSize = Int(BinaryToString(BinaryMid($sBufAcc, 3, $iNumDigitsOfLength), 1))     ; Extract the characters representing the total size value
				Local $iHeaderTotalOffset = 1 + 1 + $iNumDigitsOfLength                                           ; '#' symbol + digit count character + length digits
				$sBufAcc = BinaryMid($sBufAcc, $iHeaderTotalOffset + 1, $iPayloadSize)
			EndIf
		EndIf
	EndIf

	If Not $bBinary Then
		$sBufAcc = BinaryToString($sBufAcc, 1)                                     ; convert from binary to string
		If $g_visa_debug > 1 Then ConsoleWrite("__viRead: received string = '" & $sBufAcc & "'" & @CRLF)
		Local $iLFpos = StringInStr($sBufAcc, @LF)                                 ; strip any received data after the first EOL
		If Not $iLFpos Then $iLFpos = StringInStr($sBufAcc, @CR)
		If $iLFpos Then $sBufAcc = StringLeft($sBufAcc, $iLFpos)
		$sBufAcc = StringReplace(StringReplace($sBufAcc, @CR, ""), @LF, "")        ; strip EOL characters
		$sBufAcc = StringStripWS($sBufAcc, 3)                                      ; strip leading and trailing white spaces
	EndIf

	If $g_visa_debug Then ConsoleWrite("__viRead IN  : '" & BinaryToString($sBufAcc, 1) & "'" & @CRLF)

	Return $sBufAcc
EndFunc   ;==>__viRead


Func __viReadBinary(ByRef $viSession, $iMaxLen = 10 * 1024 * 1024, $iTimeoutMS = 1000)
	Return __viRead($viSession, $iMaxLen, $iTimeoutMS, 1)
EndFunc   ;==>__viReadBinary


;			__viReadBuf
; task:		nonblocking read - return any/all data currently received from visa device
; in:		$viSession = session handle
;			$iBufN = max number of bytes to read
; out:		[0] = status returned by visa dll call, or 0 if using raw socket protocol and no error
;			[1] = any data read as a binary data object
Func __viReadBuf(ByRef $viSession, $iBufN = 0x10000)
	Local $aR[2]
	Local $iErr, $iStatus, $bR
	If $viSession[$_VImode] Then
		$bR = TCPRecv($viSession[$_VIhSession], $iBufN)
		$iErr = @error
		If $iErr = 10093 Then
			TCPStartup()
			Sleep(50)
			$bR = TCPRecv($viSession[$_VIhSession], $iBufN)                        ; raw socket: read from socket
			$iErr = @error
		EndIf
		$aR[0] = $iErr
		$aR[1] = $bR
	Else
		Local $tBuf = DllStructCreate("byte[" & $iBufN & "]")                    ; $iBufN byte container for incoming data
		Local $aResult = __viReadDll($viSession, $tBuf, $iBufN)                    ; read into buffer using visa32.dll
		$iStatus = -1
		If Not IsArray($aResult) Then Return SetError($iStatus, @error, Binary(""))
		$iStatus = $aResult[0]
		Local $iBytesRead = $aResult[4]
		If $iBytesRead <= 0 Then
			$bR = Binary("")
		Else
			;Local $tResult = DllStructCreate("byte[" & $iBytesRead & "]")
			;DllCall("kernel32.dll", "none", "RtlMoveMemory", "struct*", $tResult, "struct*", $tBuf, "ulong", $iBytesRead)
			;$bR = Binary(DllStructGetData($tResult, 1)
			$bR = BinaryMid(DllStructGetData($tBuf, 1), 1, $iBytesRead)
		EndIf
		$aR[0] = $iStatus
		$aR[1] = $bR
		$iErr = ($iStatus < 0)
	EndIf
	If $iErr Then Return SetError($iErr, 0, $aR)
	Return $aR
EndFunc   ;==>__viReadBuf

Func __viReadDll(ByRef $viSession, ByRef $tBuf, $iBufN)
	Local $aRet = DllCall($viSession[$_VIdll], "long", "viRead", _
			"ulong", $viSession[$_VIhSession], _
			"struct*", $tBuf, _
			"ulong", $iBufN - 1, _                                          ; Max buffer length to read
			"ulong*", 0)                                                    ; Number of bytes read
	If @error Then Return SetError(@error, @extended, $aRet)
	Return $aRet
EndFunc   ;==>__viReadDll




;			__viReadToFile
; task:		blocking read of response from visa device
; in:		$viSession = session handle
;			$sFile = file to write to
;			$iTimeoutMS = timeout in milliseconds
; out:		data written to given file
;			if response begins with #Lnnnn... (IEEE 488.2) then the header is not written to the file
Func __viReadToFile(ByRef $viSession, $sFile, $iTimeoutMS = 20000)
	Local $iBufN = 65536 ; Increase chunk size to 64KB for drastically faster multi-megabyte file transfers
	Local $VI_SUCCESS = 0
	Local $VI_SUCCESS_MAX_CNT = 0x3FFF0006
	Local $iTimeout = TimerInit()
	Local $sBufAcc = Binary("")
	Local $aRet
	Local $iStatus = 0
	Local $iRetCount = 0
	Local $iReadCount = 0
	Local $tBuf
	Local $bHeaderParsed = False                        ; for IEEE488.2 data block length header
	Local $iExpectedTotalBytes = -1                     ; for IEEE488.2 data block length header
	Local $iErr = 0

	If $g_visa_debug Then ConsoleWrite("__viRead($viSession, timeoutMS=" & $iTimeoutMS & ")  mode=" & $viSession[$_VImode] & " " & @CRLF)
	Local $iMode = $viSession[$_VImode]

	__viSetEOLenable($viSession, 0)                                   ; disable EOL termination in the data stream

	Local $hFile = FileOpen($sFile, 2 + 16)                                ; open file for writing, binary
	If $hFile < 0 Then Return SetError($hFile, 0, 0)

	While True
		$aRet = __viReadBuf($viSession, $iBufN)
		$iStatus = $aRet[0]
		$tBuf = $aRet[1]
		$iRetCount = BinaryLen($tBuf)
		If $iRetCount > 0 Then
			$iReadCount += $iRetCount
			$iTimeout = TimerInit()
			If Not $bHeaderParsed Then                    ; check first 10 bytes for IEEE 488.2 header
				$sBufAcc = Binary($sBufAcc & $tBuf)
				If $iReadCount >= 10 Then                ; DYNAMIC PARSING: Calculate expected file completion boundaries mid-stream (IEEE 488.2 header)
					Local $sCheck = BinaryToString(BinaryMid($sBufAcc, 1, 2), 1)
					If StringLeft($sCheck, 1) == "#" Then
						Local $iDigits = StringRight($sCheck, 1)
						If '0' < $iDigits And $iDigits <= '9' Then
							$iDigits = Int($iDigits)
							Local $iPayloadSize = Int(BinaryToString(BinaryMid($sBufAcc, 3, $iDigits), 1))
							Local $iHeaderTotalOffset = 1 + 1 + $iDigits
							$iExpectedTotalBytes = $iHeaderTotalOffset + $iPayloadSize            ; Total block footprint = '#' symbol (1) + digit counter (1) + size digits + raw payload
							$sBufAcc = BinaryMid($sBufAcc, $iHeaderTotalOffset + 1)                ; strip header
						EndIf
					EndIf
					$bHeaderParsed = True
					FileWrite($hFile, $sBufAcc)               ; write data received past the header
					If @error Then
						$iErr = @error
						ExitLoop
					EndIf
				EndIf
			Else
				FileWrite($hFile, $tBuf)                       ; write data received after we finished header check
				If @error Then
					$iErr = @error
					ExitLoop
				EndIf
			EndIf
		EndIf
		;If $iReadCount >= $iMaxLen Then
		;	If $g_visa_debug Then ConsoleWrite("!> __viRead: Warning - Bounded buffer hit Max Length limit." & @CRLF)
		;	ExitLoop
		;EndIf
		If TimerDiff($iTimeout) > $iTimeoutMS Then            ; timeout
			If $g_visa_debug Then ConsoleWrite("!> __viRead: Warning - timeout" & @CRLF)
			$iErr = -3
			ExitLoop
		EndIf
		If $iStatus < 0 Then                ; Error check: If status code is negative, the hardware connection threw an exception
			If $g_visa_debug Then
				ConsoleWrite("!> __viRead: VISA Driver error status = 0x" & Hex($iStatus) & @CRLF)
				If $iStatus = 0xBFFF0015 Then ConsoleWrite("!> __viRead: visa timeout" & @CRLF)
			EndIf
			$iErr = $iStatus
			ExitLoop
		EndIf
		If $bHeaderParsed And ($iExpectedTotalBytes >= 0) And ($iReadCount >= $iExpectedTotalBytes) Then ExitLoop        ; SUCCESS EXIT: Cleanly break the socket loop the instant we match the binary footer layout!
		If $iMode Then        ; success check: tcp raw socket
			Local $iLFpos = StringInStr(BinaryToString($sBufAcc), @LF)
			If $iLFpos And ($iExpectedTotalBytes < 0) Then ExitLoop        ; if no IEEE488.2 header, then stop when we receive LF
		Else                ; Success Check: VISA returns VI_SUCCESS (0) when it has successfully cleared out the final packet block
			If $g_visa_debug Then ConsoleWrite("__viRead: $iStatus = " & $iStatus & @CRLF)
			If $iStatus = $VI_SUCCESS Then
				;If $g_visa_debug Then ConsoleWrite("__viRead: $iStatus = $VI_SUCCESS" & @CRLF)
				ExitLoop
			EndIf
		EndIf
	WEnd
	If Not $bHeaderParsed Then FileWrite($hFile, $sBufAcc)              ; if header never parsed, then write data received to file
	__viSetEOLenable($viSession, 1)                                     ; reenable EOL termination in the data stream
	FileClose($hFile)                                                   ; close file

	If $g_visa_debug > 1 Then ConsoleWrite("__viRead: received $sBufAcc len = " & BinaryLen($sBufAcc) & @CRLF)
	If $g_visa_debug Then ConsoleWrite("__viRead IN  : '" & BinaryToString($sBufAcc, 1) & "'" & @CRLF)

	If $iErr = 0 Then Return 1
	Return SetError($iErr, 0, 0)
EndFunc   ;==>__viReadToFile



; ====================================================================================================
; Function Name:    __viWriteFromFile
; Description:      Uploads a local file to a remote VISA device using the SCPI
;                   sends SCPI command $sCmd followed by IEEE 488.2 header and then file data.
; Parameter(s):     $viSession        - The active VISA session handle array or IP address string.
;                   $sCmd			  - the command string to tell the VISA device to receive the file
;                   $sLocalFilePath   - Path to the source file on your local computer.
; Return Value(s):  Success           - Returns 1
;                   Failure           - Returns 0 and sets @error:
;                                         -1 = Local file could not be opened.
;                                         -2 = VISA communication transmission failure.
;                                         -3 = Instrument reported an internal SCPI error.
; ====================================================================================================
Func __viWriteFromFile(ByRef $viSession, $sCmd, $sLocalFilePath)
	Local $iTotalBytes = FileGetSize($sLocalFilePath)                       ; get size of file
	If $iTotalBytes < 0 Or @error Then Return SetError(-1, @error, 0)
	Local $sDigits = String(StringLen(String($iTotalBytes)))                ; Generate the IEEE 488.2 Definite Length Arbitrary Block header
	Local $sBlockHeader = "#" & $sDigits & $iTotalBytes                     ; Format: #<num_digits><length><payload>

	Local $hFile = FileOpen($sLocalFilePath, 16)                            ; Open the local file in binary read mode (16)
	If $hFile < 0 Then Return SetError(-1, 0, 0)

	If Not __viBegin($viSession) Then                                       ; Establish the session connection transaction context
		FileClose($hFile)
		Return SetError(-2, 0, 0)
	EndIf

	Local $iChunkSize = 0x10000
	Local $bChunk
	Local $iBytesSent = 0
	Local $iWriteErr = 0
	Local $iCurrentChunkLen

	While $iBytesSent < $iTotalBytes
		$bChunk = FileRead($hFile, $iChunkSize)
		If @error Then ExitLoop
		$iCurrentChunkLen = BinaryLen($bChunk)
		If $iCurrentChunkLen = 0 Then ExitLoop
		If Not __viWriteBuf($viSession, Binary($bChunk)) Then
			$iWriteErr = 1
			ExitLoop
		EndIf
		$iBytesSent += $iCurrentChunkLen
	WEnd

	FileClose($hFile)
	If Not $iWriteErr Then __viWriteBuf($viSession, @CRLF)                  ; send mandatory EOL to close scpi transaction
	__viEnd($viSession)

	If $iWriteErr Or ($iBytesSent <> $iTotalBytes) Then Return SetError(-2, 0, 0)
	Return 1
EndFunc   ;==>__viWriteFromFile



; ---------------------------------
; visa attribute functions



;			__viSetAttribute
; task:		set attributes of the VISA connection, only for VXI-11
; in:		$viSession = visa handle
;			$iattr = attribute id/number/address
;			$ivalue = new value for attribute
; out:		1 if successful, 0 if error
Func __viSetAttribute(ByRef $viSession, $iAttr, $iValue)
	If $viSession[$_VImode] Then Return 0                                ; we do not have attributes for the raw socket protocol
	DllCall($viSession[$_VIdll], "long", "viSetAttribute", _
			"ulong", $viSession[$_VIhSession], _
			"ulong", $iAttr, _
			"ulong", $iValue)
	If (@error) Then Return SetError(@error, @extended, 0)
	Return 1
EndFunc   ;==>__viSetAttribute


;			__viSetEOLenable
; task:		enable or disable EOL byte detection in the raw data
; in:		$viSession = session handle
; 			$bEnable = 0=disabled, 1=enabled
; out:		none
Func __viSetEOLenable(ByRef $viSession, $bEnable)
	Return __viSetAttribute($viSession, 0x3FFF0038, $bEnable)
EndFunc   ;==>__viSetEOLenable


;			__viSetEOLchar
; task:		set the EOL character
; in:		$viSession = session handle
; 			$cChar
; out:		none
Func __viSetEOLchar(ByRef $viSession, $cChar)
	Return __viSetAttribute($viSession, 0x3FFF0018, $cChar)
EndFunc   ;==>__viSetEOLchar


;			__viSetTimeout
; task:		set timeout attribute of the VISA connection
; in:		$viSession = visa handle
;			$iTimeoutMS = timeout in ms
; out:		none
Func __viSetTimeout(ByRef $viSession, $iTimeoutMS)
	Return __viSetAttribute($viSession, 0x3FFF001A, $iTimeoutMS)
EndFunc   ;==>__viSetTimeout








; ---------------------------------------------
; misc visa functions




; task:		flush error messages - read errors until response is no error
Func __viFlushErrors(ByRef $viSession, $iTimeoutMS = 1500)                    ; flush error messages from dcps queue
	Local $iTimer = TimerInit()
	Local $sResponse = 1
	If Not __viBegin($viSession) Then Return SetError(-1, @error, 0)
	__viFlushInputBuffer($viSession)
	While Not (Number($sResponse) = 0) And (TimerDiff($iTimer) < (3 * $iTimeoutMS))
		$sResponse = __viReadError($viSession)         ; check for and clear error messages
	WEnd
	__viEnd($viSession)
EndFunc   ;==>__viFlushErrors



; task:		read the error status message.  format "number, string".  if the number is zero (no error) then return an empty string
Func __viReadError(ByRef $viSession)
	Local $sRet = __viReq($viSession, $VI_REQ_ERR)
	If @error Then Return SetError(@error, @extended, $sRet)
	If Number(StringLeft($sRet, StringInStr($sRet, ",") - 1)) = 0 Then Return ""
	Return $sRet
EndFunc   ;==>__viReadError



;			__viFlushInputBuffer
; task:		flush the input buffer until all previous data is emptied out of it
Func __viFlushInputBuffer($viSession)
	Local $sTrash
	; Set a tight timeout or loop quickly to consume all residual data
	If $viSession[$_VImode] Then
		Do
			$sTrash = TCPRecv($viSession[$_VIhSession], 2048) ; Read up to 2048 bytes at a time
		Until $sTrash = "" Or @error
	Else
		Do
			$sTrash = __viReadBuf($viSession, 0x400)
		Until $sTrash = "" Or @error
	EndIf
EndFunc   ;==>__viFlushInputBuffer






; ---------------------------
; misc visa functions




; Function Name:    __viGTL
; Description:      Commands the specified hardware instrument to exit remote mode and enter local mode
;                   using raw DLL calls to visa32.dll.
; Parameter(s):     $hSession - The VISA connection session handle (returned from viOpen)
; Return Value(s):  Success   - 0 (VI_SUCCESS)
;                   Failure   - Returns a negative 32-bit integer representing the VISA status error code,
;                               or sets @error if the DLL call itself fails.
; ====================================================================================================
Func __viGTL(ByRef $viSession)
	If Not __viConfirmOpen($viSession) Then Return SetError(1, 0, 0)

	If $viSession[$_VImode] Then
		Return __viWrite($viSession, "SYSTem:LOCal")                                ; not accepted by freq counter
		Return __viWrite($viSession, "SYSTem:COMMunicate:ENABle ON, LAN")        ; accepted by freq counter, but not acted on
		Return __viWrite($viSession, "SYSTem:LOCK:RELease")                        ; accepted by freq counter, but not acted on
	Else
		; Call viGpibControlLocal directly from visa32.dll
		; Calling convention: 'long:cdecl' (standard 32-bit signed long return)
		; Parameter 1: 'long' (The VISA session handle is a 32-bit unsigned/signed long)
		Local $aResult = DllCall($viSession[$_VIdll], "long:cdecl", "viGpibControlLocal", _
				"long", $viSession[$_VIhSession])
		If @error Then Return SetError(1, @error, -1)       ; @error = 1 means DLL failure    ; If @error is set by DllCall, the visa32.dll file is missing or the function name is wrong
		Local $iStatus = $aResult[0]                        ; DllCall returns an array where element [0] is the return value of the C function

		; In VISA, 0 or positive values represent Success (e.g., VI_SUCCESS)
		; Negative values represent specific VISA hardware/protocol errors
		If $iStatus < 0 Then Return SetError(2, $iStatus, $iStatus) ; @error = 2 means the instrument/VISA bus rejected the command
	EndIf
	Return $iStatus ; Success (0)
EndFunc   ;==>__viGTL



; ====================================================================================================
; Function Name:    __viIsHandleValid
; Description:      Queries visa32.dll directly to check if a session handle is live and authentic.
; Parameter(s):     $hSession - The variable containing the handle to test
; Return Value(s):  True  - The handle is authentic and open.
;                   False - The handle is dead, closed, or completely fabricated.
; ====================================================================================================
Func __viIsHandleValid($viSession)
	Local $hSession = $viSession[$_VIhSession]
	If $hSession = "" Or $hSession = True Or $hSession = False Then Return False    ; 1. Ensure it isn't an empty string or basic boolean flag
	If (Not IsInt($hSession)) And (Not IsPtr($hSession)) And ( Not (IsString($hSession) And StringRegExp($hSession, "^0x[0-9a-fA-F]+$"))) Then Return False   ; 2. Ensure it is structurally a numeric pointer or integer token

	Local Const $VI_ATTR_RSRC_CLASS = 0xBFFF0001                             ; Constant for Resource Class attribute (safest read-only universal query)
	Local $tBuffer = DllStructCreate("char[256]")                            ; Allocate a blank structure buffer to capture the text if successful

	; Call viGetAttribute: target handle, requested attribute type, buffer pointer destination
	Local $aResult = DllCall($viSession[$_VIdll], "long:cdecl", "viGetAttribute", _
			"ulong", $hSession, _
			"ulong", $VI_ATTR_RSRC_CLASS, _
			"struct*", $tBuffer)
	If @error Then Return False                 ; DLL call failed entirely (visa32.dll missing)
	Return ($aResult[0] = 0)                    ; Status code 0 (VI_SUCCESS) means VISA recognized the handle and answered the query
EndFunc   ;==>__viIsHandleValid






; ---------------------------------------
; Scan network for VISA devices functions



;			__viScanSubnetRunFirst
; task:		This must be called at the beining of the main script.  It allows for parallel visa scanning by
;			calling the script and running just the getID function
Func __viScanSubnetRunFirst()
	If $CmdLine[0] >= 2 Then
		If $CmdLine[1] = ":getidn:" Then
			Local $aResult = __viScanID(StringRegExpReplace($CmdLine[2], '^[\x22\x27]|[\x22\x27]$', ''))
			ConsoleWrite($aResult[0] & @CRLF & $aResult[1] & @CRLF)
			Exit
		EndIf
	EndIf
EndFunc   ;==>__viScanSubnetRunFirst



;			__viScanSubnet
; task:		scan a subnet and return a list of found VISA instruments/devices
; in:		subnet IP address
; out:		it only scans the 255 IP addresses of the last number in the IP address
;			2d array of items, one row for each found VISA device
;				column 0 = VISA address "TCPIP0::..."
;				column 1 = IDN response string
;				column 2 = classification of device type
Func __viScanSubnet($sSubnet = "192.168.0.0")
	; debug
	;Local $a = [["192.168.0.14", "TCPIP0::192.168.0.14::inst0::INSTR", "TEKTRONIX,MSO58B...", "Oscilloscope"], _
	;		["192.168.0.15", "TCPIP::192.168.0.15::5025::SOCKET", "Watlow Electric,F4T...", "Chamber"], _
	;		["192.168.0.16", "TCPIP0::192.168.0.16::inst0::INSTR", "Agilent Tech,N6705B...", "DC Power Supply"], _
	;		["192.168.0.25", "TCPIP::192.168.0.25::5025::SOCKET", "Watlow Electric,F4T...", "Chamber"]]
	;Return $a


	ProgressOn("Scanning subnet " & $sSubnet, "", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
	ProgressSet(0)

	;ConsoleWrite("__viScanSubnet( $sSubnet = " & $sSubnet & " ) " & @CRLF)
	Local $aPF = _PingScan($sSubnet)                        ; scan network for active IP addresses
	;_ArrayDisplay($aPF)
	;debug
	;Local $aPF = ["192.168.0.1", "192.168.0.14", "192.168.0.15", "192.168.0.16", "192.168.0.25", "192.168.0.151", "192.168.0.217"]

	Local $aInsts = _viScanList($aPF, 0)                           ; query visa *IDN? to see which IP addresses are VISA instruments

	;_ArrayDisplay($aInsts)
	$aInsts = _viClassifyList($aInsts)                            ; classify each found VISA instrument
	;_ArrayDisplay($aInsts)
	ProgressOff()
	Return $aInsts
EndFunc   ;==>__viScanSubnet



;			PingScan
; task:		scan subnet for active IP addresses
; in:		subnet IP prefix
; out:		array of found IP addresses
Func _PingScan($sSubnetBase = "192.168.0.0")
	Local $aPIDs[255]                                                                             ; Properly declared array size
	Local $aActiveIPs[1]
	Local $iFoundCount = 0

	$sSubnetBase = StringRegExpReplace($sSubnetBase, "\d+$", "")                                            ; remove last number, but keep the dot

	;ProgressOn("Scanning subnet " & $sSubnetBase & "* for instruments", "Spawning parallel ping tasks...", "0%", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
	ProgressSet(0, "", "Spawning parallel ping tasks...")
	For $i = 1 To 254                                                                            ; 1. Launch 254 hidden, concurrent pings
		Local $sIP = $sSubnetBase & $i
		; Run a fast, single-echo ping (-n 1) with a 750ms timeout (-w 750).
		; We ask cmd to echo "ONLINE" only if the ping succeeds.
		$aPIDs[$i] = Run(@ComSpec & ' /c ping -n 1 -w 750 ' & $sIP & ' | findstr "TTL=" && echo ONLINE', @TempDir, @SW_HIDE, $STDOUT_CHILD)
		If Mod($i, 10) = 0 Then ProgressSet(Int(($i / 254) * 25), "Deploying Pinger: " & $sIP)         ; Update the progress bar
		Sleep(50)
	Next

	ProgressSet(25, "Reading background tasks...", "Gathering responses...")
	For $i = 1 To 254                                                                            ; 2. Harvest results asynchronously
		Local $sIP = $sSubnetBase & $i
		ProcessWaitClose($aPIDs[$i], 5)                                                           ; Wait for this specific background ping process to close
		Local $sOutput = StdoutRead($aPIDs[$i])                                                    ; Read the standard output of the hidden window
		If StringInStr($sOutput, "ONLINE") Then                                                    ; If the window outputted our "ONLINE" keyword, it's alive!
			$iFoundCount += 1
			ReDim $aActiveIPs[$iFoundCount]
			$aActiveIPs[$iFoundCount - 1] = $sIP
		EndIf
		If Mod($i, 10) = 0 Then ProgressSet(25 + Int(($i / 254) * 25), "Checking Pinger: " & $sIP)     ; Update the progress bar
	Next

	Return $aActiveIPs
EndFunc   ;==>_PingScan



; 			VisaScan (parallel mode)
; task:		query each given IP address to get its ID string
; in:		list of IP addresses
;			flag = 1 to not filter out any non-responsive IP addresses
; out:		ip addresses with their corresponding IDN string
;			any IP address that did not respond is excluded from the output
Func _viScanList($aVisaAddresses, $flag = 0)

	Local Const $iRetries = 1
	Local $iCount = UBound($aVisaAddresses)
	Local $aPIDs[$iCount]                   ; To track process IDs
	Local $aIDNs[1][3]                      ; resulting list
	Local $i                                ; counter
	Local $j                                ; counter

	ReDim $aIDNs[$iCount][3]                ; setup output array
	For $i = 0 To $iCount - 1               ; copy IP addresses into output array
		$aIDNs[$i][0] = $aVisaAddresses[$i]
		$aIDNs[$i][1] = ""
		$aIDNs[$i][2] = ""
		$aPIDs[$i] = 0
	Next

	;ConsoleWrite(">>> Starting parallel VISA scans..." & @CRLF)
	For $j = 1 To $iRetries
		ProgressSet(50, "", "VISA Querying IDNs...")

		For $i = 0 To $iCount - 1                            ; 1. Spawn all worker processes simultaneously (Non-blocking Parallel Launch)
			If $aIDNs[$i][1] = "" Then                            ; if we do not have IDN yet, then spawn a process to ask for it
				; Re-calls this compiled EXE, passing the specific VISA address as an argument
				If @Compiled Then                            ; If compiled, call the current EXE directly with the argument
					$aPIDs[$i] = Run('"' & @ScriptFullPath & '" :getidn: "' & $aVisaAddresses[$i] & '"', @TempDir, @SW_HIDE, $STDOUT_CHILD)
				Else                                        ; If uncompiled, call the AutoIt interpreter, pass the script path, then the argument
					$aPIDs[$i] = Run('"' & @AutoItExe & '" "' & @ScriptFullPath & '" :getidn: "' & $aVisaAddresses[$i] & '"', @TempDir, @SW_HIDE, $STDOUT_CHILD)
				EndIf
			Else
				$aPIDs[$i] = 0
			EndIf
			ProgressSet(50 + Int(($i / $iCount) * 10), "Deploying VISA IDN Query: " & $aVisaAddresses[$i])             ; Update the progress bar
			Sleep(250)    ; a short pause between deployments of the visa IDN requests
		Next

		ProgressSet(60, "Awaiting results...")                                                         ; Update the progress bar

		For $i = 1 To 15
			ProgressSet(60 + $i)
			Sleep(800)
		Next


		; 2. Monitor and gather outputs dynamically as they finish
		For $i = 1 To $iCount - 1                                                                        ; 2. Harvest results asynchronously
			ProcessWaitClose($aPIDs[$i], 30)                                                               ; Wait for this specific background ping process to close
			Local $sOutput = StdoutRead($aPIDs[$i])                                                        ; Read the standard output of the hidden window
			If @error Then $sOutput = ""
			If $sOutput <> "" Then                                                                       ;     if output found in process, then append to results array for given IP address
				;If $aIDNs[$i][1] = "" Then $aIDNs[$i][1] = $j & ": "
				$aIDNs[$i][2] = $aIDNs[$i][2] & $sOutput
			EndIf
			ProgressSet(75 + Int(($i / $iCount) * 25), "Checking: " & $aVisaAddresses[$i])              ; Update the progress bar
			Sleep(50)                                                                                     ; Keep CPU cycles low
		Next

		;ProgressOff()
		Sleep(250)                                                    ; give things time to settle
	Next

	Local $iFinished = 0
	For $i = 0 To $iCount - 1                                        ; soft list, moving blank IDNs to the bottom
		;MsgBox(0, "hi", "." & $aIDNs[$i][1] & ".")
		Local $aLine = StringSplit($aIDNs[$i][2], @CRLF, 1)
		If $aLine[0] < 2 Then ContinueLoop
		If StringStripWS($aLine[2], 3) = "" Then ContinueLoop
		;msgbox(0,"hi","s[" & $i & "]=." & $aLine[1] & "." & @CRLF & "." & $aLine[2] & ".")
		If $iFinished <> $i Then
			For $j = 0 To 2
				Local $t = $aIDNs[$iFinished][$j]
				$aIDNs[$iFinished][$j] = $aIDNs[$i][$j]
				$aIDNs[$i][$j] = $t
			Next
		EndIf
		$aIDNs[$iFinished][1] = $aLine[1]
		$aIDNs[$iFinished][2] = $aLine[2]
		$iFinished += 1
	Next

	If Not $flag Then                                                ; if flag is not set then remove empty IDNs from the bottom of the list
		ReDim $aIDNs[$iFinished][3]
	EndIf

	Return $aIDNs
EndFunc   ;==>_viScanList



Func _viClassifyList($aInsts)
	Local $iCount = UBound($aInsts)
	ReDim $aInsts[$iCount][4]                    ; add a fourth column to fill in identification of instrument
	Local $i

	For $i = 0 To $iCount - 1
		Local $sid = $aInsts[$i][2]
		Local $stype = ""
		If StringInStr($sid, ",MSO") Or StringInStr($sid, ",DPO") Then
			$stype = "Oscilloscope"
		ElseIf StringInStr($sid, ",F4T") Or StringInStr($sid, ",""F4T") Then
			$stype = "Chamber"
		ElseIf StringInStr($sid, ",5323") Or StringInStr($sid, ",5313") Then
			$stype = "Frequency Counter"
		ElseIf StringInStr($sid, ",N670") Or StringInStr($sid, ",E363") Then
			$stype = "DC Power Supply"
		EndIf

		$aInsts[$i][3] = $stype
	Next

	Return $aInsts
EndFunc   ;==>_viClassifyList



;			__viScanID
; task:		try various protocols to communicate with instrument and get its ID
; in:		$ipAddr = the IP address of the instrument
; out:		[0] = full visa address including which protocol to use to communicate with this instrument in the future
;			[1] = response string from VISA *IDN? request
Func __viScanID($ipAddr)
	Local $iTimeoutMS = 1100                                                    ; 1.5 seconds
	Local $sResponse = ""
	Local $sAddr, $sTaddr

	If $sResponse = "" Then                                                     ; try VISA VXI-11 protocol
		$sTaddr = $ipAddr
		$sResponse = __viReq($sTaddr, $VI_IDN, $iTimeoutMS, 0)
		If @error Then $sResponse = ""
		$sResponse = StringStripWS($sResponse, 3)
		$sAddr = __viMakeAddress($ipAddr, 0)
	EndIf

	If $sResponse = "" Then                                                     ; try VISA raw socket protocol
		$sTaddr = "raw:" & $ipAddr
		$sResponse = __viReq($sTaddr, $VI_IDN, $iTimeoutMS, 0)
		If @error Then $sResponse = ""
		$sResponse = StringStripWS($sResponse, 3)
		$sAddr = __viMakeAddress($ipAddr, 1)
	EndIf

	Local $aResult[2]                                                           ; compile results
	$aResult[0] = $sAddr
	$aResult[1] = $sResponse
	Return $aResult
EndFunc   ;==>__viScanID



; task:		filter the list of found instruments on the network for a given type
; in:		$aList = list returned from __viScanSubnet(...)
;			$filter = filter string, one of the following
;				Chamber
;				DC Power Supply
;				Oscilloscope
;				Frequency Counter
; out:		[0] = "|" separated list of IP addresses, including ones that match the type and instruments of unidentified type
;			[1] = first item from list [0], used to set GUI combo boxes
Func __viScanSubnetFilter($aList, $filter)
	Local $s = ""
	Local $sf = ""
	Local $i, $t
	For $i = 0 To UBound($aList) - 1
		$t = $aList[$i][3]
		If ($t = $filter) Or ($t = "") Or ($filter = "") Then
			$s &= "|" & $aList[$i][0]
			If $sf = "" Then $sf = $aList[$i][0]
		EndIf
	Next
	Local $a[2]
	$a[0] = $s
	$a[1] = $sf
	Return $a
EndFunc   ;==>__viScanSubnetFilter




;-------------------------------------------------------
; GUI enter/select IP address of VISA/SCPI/Modbus instrument
;


Global $__viSD_subnet
Global $__viSD_filter



; ====================================================================================================
; Function Name:    __viSelectDevice
; Description:      Prompts the user to select or input a target VISA instrument IP address.
;                   Safely handles event loops across both OnEvent and Message-Loop modes.
; ====================================================================================================
Func __viSelectDevice($sIP, ByRef $sList, $hParent = 0, $filter = "", $subnet = "192.168.0.0")

	Local Const $DWIDTH = 165
	Local Const $DHEIGHT = 85

	Local Const $ICON_REFRESH = ChrW(0x21BB)
	Local Const $ICON_GLASS = ChrW(0xD83D) & ChrW(0xDD0D)

	$__viSD_subnet = $subnet
	$__viSD_filter = $filter

	; CRITICAL FIX STEP 1: Store the developer's original global OnEvent mode state
	Local $iOldOnEventMode = Opt("GUIOnEventMode", 0) ; Temporarily switch to standard Message-Loop mode

	; Create the modal popup window
	Global $__viSD_hGui = GUICreate("Select VISA device", $DWIDTH, $DHEIGHT, -1, -1, BitOR($WS_CAPTION, $WS_SYSTEMMENU, $DS_MODALFRAME), -1, $hParent)

	Local $hAddrLbl = GUICtrlCreateLabel("IP:", 10, 8, 15, 17)
	Global $__viSD_hIpAddr = GUICtrlCreateCombo("", 25, 5, 110, 22)
	GUICtrlSetData(-1, "|" & $sList, $sIP)

	Local $findBtn = GUICtrlCreateButton($ICON_GLASS, 135, 2, 25, 25)
	GUICtrlSetTip(-1, "Scan subnet " & $subnet & " for possible VISA devices")
	GUICtrlSetFont(-1, 15)

	Local $hDevIDlbl = GUICtrlCreateLabel("ID:", 10, 33, 15, 17)
	Global $__viSD_hDevID = GUICtrlCreateInput("", 25, 30, 110, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))

	Local $refreshBtn = GUICtrlCreateButton($ICON_REFRESH, 135, 27, 25, 25)
	GUICtrlSetTip(-1, "Read Chamber ID to verify connection")
	GUICtrlSetFont(-1, 18, 600)

	Local $hOK = GUICtrlCreateButton("OK", 25, 55, 50, 25)
	Local $hCancel = GUICtrlCreateButton("Cancel", 80, 55, 50, 25)

	GUISetState(@SW_SHOW, $__viSD_hGui)

	__viSD_Refresh()

	Local $nMsg
	Local $bKeepRunning = True

	While $bKeepRunning
		$nMsg = GUIGetMsg()

		Switch $nMsg
			Case $GUI_EVENT_CLOSE, $hCancel
				GUICtrlSetData($__viSD_hIpAddr, "") ; Wipe target selection string on cancel
				$bKeepRunning = False

			Case $hOK
				$bKeepRunning = False

			Case $findBtn
				; Divert straight to the native execution functions
				__viSD_Scan()

			Case $refreshBtn, $__viSD_hIpAddr
				; Triggers an interactive live test connection ping against the target instrument
				__viSD_Refresh()
		EndSwitch
	WEnd

	; Capture current selection configurations out of elements before destroying pointers
	$sIP = GUICtrlRead($__viSD_hIpAddr)
	If Not ($sIP = "") Then $sList = _GUICtrlComboBox_GetList($__viSD_hIpAddr)

	; Cleanup the GUI elements out of system memory
	GUISetState(@SW_HIDE, $__viSD_hGui)
	GUIDelete($__viSD_hGui)

	; CRITICAL FIX STEP 3: Seamlessly restore previous script orchestration layout
	Opt("GUIOnEventMode", $iOldOnEventMode)

	Return $sIP
EndFunc   ;==>__viSelectDevice




; task:		scan the subnet from the SelectDevice dialog
Func __viSD_Scan()
	Local $aRet = __viScanSubnetFilter(__viScanSubnet($__viSD_subnet), $__viSD_filter)
	GUICtrlSetData($__viSD_hIpAddr, $aRet[0], $aRet[1])
	__viSD_Refresh()
EndFunc   ;==>__viSD_Scan



; task:		query visa device for its id
Func __viSD_Refresh()
	Local $sIP = StringStripWS(GUICtrlRead($__viSD_hIpAddr), 3)
	If $sIP == "" Or $sIP == "0.0.0.0" Then Return

	GUICtrlSetData($__viSD_hDevID, "Checking...")
	_WinAPI_UpdateWindow($__viSD_hGui)

	Local $sid = StringReplace(__viReadIDprot($sIP, 300), '"', "")
	GUICtrlSetData($__viSD_hDevID, $sid)
	_GUICtrlEdit_SetSel($__viSD_hDevID, 0, 0)
	_WinAPI_UpdateWindow($__viSD_hGui)
EndFunc   ;==>__viSD_Refresh



Func __viSD_OK()
	GUISetState(@SW_HIDE, $__viSD_hGui)
EndFunc   ;==>__viSD_OK

Func __viSD_Cancel()
	GUICtrlSetData($__viSD_hIpAddr, "")
	GUISetState(@SW_HIDE, $__viSD_hGui)
EndFunc   ;==>__viSD_Cancel





; debug

;Local $aRet = __viScanID("192.168.0.25")
;MsgBox(0, "hi", "[0]=" & $aRet[0] & @CRLF & "[1]=" & $aRet[1] & @CRLF)
;Exit

;Local $sList = "192.168.0.15|192.168.0.25"
;Local $filter = "" ; "Chamber"
;Local $sIP = __viSelectDevice("192.168.0.25", $sList, 0, $filter)
;MsgBox(0, "hi", "sIP=" & $sIP & @CRLF & "list=" & $sList & @CRLF)

; end debug

