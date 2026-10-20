#include-once

; debug
Global $g_viPrintCmds = False
Global $g_viPrintCondCmds = False
Global $g_viPrintQueuePop = False
Global $g_viPrintQueuePush = False
Global $g_viPrintpQue = False
Global $g_viPrintpQueCond = False
Global $g_viPrintLoopRead = False

#cs

VISA/SCPI and Modbus TCP asynchronous queue library
	send request, then later check back for response
	requests are queued and sent sequentially after responses are received as needed
	some scripting functions are included, see below
	each IP address given creates an instance in a global list for continued communication with the VISA device


visa ip address format:
   [raw:]ip[:port]
   if port not given, then it will be replaced with 5025 or instr depending on the protocol
   specify "raw:" prefix to use raw socket instead of visa32.dll VXI-11 protocol


nonblocking functions:
	__viReq($oDev, $sReq, $bWait=True, $iTimeoutMS=1000)
		$oDev = ip address or a session handle variable
			if this is just an ip address, then a session is opened, communication commences, and the session is closed
			if this is a session handle, then the communication is performed but the session connection is left open
		$sReq = visa/scpi request/command string
		$bWait = true to wait for a response, false if this is a command with no expected response
		$iTimeoutMS = timeout in milliseconds to wait for response (-1 = do not wait)
		Adds the request to the queue
	__viCmd($oDev, $sCmd)
		same as __viReq except do not wait for a response ($bWait = false)
	__viUploadFile($oDev, $sFile, $sReq, $iTimeoutMS=15000)
		$sFile = file path/name of file to send
		$sReq = visa command to send as the prefix to the file data
	__viDownloadFile($oDev, $sFile, $sReq, $iTimeoutMS=15000)
		$sFile = file path/name to save downloaded file
		$sReq = visa command to send to initiate the transfer
	__viIsReqDone($oDev)
		checks and clears the reqdone flag.  returns true if the latest command being executed is done including any reply received.
		use this to check if the request/command you send is finished
	__viCmdRetStatus($oDev)
		return the exit status of the last command that finished - 0=error, 1=ok
	__viIsIdle($oDev)
		returns true if there are no pending commands.  there may still be pending incomming data

	__viRet($oDev)
		pulls an item from the return queue
			every command that finishes will put its exit status in this queue
			every visa message received will put its data in this queue
		if the item is a command status it is the return value
		if the item is received data then the data is the return value, and the status code is @extended
	__viHasRet($oDev)
		returns true if there are items in the return queue

	__mbWrite($oDev, $sDataType, $iRegAddr, $nValue)
		sends a modbus register write command.  Sets register $iRegAddr to value $nValue as datatype interpreted by $sDataType
	__mbReadBl($oDev, $sDataType, $iRegAddr, $iTimeoutMS)
		same as __mbRead, but waits for and returns the value read from the register
	__mbRead($oDev, $sDataType, $iRegAddr, $iTimeoutMS)
		sends a modbus register read request
		$sDataType = "32i" "32f" "16i" "16f" for 32 or 16 bit, integer or floating point
	__mbRet($oDev)
		same as __viRet - use this to pull the return value from the async __mbRead
	__mbHasRet($oDev)
		same as __viHasRet - use this to check if there is a response yet from async __mbRead


blocking functions:
	__viReqBl($oDev,$sReq,$bWait=true,$iTimeoutMS=2000)
		will send the request or command and wait until the command is sent or the request receives a reply, and then return the reply
	__viCmdBl($oDev,$sCmd)
		same as __viReqBl, but does not wait for a reply

	__viGetID($oDev)
		sends the scpi identity request *IDN? and waits for a reply
		if it does not work the first time, then it switches between VXI-11 and raw socket modes and tries again
		use this the first time to make sure the device is responding to the protocol,
		then subsequent uses of $oDev will use the working protocol.


script functions:
	__viScriptFile($oDev, $sFile)			read a file line by line and process it as a script, putting its commands into the queue

	script statements:
		[write|cmd] visaStatement			send visaStatement to visa device - use this for visa/scpi commands/requests
		$var=visaStatement					read response from visa device and store in given variable name
		cd|chdir path						change local directory to 'path'
		sleep timeMS						sleep for 'timeMS' milliseconds
		download::filename::visaStatement	read response from request 'visaStatement' and store it in file 'filename'
											use this to download files, including screenshots
		upload::filename::visaStatement		sends visa/scpi statement prefix and append with file data from 'filename' with IEEE488.2 length header
											use this to upload files
		logfile filename					set the log file name and path to 'filename'
		log	string							append 'string' to the logfile - use this for saving measurements.  'string' is evaluated with Execute() - see below
		set $var expr                   	set variable 'var' to the value of expression 'expr'

	script conditional statements:
		if cond								if cond evaluates to true then execute the first statement body
		  statement block...
		else								optional else statement body, execute if cond is false
		  statement block...
		end									close the if and/or else statement body

		while cond							while loop: while cond is true keep executing the body statements.  condition is evaluated before execution of the body
		  statement block...
		end									close the while statement body

		do									do until loop: repeat body block until cond evaluates true.  condition is evaulated at end of execution of the body
		  statement block...
		until cond							close the do until loop

	 string substitution:  substrings enclosed with curley brackets { } are evaluated as expressions and the result is substituted
	   this uses autoit execute() function, so variable names begin with $, math expressions are evaluated, and possibly autoit commands
	   example:
			$period=MEASUrement:MEAS2:RESUlts:ALLacq:MEAN?							read the measured clock period
			:SEARCH:SEARCH1:TRIGGER:A:PULSEWIDTH:LOWLIMIT {2.5*$period}				set search1 to look for clock pulses wider than 2.5 * period



#ce



; common visa commands
Global Const $VI_REQ_ERR = ":SYST:ERR?"
Global Const $VI_IDN = "*IDN?"
Global Const $VI_CLS = "*CLS"
Global Const $VI_RST = "*RST"



#include "mydebug.au3"
#include "datatypes.au3"


; -----------------------------------------------------------------------------------------------------------------
; -----------------------------------------------------------------------------------------------------------------
; -----------------------------------------------------------------------------------------------------------------
; -----------------------------------------------------------------------------------------------------------------

#include <File.au3>
#include "deque.au3"
#include "filemisc.au3"



Global $g_oViInstruments = ObjCreate("Scripting.Dictionary")                                ; Global visa instrument/device list
Global $g_logfile = _PathFull("log.txt")                                                    ; script logfile

Global $__vi_hDll = 0                                                                       ; handle for visa.dll
Global $__vi_hRM = 0                                                                        ; handle for visa resource manager
Global Const $__viSysUint32_64 = @AutoItX64 ? "uint64" : "ulong"                            ; uint32 or uint64 based on compiled version
Global Const $__viSysUint32_64ptr = $__viSysUint32_64 & "*"                                 ; uint32/64 pointer
Global Const $__viVisaDll = @AutoItX64 ? "visa64.dll" : "visa32.dll"                        ; visa dll file name based on 32/64 bit-ness
Global $__viVisaUint32_64 = StringInStr($__viVisaDll, "32") ? "ulong" : "uint64"            ; updated in __viCheckDLLhandle.  uint32/64 based on visa bit-ness
Global $__viVisaUint32_64ptr = $__viVisaUint32_64 & "*"                                     ; uint32/64 pointer based on visa bit-ness

; constants
Global Const $VI_SUCCESS = 0                                                                ; visa success
;Global Const $VI_SUCCESS_SYNC = 0x3FFF009B
;Global Const $VI_SUCCESS_MAX_CNT = 0x3FFF0006
Global Const $VI_ATTR_RM_SESSION = 0x3FFF00C4
Global Const $VI_ATTR_RSRC_CLASS = 0xBFFF0001                                               ; Resource Class attribute lookup constant (Universally supported read-only query)
Global Const $VI_ATTR_TMO_VALUE = 0x3FFF001A

;Global Const $VI_NOWAIT = -1                                                                ; used for screenshot command list as the timeout number for commands that do not require a reply









;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------


#cs
; VISA/SCPI instrument management functions
; ----------------------------------------------
Func __viScriptTest_debug()

	Local $sCmds = _
			'set $i 0' & @CRLF & _
			'while $i < 5' & @CRLF & _
			'  set $i $i + 1' & @CRLF & _
			'  if $i = 4' & @CRLF & _
			'    sleep 400' & @CRLF & _
			'  else' & @CRLF & _
			'    sleep 100' & @CRLF & _
			'  end' & @CRLF & _
			'end' & @CRLF & _
			'do' & @CRLF & _
			'  set $i $i - 1' & @CRLF & _
			'  if $i = 4' & @CRLF & _
			'    sleep 400' & @CRLF & _
			'  end' & @CRLF & _
			'until $i <= 0' & @CRLF & _
			'while $i > 5' & @CRLF & _
			'  set $i $i + 1' & @CRLF & _
			'  if $i = 4' & @CRLF & _
			'    sleep 400' & @CRLF & _
			'  else' & @CRLF & _
			'    sleep 100' & @CRLF & _
			'  end' & @CRLF & _
			'end' & @CRLF & _
			''
	Local $viDev = "127.0.0.1"
	__viScript($viDev, $sCmds, "", 1000)
	__viFlush($viDev)

EndFunc   ;==>oscopeTab_debug
#ce






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; VISA/SCPI instrument management functions
; ----------------------------------------------
;
; __viResolveInstrument(ByRef $oDev)							ensure the $oDev is an instrument handle
;   if oDev is already an instrument handle then no change needed
;   if oDev is a [raw:]IP[:port] address string then check if that IP is in the global instrument list.
;     if it is in the list, then change oDev to point to the instance in the global list.
;     if it is not in the list, then make a new entry and point oDev to it.
;   oDev can then be used for subsequent function calls for that visa device/instrument
;
; __viMakeInstrumentIndex($aIP)                                             ; given parsed IP address, make an instrument index string for $g_oViInstruments
; __viIsInstrument($viHandle)                                               ; confirm $viHandle is a visa instrument handle or not
; __IsDictionary($vVar)                                          ; confirm $vVar is a scripting dictionary or not
; __viParseIPaddress($ipAddr, $defPort = 0)									; parse [raw:]IP[:port] into IP, port, and raw
; __viMakeVisaAddress($ipAddr, $iPort = "", $iMode = 0)						; make a visa resource address, i.e. TCPIP0::IP::port::INSTR
; __viMakeInstrument($sIpAddr, $oDev = False)								; make instrument data structure from IP address
;
; Debug
; __viPrintInstrument($oDev)												; print the instrument data structure via handle
;



;		find visa instrument session handle in the global array
; in:	$oDev = visa device object (__viMakeInstrument) or address string [raw:]IPaddress[:port]
; out:	$oDev is converted from string to handle
;		returns true if successful, false if vihandle is invalid
Func __viResolveInstrument(ByRef $oDev)
	If __viIsInstrument($oDev) Then Return True                                 ; if already an instrument handle then nothing to do, return ok\
	If $oDev = "" Then Return False                                             ; if blank input then return fail
	Local $sIdx = __viMakeInstrumentIndex(__viParseIPaddress($oDev, ""))        ; assume it is an ip address and parse it
	If Not $g_oViInstruments.Exists($sIdx) Then _                               ; if not found in the file then create a new entry for it
			$g_oViInstruments.Item($sIdx) = __viMakeInstrument($oDev)
	$oDev = $g_oViInstruments.Item($sIdx)                                       ; point $oDev to the device data structure
	Return True                                                                 ; return ok
EndFunc   ;==>__viResolveInstrument



Func __viMakeInstrumentIndex($aIP)                                              ; given parsed IP address, make an instrument index string for $g_oViInstruments
	Local $sPort = $aIP[1]
	If $sPort = 5025 Or $sPort = "inst0" Then $sPort = ""                       ; if port number is default then make it blank
	If $sPort <> "" Then $sPort = ":" & $sPort
	Return $aIP[0] & $sPort                                                     ; search string to use to find existing instrument in global file $g_oViInstruments
EndFunc   ;==>__viMakeInstrumentIndex



Func __viIsInstrument($viHandle)                                                ; confirm $viHandle is a visa instrument handle or not
	If Not __IsDictionary($viHandle) Then Return False
	Return $viHandle.Exists('sAddr')
EndFunc   ;==>__viIsInstrument





;			_viParseIPaddress
; task:		parse IP address and port number from input
;			IP:Port
; in:		$ipAddr = IP address and Port number separated by a colon :
;			$defPort = default port to use if no port number found in $ipAddr
; out:		[0] = IP address
;			[1] = port number or default if not specified
;			[2] = 1 if "raw:" prefix found, or 0
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



;			__viMakeVisaAddress
; task:		generate VISA device address from an IP address
; in:		$ipAddr = IP address
;			$iMode = mode (0 = standard VXI-11, 1 = raw socket)
;			$iPort = port number to use for raw socket mode
; out:		VISA address string (TCPIP0::...)
Func __viMakeVisaAddress($ipAddr, $iPort = "", $iMode = 0)
	If $iMode Then
		Return "TCPIP::" & $ipAddr & "::" & (($iPort = "") ? "5025" : $iPort) & "::SOCKET"
	Else
		Return "TCPIP0::" & $ipAddr & "::" & (($iPort = "") ? "inst0" : $iPort) & "::INSTR"
	EndIf
EndFunc   ;==>__viMakeVisaAddress



;			__viMakeInstrument
; task:		make an vi instrument map data from the ip address string
; in:		$sIpAddr = ip address string format: [raw:]IP[:port]
Func __viMakeInstrument($sIpAddr, $oDev = False)
	Local $aIP = __viParseIPaddress($sIpAddr, "")                                       ; parse IP address for port number
	If $aIP[1] = "" Then $aIP[1] = ($aIP[2] ? 5025 : "inst0")                           ; if needed, fill in default port number

	If Not __viIsInstrument($oDev) Then $oDev = ObjCreate("Scripting.Dictionary")       ; create visa instrument object data structure
	; address and comm mode
	$oDev.Item('index') = __viMakeInstrumentIndex($aIP)                                 ; create index string to be able to refer back to the global instrument list
	$oDev.Item('sAddr') = ($aIP[2] ? "raw:" : "") & $aIP[0] & ":" & $aIP[1]             ; string address in the form [raw:]IP[:port]
	$oDev.Item('ipAddr') = $aIP[0]                                                      ; ip address
	$oDev.Item('viIpPort') = $aIP[1]                                                    ; ip address port part
	$oDev.Item('viIpMode') = $aIP[2]                                                    ; communication protocol 0=vxi-11, 1=raw socket
	$oDev.Item('viAddr') = __viMakeVisaAddress($aIP[0], $aIP[1], $aIP[2])               ; visa device address string

	; comm handles and state
	$oDev.Item('viSession') = 0                                                         ; visa handle when using visa dll communications
	$oDev.Item('viSocket') = 0                                                          ; socket handle for raw TCP socket protocol
	$oDev.Item('state') = 0                                                             ; true if session is open, false if closed
	;$oDev.Item('first') = 1                                                        	; true if this is the first communications with the device

	; modbus and F4T thermal chamber variables
	$oDev.Item('mbIpPort') = 502                                                        ; ModBus TCP IP port number
	$oDev.Item('mbSocket') = 0                                                          ; ModBus TCP receive buffer
	$oDev.Item('mbTransID') = 0x100                                                     ; ModBus transaction ID
	$oDev.Item('mbWordOrder') = 0                                                       ; F4T modbus word order 0=low-high, 1=high-low
	$oDev.Item('mbDataMap') = -1                                                        ; F4T thermal chamber data map 1=current, 2=legacy, -1=yet determined

	; request/command
	$oDev.Item('cmd') = ''                                                              ; command currently being processed
	$oDev.Item('timer') = 0                                                             ; timeout timer for background process TimerInit, TimerDiff
	$oDev.Item('timeout') = 1000                                                        ; timeout limit in milliseconds
	$oDev.Item('reqdone') = False                                                       ; request done flag for API usage.  set true when request, and if needed response, completes
	$oDev.Item('cStack') = __StackNew()                                                 ; this stack is used for processing flow control statements (if then/else/end, while/end, do/until)

	; async send
	$oDev.Item('upload') = 0                                                            ; handle of file currently being uploaded
	$oDev.Item('cdone') = True                                                          ; cmd done flag is set to true when a command complets
	$oDev.Item('creturn') = 1                                                           ; return code of last command executed.  1=ok, 0=error

	; async receive
	$oDev.Item('rMode') = 0                                                             ; 0=expecting visa data, 1=expecting modbus data
	$oDev.Item('rExpectedBytes') = 0                                                    ; number of bytes expected
	$oDev.Item('rHeaderParsed') = False                                                 ; IEEE488.2 header parsed, if it exists
	$oDev.Item('rHeaderLen') = 0                                                        ; length of the header
	$oDev.Item('rBuf') = Binary("")                                                     ; read buffer
	$oDev.Item('rCount') = 0                                                            ; number of bytes read
	$oDev.Item('download') = 0                                                          ; handle of file currently being downloaded
	$oDev.Item('rdone') = True                                                          ; response done flag is set to true when a response is received
	$oDev.Item('waitReply') = False                                                     ; flag to wait for reply before sending next command
	$oDev.Item('rVar') = ""                                                             ; variable name to store result into, or blank to push it onto the return queue
	;$oDev.Item('rJobActive') = False                                                    ; true if we have an active background visa network read job running
	;$oDev.Item('rJobBuf') = 0                                                           ; intake buffer for background read job
	;$oDev.Item('rJobId') = 0                                                            ; jobid of the background reading job


	; queues
	$oDev.Item('qreq') = __pQueNew()                                                    ; command/request queue
	$oDev.Item('qret') = __QueueNew()                                                   ; results queue

	Return $oDev
EndFunc   ;==>__viMakeInstrument





;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; debug
; -----------------------


Func __viPrintInstrument($oDev)
	If Not __IsDictionary($oDev) Then Return
	;__ConsoleWriteVar($oDev, @CRLF & "  ")
	__ConsoleWriteVar($oDev, ", ")
	ConsoleWrite(@CRLF)
EndFunc   ;==>__viPrintInstrument




;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; VISA/SCPI connection functions
; ----------------------------------------------
; open, close functions
;
; __viConnect($oDev)										ensure connection is established, returns false if fail
; __viInitSession($oDev)									for VXI-11 protocol, performs initial settings after opening a new session
;
; __viIsSessionOpen											check if session is connected/open
; __viOpen													open or reopen a session
; __viClose($oDev)											close visa session
;   __viCloseHandle($hVisa)									close visa handle (close session, resource manager, ...)
;
; __viMbOpen(ByRef $oDev)									open modbus connection
; __viMbClose($oDev)										close modbus connection
;
; validation functions
; __viCheckDLLhandle()										check if visa.dll is open, open if needed
;   __viIsDllHandleValid($hDll)								check if dll handle is valid
; __viCheckRMhandle()										check if visa resource manager is open, open if needed
;   __viIsResourceManagerValid($hRM, $hDll = $__viVisaDll)	check if visa resource manager handle is valid
; __viIsVisaHandleValid($hSession)							check if handle is a visa handle
; __IsTCPsocket($hSocket)									check if handle is a TCP socket
;   __SocketToIP($hSocket)								    test for TCP socket handle
;
; __viToggleMode($oDev)										toggle between raw socket and vxi-11 mode.  used to autodetect which mode works
;



;			__viConnect
; task:		ensure a connection is started
; in:		$oDev = visa instrument data structure
; out:		return 1 if successful, 0 if failed
Func __viConnect($oDev)
	If __viIsSessionOpen($oDev) Then Return True
	Return __viOpen($oDev)
EndFunc   ;==>__viConnect



; 			__viIsSessionOpen
; task:		determine if visa session is connected to device
; out:		true if either visa session handle is active, or if tcp socket handle is active
Func __viIsSessionOpen($oDev)
	If $oDev.Item('viIpMode') Then
		Local $hSocket = $oDev.Item('viSocket')
		If $hSocket = 0 Then Return False
		If __TCP_IsConnected($hSocket) Then Return True
		__viClose($oDev)                                                    ; if not active then make sure it is closed
		Return False
	Else
		Local $hSession = $oDev.Item('viSession')
		If $hSession = 0 Then Return False
		Local $tAttrState = DllStructCreate($__viSysUint32_64)              ; 2. Define the buffer according to the architecture size
		Local $iStatus = 1
		Local $aResult = DllCall($__vi_hDll, "long", "viGetAttribute", _    ; 3. Execute the System Call
				$__viSysUint32_64, $hSession, _
				"ulong", $VI_ATTR_RM_SESSION, _
				"struct*", $tAttrState)
		If Not @error Then $iStatus = $aResult[0]
		If $iStatus = $VI_SUCCESS Then Return True
		__viClose($oDev)
		Return False
	EndIf
EndFunc   ;==>__viIsSessionOpen



; =======================================================================================================================
; Function Name:    __TCP_IsConnected
; Description:      Checks if a TCP socket connection is still alive and active without blocking execution.
; Parameter(s):     $hSocket - The AutoIt TCP socket identifier variable.
; Return Value(s):  True  - The socket is open and actively connected.
;                   False - The socket has disconnected, timed out, or encountered a hardware error.
; =======================================================================================================================
Func __TCP_IsConnected($hSocket)
	Local $iSocketID = $hSocket
	If IsArray($hSocket) Then $iSocketID = $hSocket[0] ; Extract from AutoIt tracking array if needed
	If Number($iSocketID) <= 0 Then Return False

	; --- STEP 1: FORCE SOCKET INTO NON-BLOCKING MODE ---
	; FIONBIO constant = 0x8004667E. Mode = 1 (Non-blocking)
	Local $tMode = DllStructCreate("ulong")
	DllStructSetData($tMode, 1, 1)
	DllCall("ws2_32.dll", "int", "ioctlsocket", "handle", $iSocketID, "long", 0x8004667E, "struct*", $tMode)
	If @error Then Return False

	; --- STEP 2: RUN THE VERIFICATION PEEK VIA WINSOCK RECV ---
	; MSG_PEEK = 0x02. We use a tiny 1-byte binary buffer target.
	Local $tBuffer = DllStructCreate("byte")
	Local $aRecv = DllCall("ws2_32.dll", "int", "recv", _
			"handle", $iSocketID, _
			"struct*", $tBuffer, _
			"int", 1, _
			"int", 0x02) ; MSG_PEEK

	Local $bConnected = True
	Local $iError = 0

	If Not @error Then
		Local $iBytesReturned = $aRecv[0]

		If $iBytesReturned = 0 Then
			; A clean return of 0 bytes during a read indicates a graceful connection close by the remote host
			$bConnected = False
		ElseIf $iBytesReturned = -1 Then
			; Grab the specific Winsock failure reason code
			Local $aErr = DllCall("ws2_32.dll", "int", "WSAGetLastError")
			If Not @error Then $iError = $aErr[0]

			; --- ANALYSIS MATRIX ---
			; If it throws 10035 (WSAEWOULDBLOCK), the socket is healthy but simply empty!
			; Any other code (10054 Connection Reset, 10053 Aborted, etc.) means it is dead.
			If $iError <> 10035 Then $bConnected = False
		EndIf
	EndIf

	; --- STEP 3: RESTORE SOCKET BACK TO BLOCKING MODE ---
	; Mode = 0 (Standard AutoIt blocking behavior)
	DllStructSetData($tMode, 1, 0)
	DllCall("ws2_32.dll", "int", "ioctlsocket", "handle", $iSocketID, "long", 0x8004667E, "struct*", $tMode)

	Return $bConnected
EndFunc   ;==>__TCP_IsConnected



;			__viOpen
; task:		open the connection to the VISA instrument
;			if it is already open, then close it and reopen
; in:		$oDev = visa session
; out:		1 if successful, 0 if failure
Func __viOpen($oDev, $retry = 1)
	If $oDev.Item('state') Or $oDev.Item('viSession') Or $oDev.Item('viSocket') Then _  ; if previous session open, then close it
			__viClose($oDev)
	If $oDev.Item('viIpMode') Then                                                      ; if raw socket mode then
		If $oDev.Item('viIpPort') = "inst0" Then $oDev.Item('viIpPort') = 5025
		Local $hSocket = TCPConnect($oDev.Item('ipAddr'), $oDev.Item('viIpPort'))       ; Connect to the raw TCP Socket

		If @error = 10093 Then
			TCPStartup()                                                                ; if tcp not started yet, then start it and try to connect again
			Sleep(50)
			$hSocket = TCPConnect($oDev.Item('ipAddr'), $oDev.Item('viIpPort'))
		EndIf
		If @error Then Return SetError(@error, @extended, 0)                            ; return 0 if error
		$oDev.Item('viSocket') = $hSocket

		;; FIONBIO constant = 0x8004667E. Mode = 1 (Non-blocking)
		;Local $tMode = DllStructCreate("ulong")
		;DllStructSetData($tMode, 1, 1)
		;DllCall("ws2_32.dll", "int", "ioctlsocket", "handle", $hSocket, "long", 0x8004667E, "struct*", $tMode)

	Else                                                                                ; else we are using VXI-11 protocol
		__viCheckRMhandle()
		Local $aResult = __viOpenDllCall($oDev)
		Local $iStatus = $aResult[0]
		If $iStatus = 0xBFFF000E Then                                                   ; if error is RM not opened, then
			__viClose($__vi_hRM)
			__viCheckRMhandle()
			$aResult = __viOpenDllCall($oDev)                                           ; retry opening the visa session
			$iStatus = $aResult[0]
		EndIf
		If $iStatus < 0 Then Return SetError($iStatus, 0, 0)                            ; return 0 if error
		$oDev.Item('viSession') = $aResult[5]                                           ;  Index 5 corresponds to the final pointer parameter
		__viInitSession($oDev)
	EndIf
	$oDev.Item('state') = 1                                                             ; successfully connected the session
	Return 1
EndFunc   ;==>__viOpen

Func __viOpenDllCall($oDev)
	; ViStatus viOpen(ViSession rm_session, ViRsrc rsrcName, ViAccessMode accessMode, ViUInt32 timeout, ViSession *vi_session);
	Local $hSession_Out = 0
	Local $aRet = DllCall($__vi_hDll, "long", "viOpen", _                               ; _viOpen dll call
			$__viSysUint32_64, $__vi_hRM, _                                             ; Resource Manager Handle
			"str", $oDev.Item('viAddr'), _                                              ; VISA resource address String
			"ulong", 0, _                                                               ; Access Mode (0 = Default)
			"ulong", 0, _                                                               ; Timeout (0 = Default)
			$__viSysUint32_64ptr, $hSession_Out)                                        ; Dereferenced variable pointer to receive the Device Handle
	If @error Then Return SetError(@error, @extended, $aRet)
	Return $aRet
EndFunc   ;==>__viOpenDllCall



;			after session is open/connected, initialize select visa settings
Func __viInitSession($oDev)
	__viSetEOLchar($oDev, 0x0A)                             ; set EOL character to LineFeed
	__viSetEOLenable($oDev, 1)                              ; enable EOL character interpretation
	__viSetTimeout($oDev)                                   ; set timeout
EndFunc   ;==>__viInitSession



; task:		check RM and dll handles in viSession
;			if handles are 0 or expired, then reopen
Func __viCheckDLLhandle()
	If __IsDllHandleValid($__vi_hDll) Then Return                                     ; if valid then no further action needed
	$__vi_hDll = DllOpen($__viVisaDll)
	If @error Then $__vi_hDll = $__viVisaDll

	; check for bit-ness of visa driver (32 or 64 bit)
	; 2. AUTOMATED INSPECTION: Query the memory size of a generic tracking pointer.
	; This detects the TRUE architecture of the loaded driver regardless of your AutoIt compiler mode.
	Local $b64 = False
	Local $aArchTest = DllCall($__vi_hDll, "long", "viClose", "ptr", 0)
	If Not @error Then $b64 = @AutoItX64               ; if dllcall worked then visa.dll matches this autoit script bit-ness, set $b64 accordingly
	; else we fall back to 32-bit
	$__viVisaUint32_64 = $b64 ? "uint64" : "ulong"
	$__viVisaUint32_64ptr = $__viVisaUint32_64 & "*"
EndFunc   ;==>__viCheckDLLhandle



;			confirm visa RM is open
; out:		1 if ok, 0 if not open and unable to open
Func __viCheckRMhandle()
	__viCheckDLLhandle()
	If __viIsResourceManagerValid($__vi_hRM) Then Return 1                                 ; if valid then no further action needed
	Local $aResult = DllCall($__vi_hDll, "long", "viOpenDefaultRM", $__viSysUint32_64ptr, 0)  ; open the visa resource manager
	If @error Then
		ConsoleWrite("ERROR: 'visa32.dll' not found. Ensure NI-VISA runtime is installed." & @CRLF)
		Return SetError(@error, 0, 0)
	EndIf
	Local $iStatus = $aResult[0]
	If $iStatus < 0 Then
		ConsoleWrite("ERROR: Could not open Default Resource Manager. Status: 0x" & Hex($iStatus) & @CRLF)
		Return SetError($iStatus, 0, 0)
	EndIf
	$__vi_hRM = $aResult[1]
	Return 1
EndFunc   ;==>__viCheckRMhandle



; Function Name:    __viIsResourceManagerValid
; Description:      Queries visa32.dll to verify if a specific Resource Manager handle is live.
; Parameter(s):     $hRM   - The Resource Manager handle variable to test.
;                   $hDll  - Optional. The opened DLL handle context (or "visa32.dll" string).
; Return Value(s):  True   - The Resource Manager handle is recognized and active.
;                   False  - The handle is closed, invalid, or fake.
Func __viIsResourceManagerValid($hRM, $hDll = $__viVisaDll)
	If $hRM = 0 Or $hRM = "" Or $hRM = True Or $hRM = False Then Return False           ; 1. Early exit if the variable is empty or a structural boolean flag
	If Number($hRM) = 0 Then Return False
	Local $tBuffer = DllStructCreate("char[256]")                                       ; Local buffer allocation to hold string metadata
	Local $aResult = DllCall($hDll, "long", "viGetAttribute", _                         ; 3. Call viGetAttribute: Pass the RM handle, requested attribute ID, and output destination buffer
			$__viSysUint32_64, $hRM, _
			"ulong", $VI_ATTR_RSRC_CLASS, _
			"struct*", $tBuffer)
	If @error Then Return False                                                         ; 4. If the call failed structurally (e.g., DLL missing or bad signature structure), fail immediately
	Return ($aResult[0] = 0)                                                            ; 5. Element [0] holds the C function return ViStatus.
	;																					;    Status 0 (VI_SUCCESS) means the VISA backend successfully authenticated the object handle.
EndFunc   ;==>__viIsResourceManagerValid



; Function Name:    __viIsVisaHandleValid
; Description:      Queries visa32.dll directly to check if a session handle is live and authentic.
; Parameter(s):     $hSession - The variable containing the handle to test
; Return Value(s):  True  - The handle is authentic and open.
;                   False - The handle is dead, closed, or completely fabricated.
Func __viIsVisaHandleValid($hSession)
	If $hSession = "" Or $hSession = True _
			Or $hSession = False Then Return False                                  ; 1. Ensure it isn't an empty string or basic boolean flag
	If (Not IsInt($hSession)) And (Not IsPtr($hSession)) And _
			( Not (IsString($hSession) And _
			StringRegExp($hSession, "^0x[0-9a-fA-F]+$"))) Then Return False         ; 2. Ensure it is structurally a numeric pointer or integer token

	Local $tBuffer = DllStructCreate("char[256]")                                   ; Allocate a blank structure buffer to capture the text if successful

	Local $aResult = DllCall($__vi_hDll, "long", "viGetAttribute", _                ; Call viGetAttribute: target handle, requested attribute type, buffer pointer destination
			$__viSysUint32_64, $hSession, _
			"ulong", $VI_ATTR_RSRC_CLASS, _
			"struct*", $tBuffer)
	If @error Then Return False                                                     ; DLL call failed entirely (visa32.dll missing)
	Return ($aResult[0] = 0)                                                        ; Status code 0 (VI_SUCCESS) means VISA recognized the handle and answered the query
EndFunc   ;==>__viIsVisaHandleValid




;			__viClose
; task:		close VISA instrument session
Func __viClose($oDev)
	If __IsDictionary($oDev) Then
		If $oDev.Item('viSocket') Then TCPCloseSocket($oDev.Item('viSocket'))
		$oDev.Item('viSocket') = 0
		If $oDev.Item('viSession') Then __viCloseHandle($oDev.Item('viSession'))
		$oDev.Item('viSession') = 0
		If $oDev.Item('mbSocket') Then TCPCloseSocket($oDev.Item('mbSocket'))
		$oDev.Item('mbSocket') = 0
		$oDev.Item('state') = 0
	Else
		__viCloseHandle($oDev)
	EndIf
EndFunc   ;==>__viClose
Func __viCloseHandle($hVisa)
	If $hVisa = 0 Or $hVisa = "" Then Return
	DllCall($__viVisaDll, "long", "viClose", $__viSysUint32_64, $hVisa)                ;   close given handle by number
EndFunc   ;==>__viCloseHandle





; -----------------------------
; modbus open/close functions




;			__viMbOpen
; task:		open tcpsocket for modbus.  if already open, then close and reopen
; out:		1 if successful, 0 if error
Func __viMbOpen(ByRef $oDev)
	If Not __viResolveInstrument($oDev) Then Return 0
	Local $iErr
	Local $hSocket = $oDev.Item('mbSocket')
	If $hSocket Then __viMbClose($oDev)
	$hSocket = TCPConnect($oDev.Item('ipAddr'), $oDev.Item('mbIpPort'))
	$iErr = @error
	If $iErr = 10093 Then
		TCPStartup()
		Sleep(50)
		$hSocket = TCPConnect($oDev.Item('ipAddr'), $oDev.Item('mbIpPort'))
		$iErr = @error
	EndIf
	If $iErr Or $hSocket < 0 Then
		$oDev.Item('mbSocket') = 0
		Return SetError($iErr, 0, 0)
	EndIf
	$oDev.Item('mbSocket') = $hSocket
	Return 1
EndFunc   ;==>__viMbOpen



;			__viMbClose
; task:		close tcpsocket used for modbus
Func __viMbClose($oDev)
	If __IsDictionary($oDev) Then
		Local $hSocket = $oDev.Item('mbSocket')
		If __IsTCPsocket($hSocket) Then TCPCloseSocket($hSocket)
		$oDev.Item('mbSocket') = 0
	Else
		If __IsTCPsocket($oDev) Then TCPCloseSocket($oDev)
		$oDev = 0
	EndIf
EndFunc   ;==>__viMbClose




; -------------------------------------------------------
; toggle between raw socket and vxi-11 communication mode


;			__viToggleMode
; task:		toggle between raw and vxi-11 mode
; in:		$viHandle = session handle
;			if $oDev is an ip address it will be changed to a session handle
Func __viToggleMode($oDev)
	If Not __viIsInstrument($oDev) Then Return                  ; if not an instrument handle then do nothing
	Local $sIdx = $oDev.Item('index')
	Local $sIpAddr = $oDev.Item('ipAddr')
	Local $sIpPort = $oDev.Item('viIpPort')
	Local $iMode = Not $oDev.Item('viIpMode')                   ; toggle comm mode
	If $oDev.Item('state') Or $oDev.Item('viSession') _
			Or $oDev.Item('viSocket') Then __viClose($oDev)     ; if session is open, then close it
	If $iMode Then                                              ; toggle default ports between modes
		If Not StringIsInt($sIpPort) Then $sIpPort = ""
	Else
		If $sIpPort = 5025 Then $sIpPort = "inst0"
	EndIf
	If $sIpPort <> "" Then $sIpPort = ":" & $sIpPort
	Local $sAddr = ($iMode ? "raw:" : "") & $sIpAddr & $sIpPort
	__viMakeInstrument($sAddr, $oDev)                           ; overwrite data in oDev with a rebuilt handle
EndFunc   ;==>__viToggleMode



;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; VISA/SCPI attribute functions
; ----------------------------------------------
;
; __viSetAttribute($oDev, $iAttr, $iValue)							general set attributes function
; __viSetEOLenable($oDev, $bEnable)									enable or disable EOL detection in visa driver (disable for binary file transfers)
; __viSetEOLchar($oDev, $cChar)										set the EOL character (0x0A or LineFeed)
; __viSetTimeout($oDev, $iTimeoutMS = $oDev.Item('timeout'))		set the timeout for the visa driver
;



;			__viSetAttribute
; task:		set attributes of the VISA connection, only for VXI-11
; in:		$oDev = visa handle
;			$iattr = attribute id/number/address
;			$ivalue = new value for attribute
; out:		1 if successful, 0 if error
Func __viSetAttribute($oDev, $iAttr, $iValue)
	If $oDev.Item('viIpMode') Then Return 0                                ; we do not have attributes for the raw socket protocol
	DllCall($__vi_hDll, "long", "viSetAttribute", _
			$__viSysUint32_64, $oDev.Item('viSession'), _
			"ulong", $iAttr, _
			$__viVisaUint32_64, $iValue)
	Return (@error = 0)
EndFunc   ;==>__viSetAttribute



;			__viSetEOLenable
; task:		enable or disable EOL byte detection in the raw data
; in:		$oDev = session handle
; 			$bEnable = 0=disabled, 1=enabled
; out:		none
Func __viSetEOLenable($oDev, $bEnable)
	Return __viSetAttribute($oDev, 0x3FFF0038, $bEnable)
EndFunc   ;==>__viSetEOLenable



;			__viSetEOLchar
; task:		set the EOL character
; in:		$oDev = session handle
; 			$cChar
; out:		none
Func __viSetEOLchar($oDev, $cChar)
	Return __viSetAttribute($oDev, 0x3FFF0018, $cChar)
EndFunc   ;==>__viSetEOLchar



;			__viSetTimeout
; task:		set timeout attribute of the VISA connection
; in:		$oDev = visa handle
;			$iTimeoutMS = timeout in ms, or default to 'timeout' in $oDev
; out:		none
Func __viSetTimeout($oDev, $iTimeoutMS = $oDev.Item('timeout'))
	Return __viSetAttribute($oDev, $VI_ATTR_TMO_VALUE, $iTimeoutMS)
EndFunc   ;==>__viSetTimeout









;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; Modbus TCP functions
; ----------------------------------------------
;
; __viMbRead($oDev, $sFormat, $iRegAddr)							read a register,  $format=32i,32f,16i,16f for 32/16 bit integer/float
; __viMbWrite($oDev, $sFormat, $iRegAddr, $nValue)					write to a register
;
; __viMbMakeTCPframe($oDev, $bFunc, $iRegisterAddress, $sData)		make the TCP modbus frame
; __viMbReadBuf($oDev, $iMaxLen = 1460)								read from the modbus device
; __viMbExtractNumber($oDev, $bBufAcc, $sFormat)					extract the 32/16 i/f number from the read buffer
; __viMbW16toFloat16($w16)											extract 16 bit floating point number from 16 bit binary data
; __viMbFloat16toW16($nValue)										encode 16 bit float into 16 bit binary
; __viMbW32toFloat32($w32)											extract 32 bit floating point number from 32 bit binary
; __viMbFloat32toW32($nValue)										encode 32 bit float into 32 bit binary data
;



;				__viMbRead
; task:			read a register
; in:			$oDev = session handle
;				$iRegAddr = register address
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
; out:			1 if successful or 0 and @error
; note:			this only sends the read request, it does not wait for, nor read the response
Func __viMbRead($oDev, $sFormat, $iRegAddr)
	If Not __IsDictionary($oDev) Then Return 0
	Local $sPayload
	If StringLeft($sFormat, 2) = "16" Then
		$sPayload = __viMbMakeTCPframe($oDev, 0, $iRegAddr, 1)            ; build request frame (for one 16 bit register)
	Else
		$sPayload = __viMbMakeTCPframe($oDev, 0, $iRegAddr, 2)            ; build request frame (for one 32 bit register)
	EndIf

	Local $hSocket = $oDev.Item('mbSocket')
	If $hSocket = 0 Then
		If Not __viMbOpen($oDev) Then Return SetError(-1, 0, "")
		$hSocket = $oDev.Item('mbSocket')
	EndIf
	Return TCPSend($hSocket, Binary($sPayload))                         ; send request
EndFunc   ;==>__viMbRead



;				__viMbWrite
; task:			write a register
; in:			$oDev = session handle
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
;				$iRegAddr = register address
;				$nValue = value to write to register
; out:			1 if successful or 0 and @error
Func __viMbWrite($oDev, $sFormat, $iRegAddr, $nValue)
	If Not __IsDictionary($oDev) Then Return 0
	Local $sPayload
	If StringLeft($sFormat, 2) = "16" Then
		If StringRight($sFormat, 1) = "f" Then $nValue = __viMbFloat16toW16($nValue)
		Local $iB1 = Mod(Int($nValue / 0x100), 0x100)
		Local $iB2 = Mod($nValue, 0x100)
		$sPayload = __viMbMakeTCPframe($oDev, 1, $iRegAddr, Hex($iB1, 2) & Hex($iB2, 2)) ; build request frame to write
	Else
		If StringRight($sFormat, 1) = "f" Then $nValue = __viMbFloat32toW32($nValue)
		Local $iB1 = Mod(Int(Abs($nValue) / 0x1000000), 0x100) + (($nValue < 0) ? 0x80 : 0)
		Local $iB2 = Mod(Int(Abs($nValue) / 0x10000), 0x100)
		Local $iB3 = Mod(Int(Abs($nValue) / 0x100), 0x100)
		Local $iB4 = Mod(Abs($nValue), 0x100)
		Local $sHex = ""
		If $oDev.Item('mbWordOrder') Then
			$sHex = Hex($iB1, 2) & Hex($iB2, 2) & Hex($iB3, 2) & Hex($iB4, 2)       ; word order: high low
		Else
			$sHex = Hex($iB3, 2) & Hex($iB4, 2) & Hex($iB1, 2) & Hex($iB2, 2)       ; word order: low high
		EndIf
		$sPayload = __viMbMakeTCPframe($oDev, 1, $iRegAddr, $sHex)                    ; build request frame to write
	EndIf

	Local $hSocket = $oDev.Item('mbSocket')
	If $hSocket = 0 Then
		If Not __viMbOpen($oDev) Then Return SetError(-1, 0, "")
		$hSocket = $oDev.Item('mbSocket')
	EndIf
	Return TCPSend($hSocket, Binary($sPayload))                                     ; send request
EndFunc   ;==>__viMbWrite




; --- Modbus TCP Frame (ADU) ---
;      	Bytes 0-1: 		Transaction ID (auto increment for each new transaction)
;      	Bytes 2-3: 		Protocol ID (0x0000 = Modbus)
;      	Bytes 4-5: 		Remaining Length (number of bytes, 0x0006 bytes follow)
;      	Byte  6:   		Unit Identifier / Device Address (0x01)
;      	Byte  7:   		Function Code (0x03 = Read Holding Registers, 0x06 = single reg write, 0x10 = Write multiple Holding Registers)
;      	Bytes 8-9: 		Starting Reference Register Address (Big-Endian)
;		Bytes 10-11:  	Quantity - Number of 16-bit Registers to Read/write  (0x0001 = 2 bytes for 16-bit, 2 = 4 bytes for 32 bit)
;	   	Bytes 12...:  	Data Payload
;
;			__viMbMakeTCPframe
; task:		build a modbus tcp frame
; in:		$oDev = session handle
;			$bFunc = function 1=write, 0=read
;			$iRegisterAddress = register address (Big-Endian)
;			$sData = (read) number of registers to read
;				 	 (write) hex string of data payload to write
; out:		hex string of the frame to send in the tcp socket
Func __viMbMakeTCPframe($oDev, $bFunc, $iRegisterAddress, $sData)
	If Not __IsDictionary($oDev) Then Return ""
	Local $iTrans = $oDev.Item('mbTransID')
	$iTrans = Mod($iTrans + 1, 0xFFFF)                                      ; auto increment transaction id
	$oDev.Item('mbTransID') = $iTrans
	Local $iHiTrans = BitAND(BitShift($iTrans, 8), 0xFF)
	Local $iLoTrans = BitAND($iTrans, 0xFF)

	Local $iHiRegister = BitAND(BitShift($iRegisterAddress, 8), 0xFF)       ; register address high byte
	Local $iLoRegister = BitAND($iRegisterAddress, 0xFF)                    ; register address low byte
	Local Const $protocol = "0000"                                          ; modbus protocol
	Local Const $unitID = "01"                                              ; unit identifier number

	Local $iDataLen = Int(StringLen($sData) / 2)                            ; number of bytes in payload
	$bFunc = Number($bFunc)                                                 ; function: read(0) / write(1)
	Local $iFunction = $bFunc ? 0x10 : 0x03                                 ; use 0x10 = for multiple and single reg write.
	;Local $iFunction = $bFunc ? (($iDataLen > 2) ? 0x10 : 0x06) : 0x03      ; 0x10 = write multiple regs.  0x06=write single reg.  0x03=read reg(s)

	Local $len = 0x0006                                                     ; read packet has len 6 for this field
	If $bFunc Then $len = 0x07 + $iDataLen                                  ; write packet has additional bytes for payload

	Local $sPayload = "0x" & Hex($iHiTrans, 2) & Hex($iLoTrans, 2) & $protocol & _
			Hex($len, 4) & $unitID & Hex($iFunction, 2) & _
			Hex($iHiRegister, 2) & Hex($iLoRegister, 2)

	If $bFunc Then
		$sPayload &= Hex(Int($iDataLen / 2), 4) & Hex($iDataLen, 2) & $sData ; append data length and payload data
	Else
		$sPayload &= Hex(Number($sData), 4)                                 ; number of 16 bit registers to read
	EndIf
	Return $sPayload
EndFunc   ;==>__viMbMakeTCPframe




; -------------------------------------------------
; modbus data recieved handlers




;			__viMbReadBuf
; task:		nonblocking read - return any/all data currently received from modbus port device
; in:		$oDev = session handle
;			$iMaxLen = max number of bytes to read (default to one ethernet frame max size)
; out:		any data read as a binary data object
Func __viMbReadBuf($oDev, $iMaxLen = 1460)
	If Not __IsDictionary($oDev) Then Return SetError(-1, 0, Binary(""))
	Local $iErr, $iStatus, $bR
	Local $hSocket = $oDev.Item('mbSocket')
	If Not __IsTCPsocket($hSocket) Then Return SetError(-1, 0, Binary(""))
	If Not __TCP_IsDataAvailable($hSocket) Then Return Binary("")
	$bR = TCPRecv($hSocket, 64, 1)
	$iErr = @error
	If $iErr = 10093 Then
		TCPStartup()
		Sleep(50)
		__viMbOpen($oDev)
		If Not __TCP_IsDataAvailable($hSocket) Then Return Binary("")
		$bR = TCPRecv($hSocket, 64, 1)
		$iErr = @error
	EndIf
	Return SetError($iErr, 0, $bR)
EndFunc   ;==>__viMbReadBuf




;			__viMbExtractNumber
; task:		extract number from a register read reply modbus frame
; in:		$oDev = session handle
;			$bBufAcc = just the payload data from the modbus frame
;			$sFormat = 32i, 32f, 16i, 16f for 32 or 16 bit number, integer or floating point
; out:		number extracted from the payload data
Func __viMbExtractNumber($oDev, $bBufAcc, $sFormat)
	Local $vR
	If StringLeft($sFormat, 2) = "16" Then
		Local $iB1 = Int(BinaryMid($bBufAcc, 1, 1))
		Local $iB2 = Int(BinaryMid($bBufAcc, 2, 1))
		$vR = ($iB1 * 256) + $iB2
		If StringRight($sFormat, 1) = "f" Then $vR = __viMbW16toFloat16($vR)            ; if float interpretation then convert to float
	Else
		Local $iB1 = Int(BinaryMid($bBufAcc, 1, 1))                                     ; extract register value from response
		Local $iB2 = Int(BinaryMid($bBufAcc, 2, 1))
		Local $iB3 = Int(BinaryMid($bBufAcc, 3, 1))
		Local $iB4 = Int(BinaryMid($bBufAcc, 4, 1))
		If $oDev.Item('mbWordOrder') Then
			$vR = ($iB1 * 16777216) + ($iB2 * 65536) + ($iB3 * 256) + $iB4              ; word order: high low
		Else
			$vR = ($iB3 * 16777216) + ($iB4 * 65536) + ($iB1 * 256) + $iB2              ; word order: low high (default)
		EndIf
		If StringRight($sFormat, 1) = "f" Then $vR = __viMbW32toFloat32($vR)            ; if float interpretation then convert to float
	EndIf
	Return $vR
EndFunc   ;==>__viMbExtractNumber






; -----------------------------------------------
; float/int conversions




;				W16toFloat16
; task:			convert 16 bit binary data into a 16 bit floating point number
Func __viMbW16toFloat16($w16)
	Local $iSign = (BitAND($w16, 0x8000) = 0) ? 1 : -1
	Local $iExponent = BitShift(BitAND($w16, 0x7C00), 10)
	Local $iMantissa = BitAND($w16, 0x03FF)

	If $iExponent = 0 And $iMantissa = 0 Then Return 0.0
	If $iExponent = 255 Then
		If $iMantissa = 0 Then Return ($iSign / 0)            ; return +/- infinity
		Return 0 / 0                                          ; else return NaN
	EndIf

	$iExponent -= 15            ; remove bias component of exponent
	$iMantissa = 1.0 + $iMantissa / 0x0400
	Return Number($iSign * $iMantissa * (2 ^ $iExponent))
EndFunc   ;==>__viMbW16toFloat16



;				Float16toW16
; task:			convert a floating point number into a 16 bit binary data (stored as int16)
Func __viMbFloat16toW16($nValue)
	Local $iSign = ($nValue < 0) ? 1 : 0
	Local $nAbsVal = Abs($nValue)
	Local $iExponent = 0
	If $nAbsVal = 0 Then Return 0
	$iExponent = Floor(Log($nAbsVal) / Log(2))
	Local $nMantissa = ($nAbsVal / (2 ^ $iExponent)) - 1
	Local $iMantissaInt = Round($nMantissa * 0x0400)
	Return Number(($iSign * 0x8000) + (BitAND($iExponent + 15, 0x1F) * 0x0400) + BitAND($iMantissaInt, 0x03FF))
EndFunc   ;==>__viMbFloat16toW16



;				W32toFloat32
; task:			convert 32 bit binary data into a 32 bit floating point number
Func __viMbW32toFloat32($w32)
	Local $iSign = (BitAND($w32, 0x80000000) = 0) ? 1 : -1
	Local $iExponent = BitShift(BitAND($w32, 0x7F800000), 23)
	Local $iMantissa = BitAND($w32, 0x007FFFFF)

	If $iExponent = 0 And $iMantissa = 0 Then Return 0.0
	If $iExponent = 255 Then
		If $iMantissa = 0 Then Return ($iSign / 0)            ; return +/- infinity
		Return 0 / 0                                          ; else return NaN
	EndIf

	$iExponent -= 127            ; remove bias component of exponent
	$iMantissa = 1.0 + $iMantissa / 0x00800000
	Return Number($iSign * $iMantissa * (2 ^ $iExponent))
EndFunc   ;==>__viMbW32toFloat32



;				Float32toW32
; task:			convert a floating point number into a 32 bit binary data (stored as int32)
Func __viMbFloat32toW32($nValue)
	Local $iSign = ($nValue < 0) ? 1 : 0
	Local $nAbsVal = Abs($nValue)
	Local $iExponent = 0
	If $nAbsVal = 0 Then Return 0
	$iExponent = Floor(Log($nAbsVal) / Log(2))
	Local $nMantissa = ($nAbsVal / (2 ^ $iExponent)) - 1
	Local $iMantissaInt = Round($nMantissa * 0x800000)
	Return (($iSign * 0x80000000) + (BitAND($iExponent + 127, 0xFF) * 0x800000) + BitAND($iMantissaInt, 0x007FFFFF))
EndFunc   ;==>__viMbFloat32toW32


















;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; VISA/SCPI communication functions
; ----------------------------------------
;
; __viLoop()																	run this in the main loop to service background operations
;   __viLoopRead($oDev)															check for and process incomming SCPI replies
;   __viLoopWrite($oDev)														send chunks of file output when uploading a file to VISA device
;   __viLoopExec($oDev)															execute next queued VISA request when prior one is finished
;     __viReqSend($oDev, $sReq, $retry = 1)										send VISA request to device
;     __viEvalExprStrs($sText)										            convert "{expr}" into evaluated expr using autoit Execute(expr)
; __viWriteBuf($oDev, $sReq)													send one chunk of data to the visa device
;   __viWriteDll($oDev, ByRef $tBuf, $iLen)										dll call to visaNN.dll
; __viReadBuf($oDev, $iMaxLen = 1460)											read one chunk of data from the visa device
; __viFlushInputBuffer($oDev)													read input buffer until no more data available
;
; Request Queue functions - add VISA requests/commands here for processing
; __viReqQueuePush(ByRef $oDev, $sReq, $bWait = True, $iTimeoutMS = 1000)       push a request into queue
; __viReqQueueMakeItem($sReq, $bWait = True, $iTimeoutMS = 1000)                make the request item object for the request queue using the command parameters
; __viReqQueuePop($oDev)														pop a request out of the queue for processing
;
; Reply/Return Queue functions - pull replies to VISA requests from here
; __viRetQueuePush($oDev, $sRet, $iStatus = 0)                                  push return item into the return queue.  $sRet = return string, $iStatus=error status
; __viRetQueuePop($oDev, $bBin=false)                                           pull return item from return queue and return the string and error code
;
; __viParsePicture($sFile)														process a downloaded picture file, removing extra data from before the header
;																				and rename the file extension to match data format if needed
;



; -------------------------------------------------------------
; main loop function - service background processes
Func __viLoop()
	If Not __IsDictionary($g_oViInstruments) Then Return
	Local $oDev, $sKey
	For $sKey In $g_oViInstruments
		$oDev = $g_oViInstruments.Item($sKey)
		If Not __viIsInstrument($oDev) Then ContinueLoop
		__viLoopExec($oDev)                                                 ;   if ready then send next command from queue
		Local $hFile = $oDev.Item('upload')
		If $hFile Then __viLoopWrite($oDev, $hFile)                         ;   if uploading then send a chunk of outgoing data
		If $oDev.Item('waitReply') Then __viLoopRead($oDev)                 ;   if waiting for a reply then read any incomming data
	Next
EndFunc   ;==>__viLoop



;			__viLoopRead
; task:		check for incomming visa data/messages and read one buffer at a time
;			set internal variables and flags for updated status
Func __viLoopRead($oDev)
	Local $bModbus = $oDev.Item('rMode')                                                ; what type of reply are we expecting (modbus or visa)
	Local $aRet, $iStatus, $tBuf, $iRetCount

	If $bModbus Then                                                                    ; if in a modbus command then read modbus tcp port
		$tBuf = __viMbReadBuf($oDev)                                                    ;   read a chunk of data from modbus port
		$iStatus = 1                                                                    ;   1 If Not done, 0 If done
	Else                                                                                ; else we are in a visa command, read visa port
		$aRet = __viReadBuf($oDev)                                                      ;   read a chunk of data from visa port
		$iStatus = $aRet[0]
		$tBuf = $aRet[1]
	EndIf
	$iRetCount = BinaryLen($tBuf)

	If $iRetCount <= 0 Then                                                             ; if nothing received then check timeout and return
		If Not $oDev.Item('waitReply') Then Return                                      ; if not waiting for a reply then return
		If TimerDiff($oDev.Item('timer')) < $oDev.Item('timeout') Then Return              ; if no timeout yet then return
		$iStatus = -1073807339                                                          ; set status flag for timeout
	EndIf

	Local $hFile = $oDev.Item('download')
	Local $bBufAcc = $oDev.Item('rBuf')
	Local $bLeftOvers = Binary("")

	If $iRetCount > 0 Then                                                              ; if received data then process it
		Local $iExpectedBytes = $oDev.Item('rExpectedBytes')
		Local $iReadCount = $oDev.Item('rCount')

		$bBufAcc = Binary($bBufAcc & $tBuf)                                             ; add new bytes to buffer
		$oDev.Item('rBuf') = $bBufAcc
		$iReadCount += $iRetCount                                                       ; update read count
		$oDev.Item('rCount') = $iReadCount
		$oDev.Item('timer') = TimerInit()                                               ; reset timeout timer
		If $bModbus Then                                                                ; receiving MODBUS TCP frame
			If $iExpectedBytes < 0 Then                                                 ; check to see if we received the entire modbus frame
				If $iReadCount >= 6 Then                                                ; read frame length field
					$iExpectedBytes = 6 + Int(BinaryMid($bBufAcc, 5, 1)) * 0x100 + Int(BinaryMid($bBufAcc, 6, 1))          ; total number of expected bytes
					$oDev.Item('rExpectedBytes') = $iExpectedBytes
				EndIf
			EndIf
			If $iReadCount >= $iExpectedBytes Then $iStatus = 0                         ; if full frame received then set iStatus to 0 (ok), else leave it at 1 (needs more)
		Else                                                                            ; Receiving VISA SCPI data
			Local $bHeaderParsed = $oDev.Item('rHeaderParsed')
			Local $iHeaderLen = Int($oDev.Item('rHeaderLen'))

			If Not $bHeaderParsed And Number($iHeaderLen) <= 0 And $iReadCount >= 1 Then        ; dynamic parsing for IEEE 488.2 header
				If Int(BinaryMid($bBufAcc, 1, 1)) = 0x23 Then                                   ; 0x23 = "#"
					If $iReadCount >= 2 Then
						$iHeaderLen = Int(BinaryMid($bBufAcc, 2, 1)) - 0x30                     ; convert ascii digit to integer number
						$oDev.Item('rHeaderLen') = $iHeaderLen
						If Not $iHeaderLen Then
							$bHeaderParsed = True
							$oDev.Item('rHeaderParsed') = True
						EndIf
					EndIf
				Else
					$bHeaderParsed = True
					$oDev.Item('rHeaderParsed') = True
					$iHeaderLen = 0
					$oDev.Item('rHeaderLen') = 0
				EndIf
			EndIf

			If Not $bHeaderParsed Then
				If $iReadCount >= $iHeaderLen + 2 Then                      ; if IEEE 488.2 header found and fully received then decode and remove it from the buffer
					Local $iPayloadSize = Int(BinaryToString(BinaryMid($bBufAcc, 3, $iHeaderLen), 1))
					$iHeaderLen = 1 + 1 + $iHeaderLen
					$iExpectedBytes = $iHeaderLen + $iPayloadSize           ; Total block footprint = '#' symbol (1) + digit counter (1) + size digits + raw payload
					$oDev.Item('rExpectedBytes') = $iExpectedBytes
					$bBufAcc = BinaryMid($bBufAcc, $iHeaderLen + 1)         ; strip IEEE 488.2 header
					$bHeaderParsed = True
					$oDev.Item('rHeaderParsed') = True
				EndIf
			EndIf

			If $oDev.Item('viIpMode') Then                                  ; if in raw socket mode then
				If Not $bHeaderParsed Or Not $iHeaderLen Then               ;   if IEEE488.2 not found then
					Local $sBufAcc = BinaryToString($bBufAcc)
					Local $iLFpos = StringInStr($sBufAcc, @LF)              ;     look for LF end of visa message marker
					If $iLFpos Then
						Local $iLFposBefore = $iLFpos - 1
						If StringMid($sBufAcc, $iLFposBefore, 1) = @CR Then $iLFposBefore -= 1
						$iLFpos += 1
						If $iReadCount > $iLFpos Then _                     ;   save the left over data accumulated
								$bLeftOvers = BinaryMid($bBufAcc, $iLFpos)
						$bBufAcc = BinaryMid($bBufAcc, 1, $iLFposBefore)    ;   drop the CR and LF and any data accidentally read after it
						$iStatus = 0                                        ;   successful completion of receiving visa data
					EndIf
				EndIf
			EndIf

			If $g_viPrintLoopRead Then
				ConsoleWrite(@CRLF)
				__ConsolePrintVar("__viLoopRead", "bBufAcc", $bBufAcc, "iReadCount", $iReadCount, "bHeaderParsed", $bHeaderParsed, _
						"iHeaderLen", $iHeaderLen, "iExpectedBytes", $iExpectedBytes, "oDev", $oDev)
			EndIf

			If $hFile <> 0 And $bHeaderParsed Then                          ; write data to file instead of storing in buffer
				If $hFile > 0 Then
					FileWrite($hFile, $bBufAcc)
					If @error Then $iStatus = -1
				EndIf
				$oDev.Item('rBuf') = Binary("")
				$bBufAcc = Binary("")
			EndIf

			If $iReadCount >= 0x100000000 Then $iStatus = -3                ; buffer overflow
			If $bHeaderParsed And $iHeaderLen And ($iReadCount >= $iExpectedBytes) Then $iStatus = 0 ; if IEEE488.2 header, then stop when we receive all expected bytes
		EndIf
	EndIf

	If $iStatus <= 0 Then                                                   ; done reading response - 0=success, negative=error
		If $bModbus Then
			If $iStatus = 0 Then                                            ; if successfully received frame
				If $iReadCount > $iExpectedBytes Then $bLeftOvers = BinaryMid($bBufAcc, $iExpectedBytes + 1, $iReadCount - $iExpectedBytes)
				Local $iCount = Int(BinaryMid($bBufAcc, 9, 1))
				If $iCount > $iExpectedBytes - 9 Then $iCount = $iExpectedBytes - 9
				$bBufAcc = BinaryMid($bBufAcc, 10, $iCount)                 ; strip the frame header, leaving only the payload data
				Local $aCmd = StringSplit($oDev.Item('cmd'), " ")
				If UBound($aCmd) >= 3 Then $bBufAcc = __viMbExtractNumber($oDev, $bBufAcc, $aCmd[2])
			Else
				$bBufAcc = Binary("")                                       ; just in case we have error, set reply data to empty
			EndIf
		Else
			If $hFile Then FileClose($hFile)                                ; close the file if response written to file
			$oDev.Item('download') = 0
		EndIf
		If Not $hFile Then __viRetQueuePush($oDev, $bBufAcc, $iStatus)      ; push response/reply into return queue
		$oDev.Item('rHeaderParsed') = False                                 ; reinitialize settings to look for next incomming data
		$oDev.Item('rHeaderLen') = 0
		$oDev.Item('rExpectedBytes') = -1
		$oDev.Item('rBuf') = $bLeftOvers
		$oDev.Item('rCount') = BinaryLen($bLeftOvers)
		$oDev.Item('rdone') = True                                          ; signal main code that we have a newly received message
		$oDev.Item('waitReply') = False                                     ; signal cmd that it has received message and can move to next command
		$oDev.Item('reqdone') = True                                        ; signal request/command is complete
	EndIf
EndFunc   ;==>__viLoopRead




;			__viLoopWrite
; task:		if we have any pending file uploads then send the next chunk
Func __viLoopWrite($oDev, $hFile)
	Local $iErr = -1
	If $hFile > 0 Then
		Local $iBufN = 4096
		Local $bBuf = FileRead($hFile, $iBufN)
		$iErr = @error
		If Not $iErr Then                                       ; if ok then
			If Not __viWriteBuf($oDev, $bBuf) Then $iErr = -1   ;    write chunk to visa device, if error then signal EOT
		EndIf                                                   ; endif
	EndIf
	If $iErr <> 0 Then                                          ; if EOF or error then terminate the transmission
		FileClose($hFile)                                       ;   close the file
		$oDev.Item('upload') = 0
		Local $aRet[1]
		$oDev.Item('creturn') = __viWriteBuf($oDev, @CRLF)      ;   send terminate characters to the visa transmission
		$oDev.Item('cdone') = True
		If Not $oDev.Item('waitReply') Then _                   ;   if no reply needed, then raise the request done flag
				$oDev.Item('reqdone') = True
	EndIf                                                       ; endif
EndFunc   ;==>__viLoopWrite



;			__viLoopExec
; task:		start executing the next command from the queue
; out:		1 if successful, 0 if error
Func __viLoopExec($oDev)
	If $oDev.Item('cmd') = "s" Then                                                     ; if current command is "sleep" then
		If TimerDiff($oDev.Item('timer')) < $oDev.Item('timeout') Then Return 1         ;   if no timeout yet then return
		$oDev.Item('creturn') = 1                                                       ;   set return status to ok
		$oDev.Item('cdone') = True                                                      ;   else set command done flag and continue
		$oDev.Item('waitReply') = False
	EndIf                                                                               ; endif
	If Not $oDev.Item('cdone') Then Return 1                                            ; wait for previous command to complete
	If $oDev.Item('waitReply') Then Return 1                                            ; wait for previous command's reply to come in



	;
	; conditional statement processing:  processing stack for loops that are executing subsequent iterations
	;


	Local $oStack = $oDev.Item('cStack')                                                ; stack for flow control commands
	Local $bQreqEmpty = __pQueIsEmpty($oDev.Item('qreq'))

	;__ConsoleWriteVar($oDev, ", ", "__viLoopExecStack oDev")            ; debug
	;__ConsoleWriteVar($oStack, ", ", "__viLoopExecStack oStack")        ; debug

	#cs
		behavior of __viLoopExecStack
		. we check the execution stack for statement blocks that we looped back to
		  - we reprocess any statement blocks for loops
		  - at the end of the 'if' statement block, we flag to skip or execute following 'else' statement based on the condition
		  - we do not use the 'skip' flag inside the pQue here.  that is only used for __viLoopExecCmd below for the 'parked' real time interpreting
		. if there is no statement blocks, or the current statement block is parked, then we pull the next statement form the main queue and process it
	#ce


	Local $sCmd, $aReq, $bCond, $oStackTop, $bLoopExit, $bSkipElse = False

	Do
		$oStackTop = __StackPeek($oStack)

		;ConsoleWrite(@CRLF & @CRLF)
		;__ConsoleWriteVar($oStack, ", ", "__viLoopExec oStack")
		;__ConsoleWriteVar($oStackTop, ", ", "__viLoopExec oStackTop")

		$bLoopExit = True
		If __DequeIsDeque($oStackTop) Then $bLoopExit = __pQueIsParked($oStackTop)
		;__ConsoleWriteVar($bLoopExit, ", ", "__viLoopExec bLoopExit")
		If $bLoopExit Then                                                                  ; if cStack is empty or the pQue on the top of the stack is parked then
			If $bQreqEmpty Then Return __viLoopExecClose($oDev)                             ;   if no more commands in qreq and cStack is empty then close connection and return 1 (ok)
			$aReq = __viReqQueuePop($oDev)                                                  ;   pull next command to process from main queue
			ExitLoop                                                                        ;   jump to command processing
		EndIf                                                                               ; end if

		;ConsoleWrite(@CRLF & @CRLF & "Unparked queue - processing stack" & @CRLF)
		;__ConsoleWriteVar($oStack, ", ", "__viLoopExec oStack")
		;__ConsoleWriteVar($oStackTop, ", ", "__viLoopExec oStackTop")

		If __pQueIsStart($oStackTop) Then                                                   ; if we just started processing the oStackTop queue then
			$sCmd = __pQueCmd($oStackTop)                                                   ;   $sCmd = the command that created this block
			$bCond = False
			If $sCmd = "else" Then                                                          ;   if it is an 'else' block then
				$bCond = $bSkipElse                                                         ;     if previous 'if/then' block executed then we skip this 'else' block
				If $g_viPrintpQueCond Then _
						__ConsoleWriteVar(Not $bCond, ", ", "__viLoopExecStack else cond")

			ElseIf $sCmd = "if" Then                                                        ;   else if it is an 'if/then' block then
				$bCond = __viEvalExpr(__pQueCond($oStackTop))                               ;     evaluate the loop condition and if false then exit the block
				$oStackTop.Item('bCond') = $bCond
				If $g_viPrintpQueCond Then _
						__ConsoleWriteVar(__pQueCond($oStackTop), ", ", _
						"__viLoopExecStack if cond '" & $bCond & "'")
				$bCond = Not $bCond

			ElseIf $sCmd = "while" Then                                                     ;   else if it is a 'while' block then
				$bCond = Not __viEvalExpr(__pQueCond($oStackTop))                           ;     evaluate the loop condition and if false then exit the block
				If $g_viPrintpQueCond Then _
						__ConsoleWriteVar(__pQueCond($oStackTop), ", ", _
						"__viLoopExecStack while cond '" & Not $bCond & "'")

			EndIf                                                                           ;   end if
			If $bCond Then                                                                  ;   if condition is true then
				__StackPop($oStack)                                                         ;     exit the block
				ContinueLoop                                                                ;     loop back and recheck the stack
			EndIf                                                                           ;   end if

		ElseIf __pQueIsDone($oStackTop) Then                                                ; if we finished processing this statement block then

			If $g_viPrintCondCmds Then _
					__ConsoleWriteVar($oStackTop, ", ", _
					"__viLoopExec pQue is done")

			__pQueRestart($oStackTop)                                                       ;   reset PC to begining of the block
			$sCmd = __pQueCmd($oStackTop)                                                   ;   $sCmd = the command that created this block
			$bCond = True                                                                   ;   default to true to exit this block
			If $sCmd = "if" Then                                                            ;   if it is an 'if/then' block then
				$bSkipElse = $oStackTop.Item('bCond')                                       ;     if the 'if' cond was true then we skip the following 'else' block
				;$bCond = True

			ElseIf $sCmd = "while" Then                                                     ;   if it is a 'while' block then
				ContinueLoop                                                                ;     loop back and start from testing the condition

			ElseIf $sCmd = "until" Then                                                     ;   else if it is an 'until' block then
				$bCond = __viEvalExpr(__pQueCond($oStackTop))                               ;     if loop condition is true then set flag to exit the block
				If $g_viPrintpQueCond Then _
						__ConsoleWriteVar(__pQueCond($oStackTop), ", ", _
						"__viLoopExecStack until cond '" & $bCond & "'")

			EndIf                                                                           ;   end if
			If $bCond Then                                                                  ;   if condition is true then
				__StackPop($oStack)                                                         ;     exit the block
				ContinueLoop                                                                ;     loop back and recheck the stack
			EndIf                                                                           ;   end if

		EndIf                                                                               ; end if

		$aReq = __pQuePCitem($oStackTop)                                                    ; pull statement to execute from block
		$bLoopExit = Not __DequeIsDeque($aReq)                                              ; if aReq is a statement block then
		If Not $bLoopExit Then __StackPush($oStack, $aReq)                                  ;   push it onto the stack and loop back for processing
	Until $bLoopExit



	Local $sReq = "", $waitReply = False
	If IsArray($aReq) Then                                                                  ; parse command array
		Local $iCount = UBound($aReq)
		If $iCount < 1 Then Return 1
		$sReq = $aReq[0]
		$waitReply = ($iCount >= 2) ? $aReq[1] : False
		$oDev.Item('timeout') = ($iCount >= 3) ? $aReq[2] : 1000
	Else
		$sReq = $aReq
		$waitReply = (StringRight($sReq, 1) = "?")
		$oDev.Item('timeout') = 1000
	EndIf

	$oDev.Item('cdone') = True                                                              ; set command done flag as by default these commands are done before this function exits
	$oDev.Item('waitReply') = False                                                         ; waitReply flag is defaulted to false unless we get an actual visa command that needs it
	$oDev.Item('rMode') = 0                                                                 ; default to visa receive mode unless we get a modbus command



	;
	; conditional statement processing: first time processing
	;

	If $g_viPrintCondCmds Then __ConsoleWriteVar($aReq, ", ", @CRLF & "cond cmd")                            ; debug

	$sReq = StringStripWS($sReq, 3)                                                         ; trim leading and trailing white spaces
	If StringLeft($sReq, 1) = "#" Or $sReq = "" Then Return 1                               ; skip comments and blank lines


	;__ConsoleWriteVar($oDev, ", ", "__viLoopExecCmd oDev")      ; debug
	;__ConsoleWriteVar($sReq, ", ", "__viLoopExecCmd sReq")      ; debug


	Local $sArg, $sArg1, $sArg2
	__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                               ; parse the command string


	#cs
	    behavior of __viLoopExecCmd
		. if we have a non-conditional command then we push it into the statement block we are currently holding at the top of the stack
		  - if skip flag set then we do not process the command
		. if we encounter a conditional flow control statement
		  - if it starts a new statement block then we create a new pQue and push it onto the execution stack
		  - if we encounter a closing 'end' or 'until' statement then we close the statement block by popping it off the stack
		    . the closed statement block will still exist as an entry in the previous pQue item on the stack
			. the closed statement is also unparked so that the next time it is encountered it will be processed (if we loop back)
		  - if skip flag is set then we do not loop back, even if the loop condition flags us to do so
	
		behavior of the 'park' mode:
		. the pQue is parked when we have not received all of the statements in the block.  we continue to process them in real-time
	
		behavior of the 'skip' flag:
		. only used for pQues that are parked - real time processing script statements as we receive them
		. if the current statement block is marked 'skip' then if we push a new statement block on the stack then the new block is also 'skip'
		. while we process the commands, if the 'skip' flag is set, we process for flow control only, we do not execute the commands
		. if the 'skip' flag is set and we are closing a loop statement block, then we exit the loop
	#ce

	; process conditional flow control statements: if cond/then/else/end,  while cond/end,   do/until cond
	Local $spCmd = "", $bSkip = False                                                       ; $bSkip = skip flag from the most recent statement block we are executing inside
	If __DequeIsDeque($oStackTop) Then                                                      ; $spCmd = cmd that started the most recent statement block we are executing inside
		If __pQueIsParked($oStackTop) Then
			$bSkip = __pQueSkip($oStackTop)
			$spCmd = __pQueCmd($oStackTop)
		EndIf
	EndIf

	If $sCmd = "if" Then                                                                    ; if cmd is 'if' then
		If StringRight($sArg, 5) = " then" Then $sArg = StringTrimRight($sArg, 5)           ;   if a 'then' is added to the end of the line, remove it to get just the condition
		__viLoopExecStackPush($oStack, _
				__pQueNew($sCmd, $sArg), _
				Not __viEvalExpr($sArg))                                                    ;   push start of new 'if' statement block into cStack
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "else" Then                                                              ; else if cmd is 'else' then
		If $spCmd = "if" Then                                                               ;   close previous 'if' statement block and set 'skip' flag for this 'else' block
			$bSkip = Not $bSkip                                                             ;   'else' block 'skip' flag evaluate to opposite of 'if' block 'skip' flag
			__viLoopExecStackPop($oStack, $oStackTop)                                       ;   close the 'if' block
		EndIf
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg), $bSkip)                     ;   push start of new 'else' statement block into cStack
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "while" Then                                                             ; else if cmd is 'while' then
		$bSkip = Not __viEvalExpr($sArg)                                                    ;   evaluate cond before starting loop and set 'skip' flag as needed
		;__ConsoleWriteVar($bSkip, ", ", "cond cmd while bSkip")
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg), $bSkip)                     ;   push start of new 'while/end' statement block into cStack
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "end" Or $sCmd = "wend" Then                                             ; else if cmd is 'end' then close 'if' or 'while' block
		If $g_viPrintCondCmds Then __ConsoleWriteVar($oStack, ", ", "end cmd pre  oStack")      ; debug
		If $spCmd = "while" Then                                                            ;   if closing 'while' block then
			__pQueRelease($oStackTop)                                                       ;     unpark the block and leave it at the top of the stack for looping
			If $bSkip Then __viLoopExecStackPop($oStack, $oStackTop)                        ;     if skip flag set then pop the while block off the execution stack
		ElseIf $spCmd = "if" Then                                                           ;   else if closing 'if' block then
			__viLoopExecStackPop($oStack, $oStackTop)                                       ;     close the block and pop it off the stack
		ElseIf $spCmd = "else" Then                                                         ;   else if closing 'else' block then
			__viLoopExecStackPop($oStack, $oStackTop)                                       ;     close the block and pop it off the stack
		EndIf                                                                               ;   end if		(else it does not match any qualified statements, we ignore it)
		If $g_viPrintCondCmds Then __ConsoleWriteVar($oStack, ", ", "end cmd post oStack")      ; debug
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "do" Then
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg))                             ; push start of new 'do/until' statement block into cStack
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "until" Then
		If $spCmd <> "do" Then Return 1                                                     ; script has until without do, ignore until
		__pQueSet($oStackTop, $sCmd, $sArg)                                                 ; update the 'cmd' field to 'until'
		__pQueSetDone($oStackTop)                                                           ; set the queue to the 'done' state so it is caught on next cycle for evaluating loop condition
		If $bSkip Then __viLoopExecStackPop($oStack, $oStackTop)                            ; if skip flag set then do not loop this block
		Return 1                                                                            ;   return, we are done processing this statement
	EndIf



	If __DequeIsDeque($oStackTop) Then                                                      ; if we are processing a new command that is not in a pQue then
		If __pQueIsParked($oStackTop) Then
			__pQuePush($oStackTop, $aReq)                                                   ;   push a copy of the command into the oStackTop queue
			If __pQueSkip($oStackTop) Then Return 1                                         ;   if prior if statement condition evaluated to false then we skip processing this command
		EndIf
	EndIf                                                                                   ; end if

	$oDev.Item('cmd') = $sReq                                                               ; note current command being processed
	$oDev.Item('timer') = TimerInit()                                                       ; start timeout timer



	;
	; non-conditional statement processing
	;


	If $g_viPrintCmds Then __ConsoleWriteVar($aReq, ", ", "visa send")                      ; debug


	__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                               ; parse the command string


	; statement preprocessing
	Local $aMatch
	$aMatch = StringRegExp($sReq, "^\$\S*=", 1)                                             ;
	If Not @error Then                                                                      ; if req starts with $var= then
		Local $var = StringTrimRight($aMatch[0], 1)                                         ;   remove the trailing =
		If StringLeft($var, 1) = "$" Then $var = StringTrimLeft($var, 1)
		$oDev.Item('rVar') = $var
		$sReq = StringStripWS(StringTrimLeft($sReq, StringLen($aMatch[0])), 3)              ;   remove the $var= prefix from the command
		$waitReply = True                                                                   ;   force waitReply to true so we wait for the results
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf                                                                                   ; endif

	$aMatch = StringRegExp($sReq, "^((?i)upload::(.*?)::)", 1)
	If Not @error Then                                                                      ; if line starts with upload::filename:: then
		Local $sFile = $aMatch[1]                                                           ;   extract the filename
		$sReq = StringStripWS(StringTrimLeft($sReq, StringLen($aMatch[0])), 3)              ;   extract the command statement
		__viLoopExecUploadPrep($oDev, $sFile)                                               ;   open upload file for reading and set $oDev('upload') so it is sent along with visa command
		$waitReply = False
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf                                                                                   ; endif

	$aMatch = StringRegExp($sReq, "^((?i)download::(.*?)::)", 1)
	If Not @error Then                                                                      ; if line starts with download::filename:: then
		Local $sFile = $aMatch[1]                                                           ;   extract the filename
		$sReq = StringStripWS(StringTrimLeft($sReq, StringLen($aMatch[0])), 3)              ;   extract the command statement
		__viLoopExecDownloadPrep($oDev, $sFile)                                             ;   open download file for writing and set $oDev('download') so response is written to file
		$waitReply = True
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf                                                                                   ; endif



	If $g_viPrintCondCmds Then
		__ConsolePrintVar("exec cmd", "sReq", $sReq, "sArg", $sArg, "sArg1", $sArg1, "sArg2", $sArg2, "waitReply", $waitReply)
	EndIf



	;
	; statement processing:  script commands
	;


	If $sCmd = "sleep" Then
		$oDev.Item('cmd') = "s"                                                             ; $oDev.Item('cmd'] = "s" for sleep
		$oDev.Item('timeout') = Int(__viEvalExpr($sArg))                                    ; $oDev.Item('timeout'] = duration
		$oDev.Item('cdone') = False
		Return 1

	ElseIf $sCmd = "cd" Or $sCmd = "chdir" Then                                             ; change the current working directory
		FileChangeDir(__viEvalExprStrs($sArg))
		Return 1

	ElseIf $sCmd = "logfile" Then                                                           ; set the file name/path of the logfile
		$g_logfile = _PathFull(__viEvalExprStrs($sArg))
		Return 1

	ElseIf $sCmd = "log" Or $sCmd = "print" Then                                            ; write a line to the logfile - output data
		Local $hFile = FileOpen($g_logfile, $FO_APPEND)
		If $hFile > 0 Then
			FileWrite($hFile, __viEvalExprStrs($sArg) & @CRLF)
			FileClose($hFile)
		EndIf
		Return 1

	ElseIf $sCmd = "set" Then                                                               ; set a variable to a value, perform a function or evaluate expression
		If StringLeft($sArg1, 1) = "$" Then $sArg1 = StringTrimLeft($sArg1, 1)
		Assign($sArg1, __viEvalExpr($sArg2), 2)
		If $g_viPrintCondCmds Then __ConsoleWriteVar(Eval($sArg1), ", ", "set " & $sArg1)                            ; debug
		Return 1

	ElseIf $sCmd = "getret" Or $sCmd = "read" Then                                          ; take reply from previous command and assign it to a variable
		$sArg = __viEvalExprStrs($sArg)
		If StringLeft($sArg, 1) = "$" Then $sArg = StringTrimLeft($sArg, 1)
		Local $sR = __viRetQueuePop($oDev)                                                  ; pull return value from previous command
		If $sArg <> "" Then Assign($sArg, $sR, 2)
		Return 1

	ElseIf $sCmd = "upload" Then                                                            ; include this before the visa command that initiates the transfer
		__viLoopExecUploadPrep($oDev, __viEvalExprStrs($sArg))
		Return 1

	ElseIf $sCmd = "download" Then                                                          ; include this before the visa command that initiates the transfer
		__viLoopExecDownloadPrep($oDev, __viEvalExprStrs($sArg))
		Return 1

	ElseIf $sCmd = "parsepic" Then                                                          ; include this after download of a picture file
		Local $sFile = __viParsePicture(__viEvalExprStrs($sArg))                            ;   fix picture file (strip extra header, find extension), and return=file name
		__viRetQueuePush($oDev, $sFile)
		Return 1

	ElseIf $sCmd = "modbuswrite" Then                                                       ; send a modbus register write command
		$aArg = StringSplit(StringRegExpReplace(__viEvalExprStrs($sArg), "\s+", " "), " ")
		If UBound($aArg) >= 3 Then
			$oDev.Item('cmd') = "modbus write " & $aArg[0] & " " & $aArg[1] & " " & $aArg[2]
			__viMbWrite($oDev, $aArg[0], $aArg[1], $aArg[2])                                ; params: $oDev, type=(32|64)(i|f), address, value
		EndIf
		Return 1

	ElseIf $sCmd = "modbusread" Then                                                        ; send a modbus register read command
		$oDev.Item('waitReply') = True
		$oDev.Item('rMode') = 1                                                             ; expect modbus tcp frame reply
		$aArg = StringSplit(StringRegExpReplace(__viEvalExprStrs($sArg), "\s+", " "), " ")
		If UBound($aArg) >= 2 Then
			$oDev.Item('cmd') = "modbus read " & $aArg[0] & " " & $aArg[1]
			__viMbRead($oDev, $aArg[0], $aArg[1])                                           ; params: $oDev, type=(32|64)(i|f), address
		EndIf
		Return 1

	EndIf





	;
	; statement processing:  visa/scpi statement to send to visa device
	;

	If $sCmd = "write" Or $sCmd = "send" Then _                                             ; optional prefix visa statement with 'write' or 'send'
			$sReq = StringTrimLeft($sReq, StringLen($sCmd) + 1)                             ;   remove prefix

	$sReq = __viEvalExprStrs($sReq)                                                         ; evaluate expressions {expr} and substitute
	$oDev.Item('cmd') = $sReq                                                               ; note current command being processed
	If StringRight($sReq, 1) = "?" Then $waitReply = True                                   ; if request string ends in ? then assume we are getting a reply


	If Not __viConnect($oDev) Then                                                          ; if we cannot connect then
		If $waitReply Then                                                                  ;   if command wants a reply then push error code return
			__viRetQueuePush($oDev, "", -1)                                                 ;     push error code return
			$oDev.Item('creturn') = -1                                                      ;     set command return code to error
		EndIf                                                                               ;   end if
		$oDev.Item('reqdone') = True
		Return SetError(-1, 0, 0)                                                           ;   return error
	EndIf                                                                                   ; end if
	$oDev.Item('waitReply') = $waitReply                                                    ; set waitReply to what was requested

	;if $oDev.Item('viIpMode') then __viFlushInputBuffer($oDev)  							; if raw socket mode then flush input buffer before sending next command as a precaution

	If $oDev.Item('timeout') > 0 Then __viSetTimeout($oDev)                                 ; set visa timeout

	Local $hFile = $oDev.Item('upload')
	If StringLeft($hFile, 1) = "," Then                                                     ; if we are sending a file with this command then
		Local $iPos = StringInStr(StringMid($hFile, 2), ",")
		$oDev.Item('upload') = Int(StringMid($hFile, $iPos + 2))                            ;   extract the file handle
		Local $sHeader = StringMid($hFile, 2, $iPos - 1)                                    ;   extract the header
		$sReq &= $sHeader                                                                   ;   add IEEE 488.2 header
		__viSetEOLenable($oDev, 0)                                                          ;   disable EOL interpretation for binary file transfers
	Else                                                                                    ; else
		$sReq &= @CRLF                                                                      ;   add message terminator
		__viSetEOLenable($oDev, 1)                                                          ;   enable EOL interpretation for request string
	EndIf                                                                                   ; endif



	$oDev.Item('creturn') = __viReqSend($oDev, $sReq)                                       ; send the request string to the visa device

	If $waitReply Then $oDev.Item('rdone') = False                                          ; reset read done indicator if we need a reply
	If $hFile = 0 Then                                                                      ; if not a file upload operation then
		If Not $waitReply Then $oDev.Item('reqdone') = True                                 ;   if no reply needed, then raise the request done flag
	Else                                                                                    ; else file upload operation needs background time
		__viSetEOLenable($oDev, 0)                                                          ;   disable EOL interpretation for binary file transfers
		$oDev.Item('cdone') = False                                                         ;   clear the cdone flag
	EndIf                                                                                   ; end if

	Return 1
EndFunc   ;==>__viLoopExec



; task:		helper function for __viReq - write request to visa target
; out:		1 if successful, 0 if error
Func __viReqSend($oDev, $sReq, $retry = 1)
	__viWriteBuf($oDev, $sReq)                                                          ; send request
	If @error Then
		If $retry Then
			__viClose($oDev)                                                            ; attempt to close and reopen the tcp socket
			Sleep(10)
			__viOpen($oDev)
			Return __viReqSend($oDev, $sReq, 0)
		Else
			Return SetError(@error, 0, 0)
		EndIf
	EndIf
	Return 1
EndFunc   ;==>__viReqSend

Func __viLoopExecClose($oDev)                                                           ; no more commands in the queue, close connection and return 1
	__viClose($oDev)                                                                    ; close the visa connection
	__viMbClose($oDev)                                                                  ; close the modbus connection
	Return 1                                                                            ; return 1
EndFunc   ;==>__viLoopExecClose


Func __viLoopExecParseCmd($sReq, ByRef $sCmd, ByRef $sArg, ByRef $sArg1, ByRef $sArg2)  ; parse the command string
	Local $sLower, $iPos                                                                ; parse the command string to look for directives to act on here
	$sLower = StringLower($sReq)                                                        ;
	$iPos = StringInStr($sLower, " ")
	If $iPos Then
		$sArg = StringStripWS(StringMid($sReq, $iPos + 1), 3)                           ; $sArg = text after first word unparsed
		$sCmd = StringLeft($sLower, $iPos - 1)                                          ; $sCmd = first word in lower case
		$iPos = StringInStr($sArg, " ")
		If $iPos Then
			$sArg2 = StringStripWS(StringMid($sArg, $iPos + 1), 3)                      ; $sArg2 = text after second word unparsed
			$sArg1 = StringStripWS(StringLeft($sArg, $iPos - 1), 3)                     ; $sArg1 = second word only in lower case
		Else
			$sArg1 = $sArg
			$sArg2 = ""
		EndIf
		$sArg1 = StringLower($sArg1)
	Else
		$sArg = ""
		$sCmd = $sLower
		$sArg1 = ""
		$sArg2 = ""
	EndIf
EndFunc   ;==>__viLoopExecParseCmd


;		find all occurrences of "{expr}" and substitute with the evaluated expression usine execute(expr)
Func __viEvalExprStrs($sText)
	; Regex pattern to find matches inside curly braces: {(.*?)}
	; It uses lazy matching (.*?) so it stops at the very first closing brace.
	Local $sPattern = "{(.*?)}"
	While 1                                                                             ; Run a loop to find all occurrences
		Local $aMatch = StringRegExp($sText, $sPattern, 1)                              ; Check if there is an expression left in the text.  Return 1st match array
		If @error Then ExitLoop                                                         ; No more matches found, exit the loop
		Local $sExpression = $aMatch[0]                                                 ; Extract the raw expression string (e.g., "55.50 + 12.30")
		Local $vResult = Execute($sExpression)                                          ; Evaluate the expression dynamically
		If @error Then $vResult = "[ERROR: Invalid Expression, error=" & @error & "]"   ; If Execute fails or returns an error, handle it gracefully
		Local $sPlaceholder = "{" & $sExpression & "}"                                  ; We construct the literal placeholder string to target it accurately
		$sText = StringReplace($sText, $sPlaceholder, $vResult, 1)                      ; The '1' restricts it to the first occurrence.  We want to replace ONLY the first exact match
	WEnd
	Return $sText
EndFunc   ;==>__viEvalExprStrs


Func __viEvalExpr($sExpr)                                                               ; evaluate a single expression
	If StringLeft($sExpr, 1) = "{" Then $sExpr = StringTrimLeft($sExpr, 1)
	If StringRight($sExpr, 1) = "}" Then $sExpr = StringTrimRight($sExpr, 1)
	Local $vRet = Execute($sExpr)
	If @error Then $vRet = String($sExpr)
	;__ConsoleWriteVar($vRet, ", ", "__viEvalExpr('" & $sExpr & "') error=" & @error)
	Return $vRet
EndFunc   ;==>__viEvalExpr



Func __viLoopExecUploadPrep($oDev, $sArg)
	Local $iTotalBytes = FileGetSize($sArg)                                             ; get size of file
	If $iTotalBytes < 0 Or @error Then $iTotalBytes = 0
	Local $sDigits = String(StringLen(String($iTotalBytes)))                            ; Generate the IEEE 488.2 Definite Length Arbitrary Block header
	Local $sBlockHeader = "#" & $sDigits & $iTotalBytes                                 ; Format: #<num_digits><length><payload>
	$oDev.Item('upload') = "," & $sBlockHeader & "," & FileOpen($sArg, 16)              ; mode = 0(read) + 16(Binary)
EndFunc   ;==>__viLoopExecUploadPrep


Func __viLoopExecDownloadPrep($oDev, $sArg)
	$oDev.Item('download') = FileOpen($sArg, 18)                                        ; mode = 2(write/overwrite) + 16(binary)
EndFunc   ;==>__viLoopExecDownloadPrep


Func __viLoopExecStackPush($oStack, $opQue, $bSkip = False)                             ; push new opQue item onto cStack
	Local $oStackTop = __StackPeek($oStack)
	$bSkip = __pQueSkip($opQue) Or $bSkip                                               ; merge 'skip' flag with opQue's skip flag
	If __DequeIsDeque($oStackTop) Then                                                  ; additionally if opQue at top of stack is parked then push this opQue into it as well
		If __pQueIsParked($oStackTop) Then __pQuePush($oStackTop, $opQue)
		$bSkip = __pQueSkip($oStackTop) Or $bSkip                                       ; merge 'skip' flag from current opQue on top of stack
	EndIf
	__pQueSkip($opQue, $bSkip)                                                          ; set opQue 'skip' flag to merged bSkip
	__StackPush($oStack, $opQue)                                                        ; push opQue onto the stack
	If $g_viPrintCondCmds Then __ConsoleWriteVar($opQue, ", ", "__viLoopExecStackPush")     ; debug
EndFunc   ;==>__viLoopExecStackPush

Func __viLoopExecStackPop($oStack, $oStackTop)
	__pQueRelease($oStackTop)                                                           ; unpark the statement block on the top of the stack so it will be executed on next encounter
	__StackPop($oStack)                                                                 ; close the statement block by removing it from the stack
EndFunc   ;==>__viLoopExecStackPop






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; visa/scpi read/write functions
; ----------------------------




;			__viWrite
; task:		send data to the VISA instrument
; in:		$oDev = visa session handle
;			$sReq = request/command/data to send
; out:		1 if successful, 0 if error
Func __viWriteBuf($oDev, $sReq)

	If $oDev.Item('viIpMode') Then                                          ; raw socket mode
		TCPSend($oDev.Item('viSocket'), $sReq)                              ; Send the query over the socket stream
		If @error = 10093 Then
			TCPStartup()                                                    ; start TCP service
			Sleep(50)
			__viOpen($oDev)
			TCPSend($oDev.Item('viSocket'), $sReq)
		EndIf
		If @error Then
			__viOpen($oDev)                                                 ; reopen session
			TCPSend($oDev.Item('viSocket'), $sReq)                          ; Send the query over the socket stream
			If @error Then
				Local $iErr = @error
				__viClose($oDev)
				Return SetError($iErr, 0, 0)
			EndIf
		EndIf
	Else                                                                    ; VXI-11 mode
		Local $tBuf, $iLen
		If IsBinary($sReq) Then
			$iLen = BinaryLen($sReq)
			$tBuf = DllStructCreate("byte[" & $iLen + 1 & "]")
			DllStructSetData($tBuf, 1, $sReq)
		Else
			$iLen = StringLen($sReq)
			$tBuf = DllStructCreate("char[" & $iLen + 1 & "]")
			DllStructSetData($tBuf, 1, $sReq)
		EndIf

		Local $aRet = __viWriteDll($oDev, $tBuf, $iLen)                     ; send $tBuf
		Local $iStatus = -1
		If IsArray($aRet) Then $iStatus = $aRet[0]
		If $iStatus < 0 Then                                                ; if failed to write, then close and reopen the session and try again
			__viOpen($oDev)
			$aRet = __viWriteDll($oDev, $tBuf, $iLen)
			Local $iStatus = -1
			If IsArray($aRet) Then $iStatus = $aRet[0]
			If $iStatus < 0 Then
				__viClose($oDev)
				Return SetError($iStatus, 0, 0)
			EndIf
		EndIf
	EndIf

	Return 1
EndFunc   ;==>__viWriteBuf

Func __viWriteDll($oDev, ByRef $tBuf, $iLen)
	; ViStatus viWrite(ViSession vi, ViBuf buf, ViUInt32 count, ViPUInt32 retCount);
	Return DllCall($__vi_hDll, "long", "viWrite", _
			$__viSysUint32_64, $oDev.Item('viSession'), _
			"struct*", $tBuf, _
			"ulong", $iLen, _
			"ulong*", 0)     ; Number of bytes actually written (ignored here)
EndFunc   ;==>__viWriteDll




; ==============================================================================
; Function Name:    __viReadBuf
; Description:      Reads any available bytes from either a Raw Socket stream or
;                   an active VXI-11 Asynchronous I/O job container without blocking.
;                   Implements an ultra-fast temporary timeout gate to turn standard
;                   viRead blocks into instantaneous non-blocking network peeks.
; ==============================================================================
Func __viReadBuf($oDev, $iMaxLen = 1460)
	Local $aR = [-1, Binary("")]
	If Not __viIsInstrument($oDev) Then Return SetError(1, 0, $aR)
	Local $bData = Binary("")

	; -------------------------------------------------------------------------		; Stream Mode: Raw Socket
	If $oDev.Item('viIpMode') Then                                                  ;
		Local $hSocket = $oDev.Item('viSocket')
		If $hSocket = 0 Then Return SetError(2, 0, $aR)
		Local $bData = Binary("")
		Local $iErr = 0
		If __TCP_IsDataAvailable($hSocket) Then                                     ; nonblocking check if data is available
			$bData = TCPRecv($hSocket, $iMaxLen, 1)
			$iErr = @error
		EndIf
		If $iErr = 10093 Then
			TCPStartup()
			Sleep(50)
			__viOpen($oDev)
			If __TCP_IsDataAvailable($hSocket) Then
				$bData = TCPRecv($hSocket, $iMaxLen, 1)
				$iErr = @error
			EndIf
		EndIf
		$aR[0] = ($iErr = 0 ? 1 : $iErr)                                            ; return 1 = ok, but possibly more data remaining, to match vxi-11 return value
		$aR[1] = $bData
		Return SetError(($iErr <> 0), 0, $aR)
	EndIf


	; -------------------------------------------------------------------------		; Stream Mode: VXI-11 visa32.dll
	Local $hSession = $oDev.Item('viSession')
	If $hSession = 0 Then Return SetError(3, 0, $aR)
	Local Const $VI_ERROR_TMO = 0xBFFF0015                                          ; Signed equivalent = -1073807339

	Local $iOriginalTimeout = $oDev.Item('timeout')                                 ; Store your script's current global command timeout to restore it later
	If $iOriginalTimeout <= 0 Then $iOriginalTimeout = 2000
	__viSetTMO($hSession, 15)                                                       ; set timeout to 15 ms so we get instant return if no data available
	Local $tBuf = DllStructCreate("byte[" & $iMaxLen & "]")                         ; input buffer
	Local $tBytesRead = DllStructCreate("ulong")                                    ; Return counts are ALWAYS hardcoded 32-bit ulong
	Local $aRead = DllCall($__vi_hDll, "long", "viRead", _                          ; ViStatus viRead(ViSession vi, ViPBuf buf, ViUInt32 count, ViPUInt32 retCount);
			$__viSysUint32_64, $hSession, _                                         ;   Primary Session Handle (Scales 32/64 bit)
			"struct*", $tBuf, _                                                     ;   Data Buffer structure location
			"ulong", $iMaxLen, _                                                    ;   Pull full footprint width per pass
			"struct*", $tBytesRead)                                                 ;   Captured bytes written pointer tracking reference
	If @error Or Not IsArray($aRead) Then                                           ; if error then
		__viSetTMO($hSession, $iOriginalTimeout)                                    ;   restore timeout setting
		Return SetError(-1, 0, $aR)                                                 ;   return error
	EndIf                                                                           ; endif
	Local $iStatus = $aRead[0]                                                      ; status of viRead
	__viSetTMO($hSession, $iOriginalTimeout)                                        ; restore original timeout setting
	If $iStatus = $VI_ERROR_TMO Then                                                ; if timeout then we received no data
		$aR[0] = 1
		Return $aR
	EndIf
	$aR[0] = $iStatus                                                               ; set return status code, expect 0 for VI_SUCCESS or 0x3FFF0006 for full buffer markers
	If $iStatus < 0 Then Return SetError(1, 0, $aR)
	Local $iBytesRead = DllStructGetData($tBytesRead, 1)                            ; success: data arrived, extract it
	If $iBytesRead > 0 Then $bData = BinaryMid(DllStructGetData($tBuf, 1), 1, $iBytesRead)
	$aR[1] = $bData
	Return $aR
EndFunc   ;==>__viReadBuf

Func __viSetTMO($hSession, $iTmo)
	Return DllCall($__vi_hDll, "long", "viSetAttribute", $__viSysUint32_64, $hSession, "ulong", $VI_ATTR_TMO_VALUE, "ulong", $iTmo)
EndFunc   ;==>__viSetTMO



; =======================================================================================================================
; Function Name:    __TCP_IsDataAvailable
; Description:      Checks if there is incoming data waiting to be read in the socket buffer without blocking.
; Parameter(s):     $hSocket - The AutoIt TCP socket identifier variable.
; Return Value(s):  True  - Data is waiting in the buffer. Safe to call TCPRecv() instantly.
;                   False - No data is available to read at this moment.
; =======================================================================================================================
Func __TCP_IsDataAvailable($hSocket)
	; Extract raw Win32 socket handle descriptor if AutoIt passed it as a tracking array
	Local $iSocketID = $hSocket
	If IsArray($hSocket) Then $iSocketID = $hSocket[0]
	If Number($iSocketID) <= 0 Then Return False

	; Create a Win32 fd_set structure layout template
	; struct fd_set { u_int fd_count; SOCKET fd_array[1]; }
	Local $tFD_SET = DllStructCreate("uint fd_count;handle fd_array")
	DllStructSetData($tFD_SET, "fd_count", 1)
	DllStructSetData($tFD_SET, "fd_array", $iSocketID, 1)

	; Create an immediate-timeout timeval structure (0 seconds, 0 microseconds)
	Local $tTimeVal = DllStructCreate("long tv_sec;long tv_usec")
	DllStructSetData($tTimeVal, "tv_sec", 0)
	DllStructSetData($tTimeVal, "tv_usec", 0)

	; Call the Winsock select API targeting readfds (the second parameter)
	Local $aRet = DllCall("ws2_32.dll", "int", "select", _
			"int", 0, _                 ; nfds (ignored in Windows)
			"struct*", $tFD_SET, _      ; readfds (checks if data is ready to read)
			"ptr", 0, _                 ; writefds (omitted)
			"ptr", 0, _                 ; exceptfds (omitted)
			"struct*", $tTimeVal)       ; timeout structure pointer

	If @error Or $aRet[0] <= 0 Then Return False ; DllCall failed or select returned 0 (timeout/no data)

	Return True ; Data is physically waiting in the socket buffer!
EndFunc   ;==>__TCP_IsDataAvailable



;			__viFlushInputBuffer
; task:		flush the input buffer until all previous data is emptied out of it
Func __viFlushInputBuffer(ByRef $oDev)
	If Not __viResolveInstrument($oDev) Then Return 0
	Local $sTrash, $iErr
	; Set a tight timeout or loop quickly to consume all residual data
	If $oDev.Item('viIpMode') Then
		Local $hSocket = $oDev.Item('viSocket')
		Do
			If __TCP_IsDataAvailable($hSocket) Then _
					$sTrash = TCPRecv($hSocket, 2048, 1)        ; Read up to 2048 bytes at a time
			$iErr = @error
		Until $sTrash = "" Or $iErr
	Else
		Do
			$sTrash = __viReadBuf($oDev, 0x400)
			$iErr = @error
		Until $sTrash = "" Or $iErr
	EndIf
	Return 1
EndFunc   ;==>__viFlushInputBuffer





;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; VISA/SCPI queue request and reply functions
; -------------------------------------------------------------



;			add request to request queue
; in:		$oDev = instrument handle
;			$sReq = request/command string
;			$bWait = true to wait for response
;			$iTimeoutMS = timeout to wait for response
Func __viReqQueuePush(ByRef $oDev, $sReq, $bWait = True, $iTimeoutMS = 1000)        ; add request to request queue
	If Not __viResolveInstrument($oDev) Then Return False
	Local $aReq = __viReqQueueMakeItem($sReq, $bWait, $iTimeoutMS)
	If $g_viPrintQueuePush Then ConsoleWrite(@CRLF & "__viReqQueuePush ")
	__pQuePush($oDev.Item('qreq'), $aReq)
	;If $g_viPrintQueuePush Then __ConsoleWriteVar($aReq, ", ", "qout push")
EndFunc   ;==>__viReqQueuePush

Func __viReqQueueMakeItem($sReq, $bWait = True, $iTimeoutMS = 1000)                 ; make the request item object for the request queue
	Local $aReq[3]                                                                  ; request queue item structure
	$aReq[0] = $sReq                                                                ; [0] = visa request/command string
	$aReq[1] = $bWait                                                               ; [1] = wait flag
	$aReq[2] = $iTimeoutMS                                                          ; [2] = timeout for this command
	Return $aReq
EndFunc   ;==>__viReqQueueMakeItem


Func __viReqQueuePop($oDev)
	Local $aR[] = ["", False, 1000]
	If Not __viIsInstrument($oDev) Then Return $aR                                  ; if issue then return empty request
	If __pQueIsEmpty($oDev.Item('qreq')) Then Return $aR                            ; if queue is empty then return empty request
	If $g_viPrintQueuePop Then ConsoleWrite("__viReqQueuePop ")
	$aR = __pQuePop($oDev.Item('qreq'))                                             ; pull next request
	If $g_viPrintQueuePop Then __ConsoleWriteVar($aR, ", ", "qout pop ")
	Return $aR
EndFunc   ;==>__viReqQueuePop



Func __viRetQueuePush($oDev, $sRet, $iStatus = 0)                                   ; push return item into the return queue.  $sRet = return string, $iStatus=error status
	If Not __viIsInstrument($oDev) Then Return SetError(-1, 0, 0)
	Local $rVar = $oDev.Item('rVar')
	If $rVar <> "" Then
		If StringRight($rVar, 4) <> "Data" Then $sRet = StringStripWS(BinaryToString($sRet), 3)             ; if variable name ends in "Data" then leave the result as a binary object
		Assign($rVar, $sRet, 2)
		If $g_viPrintQueuePush Or $g_viPrintQueuePop Then __ConsoleWriteVar($sRet, ", ", "qin $" & $rVar)
		If $g_viPrintCmds Then __ConsoleWriteVar($sRet, ", ", "visa recv: $" & $rVar)
		$oDev.Item('rVar') = ''
	Else
		Local $a[2]
		$a[0] = $sRet
		$a[1] = $iStatus
		__QueuePush($oDev.Item('qret'), $a)
		If $g_viPrintQueuePush Then __ConsoleWriteVar($a, ", ", "qin  push")
		If $g_viPrintCmds Then __ConsoleWriteVar(StringStripWS(BinaryToString($sRet), 3), ", ", "visa recv")
	EndIf
	Return 1
EndFunc   ;==>__viRetQueuePush



Func __viRetQueuePop($oDev, $bBin = False)                                          ; pull return item from return queue and return the string and error code
	If Not __viIsInstrument($oDev) Then Return SetError(-1, 0, "")
	Local $aRet = __QueuePop($oDev.Item('qret'))
	Local $iErr = @error
	Local $sRet = ""
	If IsArray($aRet) Then
		If UBound($aRet) >= 2 Then $iErr = $aRet[1]
		If UBound($aRet) >= 1 Then $sRet = $aRet[0]
	Else
		$sRet = $aRet
	EndIf
	If Not $bBin Then $sRet = StringStripWS(BinaryToString($sRet), 3)
	If $g_viPrintQueuePop Then __ConsoleWriteVar($oDev.Item('creturn') & "," & $iErr & "," & $sRet, ", ", "qin  pop ")
	Return SetError($iErr, 0, $sRet)
EndFunc   ;==>__viRetQueuePop







;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; VISA/SCPI misc functions
; --------------------------------------



; task:		strip header from data stream leaving only the picture file
; in:		$sFile = file name or binary picture data
; out:		if file is identified as .png, .gif, .bmp, or .jpg then the file extension will be updated
;			the (new) file name is returned
;			if binary data is given then $sFile is updated to have the head trimed up to the picture data
Func __viParsePicture(ByRef $sFile)
	Local $bData, $sFilePath = ''
	Local $sDrive, $sDir, $sName, $sExt, $sNewExt                   ; break down the file path name and extension
	If Not IsBinary($sFile) Then
		$sFilePath = _PathFull($sFile)                              ; sanitize it
		_PathSplit($sFilePath, $sDrive, $sDir, $sName, $sExt)
		$sFilePath = _PathMake($sDrive, $sDir, $sName, $sExt)
		Local $iSize = FileGetSize($sFilePath)                      ; get the file size
		If @error Then Return $sFile
		Local $hFile = FileOpen($sFilePath, 0 + 16)                 ; open file for reading 0(read)+16(binary)
		If $hFile < 0 Then Return $sFile
		$bData = FileRead($hFile, $iSize)                           ; read file into memory
		FileClose($hFile)                                           ; close file
	Else
		$bData = $sFile
	EndIf

	Local $iByteStartOffset = -1
	Local $sHexText = String($bData)                                ; 1. Convert to a standard text string representation for accurate character indexing

	If $iByteStartOffset < 0 Then
		Local $iGifPos = StringInStr($sHexText, "474946383761", 1)  ; Hex for GIF87a
		If $iGifPos > 0 Then
			$sNewExt = ".gif"
			$iByteStartOffset = (($iGifPos - 3) / 2) + 1            ; Formula: Remove the "0x" (2 chars), divide text characters by 2 to get bytes, add 1 for 1-based index
		EndIf
	EndIf
	If $iByteStartOffset < 0 Then
		Local $iPngPos = StringInStr($sHexText, "89504E47", 1)      ; Hex for PNG
		If $iPngPos > 0 Then
			$sNewExt = ".png"
			$iByteStartOffset = (($iPngPos - 3) / 2) + 1
		EndIf
	EndIf
	If $iByteStartOffset < 0 Then
		Local $iBmpPos = StringInStr($sHexText, "424D", 1)          ; Hex for BM - BMP files
		If $iBmpPos > 0 Then
			$sNewExt = ".bmp"
			$iByteStartOffset = (($iBmpPos - 3) / 2) + 1
		EndIf
	EndIf
	If $iByteStartOffset < 0 Then
		Local $iJpgPos = StringInStr($sHexText, "FFD8FF", 1)        ; Hex for SOI start of image marker for Jpg
		If $iJpgPos > 0 Then
			$sNewExt = ".jpg"
			$iByteStartOffset = (($iJpgPos - 3) / 2) + 1
		EndIf
	EndIf

	If $iByteStartOffset > 0 Then                                   ; 3. Safely slice the binary data using the true byte index position
		$bData = BinaryMid($bData, $iByteStartOffset)               ; trim the header until we get to the picture data
		If $sFilePath <> '' Then
			$hFile = FileOpen($sFilePath, 2 + 16)                   ; save over the original file
			FileWrite($hFile, $bData)
			FileClose($hFile)
		EndIf
	EndIf
	If $sFilePath <> '' Then
		Local $sFileNew = _PathMake($sDrive, $sDir, $sName, $sNewExt)
		If $sExt <> $sNewExt Then FileMove($sFilePath, $sFileNew)      ; if needed, rename the file extension to match
		Return $sFileNew
	EndIf
	$sFile = $bData     ; update binary data variable passed byref
	Return $sNewExt     ; return just the identified extension (.jpg, .bmp, .png, .gif...)
EndFunc   ;==>__viParsePicture











;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------


; SCPI/VISA functions
; ==============================================================================
;
; Nonblocking API interface functions
;
; __viReq($oDev, $sReq, $bWait)			send request
; __viCmd($oDev, $sCmd)					send command (__viReq $bWait=false)
; __viIsReqDone($oDev)					return true if prior command is done
; __viCmdRetStatus($oDev)				return exit status of prior command
; __viIsIdle($oDev)						check if all commands have been sent (including waiting for the last response to be received)
; __viHasRet($oDev)						check if there is a response received
; __viRet($oDev,$bBin=False)			pull the received response
;
; __viLoop()							run this periodically in main loop to service all visa transactions
;


;			__viReq
; in:		$oDev = vi device index or IP address
;			$sReq = request/command
;			$bWait = true to wait for a response before sending next request
; out:		return true if successful
Func __viReq(ByRef $oDev, $sReq, $bWait = True, $iTimeoutMS = 1000)
	Return __viReqQueuePush($oDev, $sReq, $bWait, $iTimeoutMS)
EndFunc   ;==>__viReq

Func __viCmd(ByRef $oDev, $sCmd)
	Return __viReq($oDev, $sCmd, False, 0)
EndFunc   ;==>__viCmd

Func __viUploadFile(ByRef $oDev, $sFile, $sReq, $iTimeoutMS = 15000)
	Return __viReq($oDev, "upload::" & $sFile & "::" & $sReq, False, $iTimeoutMS)
EndFunc   ;==>__viUploadFile

Func __viDownloadFile(ByRef $oDev, $sFile, $sReq, $iTimeoutMS = 15000)
	Return __viReq($oDev, "download::" & $sFile & "::" & $sReq, True, $iTimeoutMS)
EndFunc   ;==>__viDownloadFile

Func __viDownloadPicture(ByRef $oDev, $sFile, $sReq, $iTimeoutMS = 15000)
	__viDownloadFile($oDev, $sFile, $sReq, $iTimeoutMS)
	__viCmd($oDev, "parsePic " & $sFile)
EndFunc   ;==>__viDownloadPicture



;			__viSaveScreenShot
; task:		grab screenshot and save it to file
; in:		$oDev = ipAddr or visa session handle
;			$sFile = path and name of destination file
;			$aCmds = commands to send visa device in order to start the download
;				each command is [ $sCmd, $iTimeout ]
;				The command that initiates the file transfer must have "!" proceeding it
; out:		none
Func __viSaveScreenShot(ByRef $oDev, ByRef $sFile, $aCmds)
	If Not IsArray($aCmds) Then Return
	If UBound($aCmds, 2) <> 2 Then Return
	Local $i, $iTout, $sCmd, $iN = UBound($aCmds, 1) - 1
	For $i = 0 To $iN                                                           ; send commands to the queue
		$iTout = $aCmds[$i][1]
		$sCmd = $aCmds[$i][0]
		If StringLeft($sCmd, 1) = "!" Then
			$sFile = __FileNameAutoIncrement($sFile)                            ; $sFile is also modified (passed byref)
			__viDownloadPicture($oDev, $sFile, StringMid($sCmd, 2), $iTout)
		Else
			__viReq($oDev, $sCmd, ($iTout > 0), $iTout)
		EndIf
	Next
EndFunc   ;==>__viSaveScreenShot



;			__viScript
; task:		push a series of commands into the queue
; in:		$oDev = ipAddr or visa session handle
;			$vCmds = commands to send visa device in order to start the download
;			    . This can be a string of commands with EOL separators (@LF or @CRLF)
;				  It can also be an array of commands
;				    If it is a 2D array then the 2nd column is the timeout for each command
;				  If can be a map or dictionary object with a list of commands
;				. Any command that initiates the file transfer must have "#" proceeding it - the reply will be downloaded to the file
;				. Any command proceeded by "##" will have the reply downloaded to the file and it parsed as a picture
;				. multiple downloads can be done, the $sFile will have its name autoincremented
;				. if command is proceeded by "number!" then the number is used as the timeout for that command
;			$sFile = path and name of destination file used for any lines that are proceeded by "#"
;			$iTimeoutMS = timeout for file transfers
; out:		all names of downloaded files are pushed into the qret queue, use __viRet to retrieve
Func __viScript(ByRef $oDev, $vCmds, $sFile = "", $iTimeoutMS = 1000)
	Local $aCmds[0]
	If __IsDictionary($vCmds) Then                      ; check script input and convert it to an array of commands for processing
		If __DequeIsDeque($vCmds) Then
			$aCmds = __DequeToArray($vCmds)             ; convert queue to array
		Else
			Local $sKey, $iCount = $vCmds.Count         ; convert dictionary to array
			ReDim $aCmds[$iCount]
			Local $i = 0
			For $sKey In $vCmds
				$aCmds[$i] = $vCmds.Item($sKey)
				$i += 1
			Next
		EndIf
	ElseIf IsMap($vCmds) Then                           ; convert map to array
		$aCmds = MapKeys($vCmds)
		Local $i, $n = UBound($aCmds) - 1
		For $i = 0 To $n
			$aCmds[$i] = $vCmds[$aCmds[$i]]
		Next
	ElseIf IsArray($vCmds) Then                         ; convert 2D array to 1D array
		If UBound($vCmds, 0) = 2 Then
			Local $m = UBound($vCmds, 2)
			Local $s, $t, $i, $n = UBound($vCmds, 1)
			ReDim $aCmds[$n]
			$n -= 1
			For $i = 0 To $n
				$s = $vCmds[$i][0]
				If $m > 1 Then
					$t = Int($vCmds[$i][1])
					If $t > 0 Then $s = $t & "!" & $s
				EndIf
				$aCmds[$i] = $s
			Next
		Else
			$aCmds = $vCmds                             ; already a 1D array, no conversion needed
		EndIf
	Else                                                ; convert string to array
		If IsBinary($vCmds) Then $vCmds = BinaryToString($vCmds)
		$aCmds = StringSplit($vCmds, @CR & @LF, 0)
		$aCmds[0] = ""    ; make the 1-indexed array a 0-indexed array with an empty command in the front
	EndIf

	Local $i, $sCmd, $n = UBound($aCmds) - 1, $iMode, $iTo
	For $i = 0 To $n                                                            ; send commands to the queue
		$sCmd = StringStripWS($aCmds[$i], 3)
		If $sCmd = "" Then ContinueLoop                                         ; skip blank lines

		$iTo = StringRegExp($sCmd, "^([0-9]*!)", 1)                             ; parse optional timeout
		If @error Then
			$iTo = 0
		Else
			$iTo = $iTo[0]
			$sCmd = StringTrimLeft($sCmd, StringLen($iTo))
			$iTo = Int(StringTrimRight($iTo, 1))
		EndIf

		$iMode = Number(StringLeft($sCmd, 1) = "#")                             ; parse optional download/picture flag
		If $iMode Then
			$iMode += Number(StringMid($sCmd, 2, 1) = "#")                      ; parse "##" picture flag
			$sCmd = StringTrimLeft($sCmd, $iMode)
			If $sFile = "" Then $iMode = 0                                      ; if file not specified then store file data on return queue
		EndIf
		If $iMode Then
			$sFile = __FileNameAutoIncrement($sFile)                            ; roll $sFile to next available name
			If $iTo = 0 Then $iTo = $iTimeoutMS * 10
			If $iMode = 2 Then
				__viDownloadPicture($oDev, $sFile, $sCmd, $iTo)
			Else
				__viDownloadFile($oDev, $sFile, $sCmd, $iTo)
			EndIf
		Else
			If StringLeft($sCmd, 1) = "$" Or StringRight($sCmd, 1) = "?" And $iTo <= 0 Then $iTo = $iTimeoutMS
			__viReq($oDev, $sCmd, ($iTo > 0), (($iTo = 0) ? $iTimeoutMS : $iTo))
		EndIf
	Next
EndFunc   ;==>__viScript



;			check if request/command is done and reset the reqdone flag
Func __viIsReqDone($oDev)
	If Not __viIsInstrument($oDev) Then Return True
	Local $b = $oDev.Item('reqdone')
	If $b Then $oDev.Item('reqdone') = False
	Return $b
EndFunc   ;==>__viIsReqDone



;			return exit code of most recently finished command
Func __viCmdRetStatus($oDev)
	If Not __viIsInstrument($oDev) Then Return SetError(1, 0, -1)
	Return $oDev.Item('creturn')
EndFunc   ;==>__viCmdRetStatus



;			returns true if no pending commands remain
Func __viIsIdle($oDev)
	If Not __viIsInstrument($oDev) Then Return True
	Return __QueueIsEmpty($oDev.Item('qreq'))
EndFunc   ;==>__viIsIdle



;			__viRet
; task:		return responses received from the visa device, pull the first response in the receive queue
; in:		$oDev = instrument handle
;			$bBin = true to return the data as a binary object instead of converting to string
; out:		if the result item in the queue is a response, then the response is returned, and @extended is set to the status
;			if the result item is a status from a command then it is returned
Func __viRet(ByRef $oDev, $bBin = False)
	Return __viRetQueuePop($oDev, $bBin)
EndFunc   ;==>__viRet



Func __viHasRet($oDev)
	If Not __viIsInstrument($oDev) Then Return False
	Return Not __QueueIsEmpty($oDev.Item('qret'))
EndFunc   ;==>__viHasRet






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; ---------------------
; API modbus commands
; nonblocking:
;	__mbRead
;	__mbWrite
; blocking:
;	__mbReadBl
;   __mbRet
;   __mbHasRet



;				__mbRead
; task:			read a register
; in:			$oDev = vi device handle
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
;				$iRegAddr = register address
;				$iTimeoutMS = timeout in ms
Func __mbRead(ByRef $oDev, $sDataType, $iRegAddr, $iTimeoutMS = 3000)
	Return __viReq($oDev, "modbusread " & $sDataType & " " & $iRegAddr, True, $iTimeoutMS)
EndFunc   ;==>__mbRead

Func __mbReadBl(ByRef $oDev, $sDataType, $iRegAddr, $iTimeoutMS = 3000)
	Return __viReqBl($oDev, "modbusread " & $sDataType & " " & $iRegAddr, True, $iTimeoutMS)
EndFunc   ;==>__mbReadBl

Func __mbRet(ByRef $oDev)
	Return __viRet($oDev)
EndFunc   ;==>__mbRet
Func __mbHasRet($oDev)
	Return __viHasRet($oDev)
EndFunc   ;==>__mbHasRet



;				__mbWrite
; task:			write a register
; in:			$oDev = vi device handle
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
;				$iRegAddr = register address
;				$nValue = value to write to register
; out:			0 if successful or @error
Func __mbWrite(ByRef $oDev, $sDataType, $iRegAddr, $nValue)
	Return __viCmd($oDev, "modbuswrite " & $sDataType & " " & $iRegAddr & " " & $nValue)
EndFunc   ;==>__mbWrite







;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------

; Blocking API interface functions
;
; __viGetID($oDev)								request device id
; __viReqBl($oDev, $sReq, $bWait)			send request and wait for response, return response
; __viCmdBl($oDev, $sCmd)					send command (__viReq $bWait=false)
; __viEnd($oDev)								wait for last command to finish then close the connection.  return last response if available
;




;			__viGetID
; task:		request ID from device, if it fails, then switch to other comm protocol and try again
; in:		$oDev = the IP address of the instrument in the form [raw:]IP[:port]
; out:		response string from VISA *IDN? request
Func __viGetID(ByRef $oDev, $iTimeoutMS = 1100, $retry = 1)
	__viFlushInputBuffer($oDev)                                                    ; when initially connecting we can flush the devices input traffic from any previous interactions
	Local $sRet = __viReqBl($oDev, $VI_IDN, True, $iTimeoutMS)
	If Not @error And $sRet <> "" Then Return $sRet
	If $retry = 0 Then Return SetError(@error, 0, $sRet)
	__viToggleMode($oDev)                             ; switch between VXI-11 and raw socket modes
	Return __viGetID($oDev, $iTimeoutMS, 0)           ; try again
EndFunc   ;==>__viGetID



;			__viReqBl
; task:		submit a visa request and wait for the response or command completion
; in:		$oDev
; out:		response from visa device or blank
Func __viReqBl(ByRef $oDev, $sReq, $bWait = True, $iTimeoutMS = 2000)
	Local $iStatus, $sRet
	__viFlush($oDev)
	__viReq($oDev, $sReq, $bWait, $iTimeoutMS)          ; put request in queue
	$sRet = __viWaitCmd($oDev)                          ; wait for command to complete
	If Not $bWait Then Return $sRet                     ; if do not need a reply then return transmit status
	$iStatus = ($sRet >= 0)
	$sRet = __viWaitReply($oDev, $iTimeoutMS)
	$iStatus = $iStatus And (@extended = 0)
	Return SetError(Number(Not $iStatus), 0, $sRet)
EndFunc   ;==>__viReqBl

Func __viCmdBl(ByRef $oDev, $sCmd)
	Return __viReqBl($oDev, $sCmd, False, 0)
EndFunc   ;==>__viCmdBl



;			wait for a command to complete and return its exit status
Func __viWaitCmd($oDev)
	If Not __viIsInstrument($oDev) Then Return SetError(1, 0, 0)
	Do
		__viLoop()
		Sleep(1)
	Until $oDev.Item('cdone')               ; wait for command to complete
	Return $oDev.Item('creturn')            ; return the status of the command
EndFunc   ;==>__viWaitCmd



;			wait for a reply and return the response
Func __viWaitReply($oDev, $iTimeoutMS = 2000)
	If Not __viIsInstrument($oDev) Then Return SetError(1, 0, "")
	If Not $oDev.Item('waitReply') Then Return __viRet($oDev)
	Local $iTimer = TimerInit()
	While Not __viHasRet($oDev) And TimerDiff($iTimer) < $iTimeoutMS            ; wait for response
		__viLoop()
		Sleep(1)
	WEnd
	Return __viRet($oDev)                                                       ; pull the return status of the command
EndFunc   ;==>__viWaitReply



;			wait for all commands/requests to finish and return a response (the response of the most recent executed request, not the last one executed in the queue)
Func __viFlush($oDev, $iTimeoutMS = 10000)
	If Not __viIsInstrument($oDev) Then Return SetError(1, 0, "")
	Local $iTimer = TimerInit()
	If Not __viIsIdle($oDev) Then
		While Not __viIsIdle($oDev) And TimerDiff($iTimer) < $iTimeoutMS        ; wait for command queue to empty
			__viLoop()
			Sleep(1)
		WEnd
	EndIf
	If $oDev.Item('waitReply') Then
		While Not __viHasRet($oDev) And TimerDiff($iTimer) < $iTimeoutMS        ; wait for response
			__viLoop()
			Sleep(1)
		WEnd
	EndIf
	Local $vR
	While __viHasRet($oDev)                                                     ; flush all responses out of the response queue
		$vR = __viRet($oDev)
	WEnd
	Return $vR                                                                  ; return last response in the queue
EndFunc   ;==>__viFlush



;			__viEnd
; task:		wait for any pending requests to complete and close the session
; in:		$oDev
; out:		if any response string exist then it is returned
Func __viEnd($oDev)
	If Not __viIsInstrument($oDev) Then Return ""
	__viWaitCmd($oDev)
	Local $sRet = __viWaitReply($oDev)
	__viClose($oDev)
	__viMbClose($oDev)
	Return $sRet
EndFunc   ;==>__viEnd






;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------


; scripting functions





;			__viScriptFile
; task:		read a script from a file and execute it
; in:		$oDev = vi session handle or ip address
;			$sFile = script file name
;
; script commands:
;	[write|cmd] visaStatement			send visaStatement to visa device - use this for visa/scpi commands/requests
;   $var=visaStatement					read response from visa device and store in given variable name
;   cd|chdir path						change local directory to 'path'
;   sleep timeMS						sleep for 'timeMS' milliseconds
;   download::filename::visaStatement	read response from request 'visaStatement' and store it in file 'filename'
;										use this to download files, including screenshots
;   upload::filename::visaStatement		sends a visa/scpi command with visaStatement prefix and file data from 'filename' with IEEE488.2 length header
;										use this to upload files
;   logfile filename					set the log file name and path to 'filename'
;  	log	string							append 'string' to the logfile - use this for saving measurements
;   set $var expr                   	set variable 'var' to the value of expression 'expr'
;
; string substitution:  substrings enclosed with curley brackets { } are evaluated as expressions and the result is substituted
;   this uses autoit execute() function, so variable names begin with $, math expressions are evaluated, and possibly autoit commands
;   example:
;     $period=MEASUrement:MEAS2:RESUlts:ALLacq:MEAN?							read the measured clock period
;     :SEARCH:SEARCH1:TRIGGER:A:PULSEWIDTH:LOWLIMIT {2.5*$period}				set search1 to look for clock pulses wider than 2.5 * period
;

Func __viScriptFile(ByRef $oDev, $sFile)
	$sFile = _PathFull($sFile)
	If Not FileExists($sFile) Then Return SetError(1, 0, -1)                            ; script file not found
	Local $hFile = FileOpen($sFile, $FO_READ)
	If $hFile < 0 Then Return SetError(2, 0, -1)                                        ; could not open script file
	Local $sLine

	While 1
		$sLine = StringStripWS(FileReadLine($hFile), 3)
		If @error Then ExitLoop
		If StringLeft($sLine, 1) = "#" Then ContinueLoop                                ; skip comment lines
		If $sLine = "" Then ContinueLoop                                                ; skip blank lines
		$sLine = StringStripWS($sLine, 3)
		__viCmd($oDev, $sLine)
	WEnd
	FileClose($hFile)
EndFunc   ;==>__viScriptFile







;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------



