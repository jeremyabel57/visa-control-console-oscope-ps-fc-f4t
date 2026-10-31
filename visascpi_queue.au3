#include-once

; debug
Global $g_mbPrint = 0
Global $g_mbPrintDecode = 0
Global $g_mbPrintDecodeString = 0
Global $g_F4T_PrintResolv = 0

Global $g_viPrintCmds = 1
Global $g_viPrintReplies = 1

Global $g_viPrintCondCmds = 0
Global $g_viPrintQueuePop = 0
Global $g_viPrintQueuePush = 0
Global $g_viPrintpQue = 0
Global $g_viPrintpQueCond = 0
Global $g_viPrintLoopRead = 0

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
	__viUploadFile($oDev, $sFile, $sReq, $iTimeoutMS=5000)
		$sFile = file path/name of file to send
		$sReq = visa command to send as the prefix to the file data
	__viDownloadFile($oDev, $sFile, $sReq, $iTimeoutMS=5000)
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
		$sDataType = "Nt", n=number of 16-bit words, t=type (i=integer, f=float, s=string)
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
		close								close the connection.  it will not reopen until the next visa or modbus command is attempted

		sel[ect] [sc|dc|tc|fc]				select active visa device.  all following visa commands will be sent to that device.  This device must be registered
											in the $g_oViSelect dictionary under the identifier sc|dc|tc|fc for it to work, otherwise the commands are skipped


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
Global Const $VI_REQ_ERR = ":SYSTem:ERRor?"
Global Const $VI_IDN = "*IDN?"
Global Const $VI_CLS = "*CLS"
Global Const $VI_RST = "*RST"
Global Const $VI_GTL = "&GTL"



#include "mydebug.au3"
#include "datatypes.au3"


; -----------------------------------------------------------------------------------------------------------------
; -----------------------------------------------------------------------------------------------------------------
; -----------------------------------------------------------------------------------------------------------------
; -----------------------------------------------------------------------------------------------------------------


#include <StructureConstants.au3>
#include <File.au3>
#include "deque.au3"
#include "filemisc.au3"
#include "winfuncs.au3"



Global $g_oViDevs = ObjCreate("Scripting.Dictionary")                                       ; Global visa instrument/device list
;Global $g_oViDevs                                                                           ; Global visa instrument/device list
Global $g_oViSelect = ObjCreate("Scripting.Dictionary")                                     ; list of devices selected for use with the main script queue
Global $g_oNotices = ObjCreate("Scripting.Dictionary")                                      ; list of return notices for commands that have completed
Global $g_oDevMain                                                                          ; pointer direct to main script queue
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


Global $g_dbg_hOutput, $g_dbg_hStack, $g_dbg_hQueue                                         ; debug tab handles for monitor windows







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

EndFunc   ;==>scTab_debug
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
; __viMakeInstrumentIndex($aIP)                                             ; given parsed IP address, make an instrument index string for $g_oViDevs
; __viIsInstrument($viHandle)                                               ; confirm $viHandle is a visa instrument handle or not
; __IsDictionary($vVar)                                          			; confirm $vVar is a scripting dictionary or not
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
	If __viIsInstrument($oDev) Then Return True                                 ; if already an instrument handle then nothing to do, return ok
	If Not IsString($oDev) Then Return False
	If $oDev = "" Or $oDev = "raw:" Then Return False                           ; if blank input then return fail
	Local $sIdx = __viMakeInstrumentIndex(__viParseIPaddress($oDev, ""))        ; assume it is an ip address and parse it
	If $sIdx = "" Then Return False
	;	If Not __IsDictionary($g_oViDevs) Then $g_oViDevs = ObjCreate("Scripting.Dictionary")
	If Not $g_oViDevs.Exists($sIdx) Then _                                      ; if not found in the file then create a new entry for it
			$g_oViDevs.Item($sIdx) = __viMakeInstrument($oDev)
	$oDev = $g_oViDevs.Item($sIdx)                                              ; point $oDev to the device data structure
	If $sIdx = "main" Then $g_oDevMain = $oDev                                  ; if this is the main script queue then point the main pointer to it
	Return True                                                                 ; return ok
EndFunc   ;==>__viResolveInstrument
Func __viResolve(ByRef $oDev)
	Return __viResolveInstrument($oDev)
EndFunc   ;==>__viResolve


Func __viMakeInstrumentIndex($aIP)                                              ; given parsed IP address, make an instrument index string for $g_oViDevs
	Local $sPort = $aIP[1]
	If $sPort = 5025 Or $sPort = "inst0" Then $sPort = ""                       ; if port number is default then make it blank
	If $sPort <> "" Then $sPort = ":" & $sPort
	Return $aIP[0] & $sPort                                                     ; search string to use to find existing instrument in global file $g_oViDevs
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




; Instrument Map
;

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
	$oDev.Item('viIdn') = ''                                                            ; IDN string received from device
	$oDev.Item('viType') = ''                                                           ; classification initials for what type of device (tc, fc, dc, sc)

	; comm handles and state
	$oDev.Item('viSession') = 0                                                         ; visa handle when using visa dll communications
	$oDev.Item('viSocket') = 0                                                          ; socket handle for raw TCP socket protocol
	$oDev.Item('state') = 0                                                             ; true if session is open, false if closed

	; modbus variables
	$oDev.Item('mbIpPort') = 502                                                        ; ModBus TCP IP port number
	$oDev.Item('mbSocket') = 0                                                          ; ModBus TCP receive buffer
	$oDev.Item('mbTransID') = 0x100                                                     ; ModBus transaction ID

	; F4T Thermal/Environmental Chamber variables
	$oDev.Item('f4tWordOrder') = -1                                                     ; F4T modbus word order 0=low-high, 1=high-low
	$oDev.Item('f4tDataMap') = -1                                                       ; F4T thermal chamber data map 1=current, 2=legacy, -1=yet determined
	$oDev.Item('f4tUnits') = -1                                                         ; F4T thermal chamber units 1=C, 0=F

	; request/command
	$oDev.Item('cmd') = ''                                                              ; command currently being processed
	$oDev.Item('timer') = 0                                                             ; timeout timer for background process TimerInit, TimerDiff
	$oDev.Item('timeout') = 1000                                                        ; timeout limit in milliseconds
	$oDev.Item('reqdone') = False                                                       ; request done flag for API usage.  set true when request, and if needed response, completes
	$oDev.Item('cStack') = __StackNew()                                                 ; this stack is used for processing flow control statements (if then/else/end, while/end, do/until)
	$oDev.Item('rNotice') = ''                                                          ; non empty string to drop notice in rNotices when command and response are complete
	$oDev.Item('wNotice') = ''                                                          ; any notice tag we are waiting for in this queue

	; async send
	$oDev.Item('upload') = 0                                                            ; handle of file currently being uploaded
	$oDev.Item('cdone') = True                                                          ; cmd done flag is set to true when a command complets
	$oDev.Item('creturn') = 1                                                           ; return code of last command executed.  1=ok, 0=error

	; async receive
	$oDev.Item('rMode') = 0                                                             ; 0=expecting visa data, 1=expecting modbus data
	$oDev.Item('rExpLen') = 0                                                           ; number of bytes expected
	$oDev.Item('rParse') = -1                                                           ; IEEE488.2 header parsed, if it exists
	;$oDev.Item('rHeaderLen') = 0                                                       ; length of the header
	$oDev.Item('rBuf') = Binary("")                                                     ; read buffer
	$oDev.Item('rCount') = 0                                                            ; number of bytes read
	$oDev.Item('download') = 0                                                          ; handle of file currently being downloaded
	$oDev.Item('rdone') = True                                                          ; response done flag is set to true when a response is received
	$oDev.Item('waitReply') = False                                                     ; flag to wait for reply before sending next command
	$oDev.Item('rVar') = ""                                                             ; variable name to store result into, or blank to push it onto the return queue
	$oDev.Item('rExec') = ""                                                            ; expression to execute with returned value, local variable $rv will be the returned value

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
	__ConsolePrintVar($oDev)        ; yes this is correct, leave this uncommented
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
; __viIsConnected											check if session is connected/open
; __viOpen													open or reopen a session
; __viClose($oDev)											close visa session
;   __viCloseHandle($hVisa)									close visa handle (close session, resource manager, ...)
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
	If __viIsConnected($oDev) Then Return True
	Return __viOpen($oDev)
EndFunc   ;==>__viConnect



; 			__viIsConnected
; task:		determine if visa session is connected to device
; out:		true if either visa session handle is active, or if tcp socket handle is active
Func __viIsConnected($oDev)
	If $oDev.Item('index') = 'main' Then Return True                        ; the unified main script queue does not 'connect' to any individual instrument
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
EndFunc   ;==>__viIsConnected



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
	If $__vi_hDll <> '' And $__vi_hDll <> 0 Then DllClose($__vi_hDll)
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



; ====================================================================================================
; Function Name:    __viCheckRMhandle
; Description:      Maintains a persistent, single-instance global master Resource Manager session block.
; ====================================================================================================
;			confirm visa RM is open
; out:		1 if ok, 0 if not open and unable to open
Func __viCheckRMhandle()
	__viCheckDLLhandle()
	If __viIsResourceManagerValid($__vi_hRM) Then Return 1                                      ; if valid then no further action needed
	If $__vi_hRM <> 0 And $__vi_hRM <> "" Then                                                  ; If it's an orphaned token, clean up via the proper driver DLL allocation context
		__viCloseHandle($__vi_hRM)    ; DllCall($__vi_hDll, "long", "viClose", $__viSysUint32_64, $__vi_hRM)
		$__vi_hRM = 0
	EndIf
	Local $aResult = DllCall($__vi_hDll, "long", "viOpenDefaultRM", $__viSysUint32_64ptr, 0)    ; open the visa resource manager
	If @error Then
		ConsoleWrite("ERROR: 'visa32.dll' not found. Ensure NI-VISA runtime is installed." & @CRLF)
		Return SetError(@error, 0, 0)
	EndIf
	Local $iStatus = $aResult[0]
	If $iStatus < 0 Then
		ConsoleWrite("ERROR: Could not open Default Resource Manager. Status: 0x" & Hex($iStatus) & @CRLF)
		Return SetError($iStatus, 0, 0)    ;	0xBFFF003C = VI_ERROR_ALLOC - no more system resources available (malloc or something else)
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
	Local $tAttrState = DllStructCreate($__viSysUint32_64)
	; Query the RM Session attribute back against the target handle descriptor
	Local $aResult = DllCall($__vi_hDll, "long", "viGetAttribute", _
			$__viSysUint32_64, $hRM, _
			"ulong", $VI_ATTR_RM_SESSION, _
			"struct*", $tAttrState)
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






; -------------------------------------------------------
; toggle between raw socket and vxi-11 communication mode


;			__viToggleMode
; task:		toggle between raw and vxi-11 mode
; in:		$viHandle = session handle
;			if $oDev is an ip address it will be changed to a session handle
Func __viToggleMode($oDev)
	If Not __viIsInstrument($oDev) Then Return ''               ; if not an instrument handle then do nothing
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
	Return ''                                                   ; return a blank string for viScripts when evaluated inside "{__viToggleMode($oDev)}"
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
;
; __viMbConnect(ByRef $oDev)
; __viMbIsSessionOpen(ByRef $oDev)
;
; __viMbOpen(ByRef $oDev)											open modbus connection
; __viMbClose($oDev)												close modbus connection
;
; __viMbMakeTCPframe($oDev, $bFunc, $iRegisterAddress, $sData)		make the TCP modbus frame
; __viMbReadBuf($oDev, $iMaxLen = 1460)								read from the modbus device
; __viMbDecode($oDev, $bBufAcc, $sFormat)				    	extract the 32/16 i/f number from the read buffer
; __viMbW16toFloat16($w16)											extract 16 bit floating point number from 16 bit binary data
; __viMbFloat16toW16($nValue)										encode 16 bit float into 16 bit binary
; __viMbW32toFloat32($w32)											extract 32 bit floating point number from 32 bit binary
; __viMbFloat32toW32($nValue)										encode 32 bit float into 32 bit binary data
;






;				__viMbRead
; task:			read a register
; in:			$oDev = session handle
;				$iRegAddr = register address
;				$sDataType = "Nt", n=number of 16-bit words, t=type (i=integer, f=float, s=string)
; out:			1 if successful or 0 and @error
; note:			this only sends the read request, it does not wait for, nor read the response
Func __viMbRead($oDev, $sFormat, $iRegAddr)
	If Not __IsDictionary($oDev) Then Return False
	If Not __viMbConnect($oDev) Then Return False
	$iRegAddr = Int($iRegAddr)
	Local $sType = StringRight($sFormat, 1)
	Local $iN = Int(StringTrimRight($sFormat, 1))
	Local $sPayload = __viMbMakeTCPframe($oDev, 0, $iRegAddr, $iN)   ; build request frame
	Local $hSocket = $oDev.Item('mbSocket')
	If Not __TCP_IsConnected($hSocket) Then
		If Not __viMbOpen($oDev) Then Return SetError(-1, 0, False)
		$hSocket = $oDev.Item('mbSocket')
	EndIf
	If $g_mbPrint Then __ConsolePrintVars("__viMbRead (reg), ", "sFormat", $sFormat, "iRegAddr", $iRegAddr, "sPayload", $sPayload)
	Return (TCPSend($hSocket, Binary($sPayload)) > 0)                           ; send request
EndFunc   ;==>__viMbRead



;				__viMbWrite
; task:			write a register
; in:			$oDev = session handle
;				$sDataType = "Nt", n=number of 16-bit words, t=type (i=integer, f=float, s=string)
;				$iRegAddr = register address
;				$vValue = value or string to write to register
; out:			true if successful or false and @error
Func __viMbWrite($oDev, $sFormat, $iRegAddr, $vValue)
	If Not __IsDictionary($oDev) Then Return False
	If Not __viMbConnect($oDev) Then Return False
	$iRegAddr = Int($iRegAddr)
	Local $sHex = __viMbEncode($oDev, $vValue, $sFormat)          ; encode number into binary hex string
	Local $sPayload = __viMbMakeTCPframe($oDev, 1, $iRegAddr, $sHex)    ; build request frame to send

	Local $hSocket = $oDev.Item('mbSocket')
	If Not __TCP_IsConnected($hSocket) Then
		If Not __viMbOpen($oDev) Then Return SetError(-1, 0, False)
		$hSocket = $oDev.Item('mbSocket')
	EndIf
	If $g_mbPrint Then __ConsolePrintVars("__viMbWrite (reg), ", "sFormat", $sFormat, "iRegAddr", $iRegAddr, "nValue", $vValue, "sPayload", $sPayload, "sHex", $sHex)

	Return (TCPSend($hSocket, Binary($sPayload)) > 0)                               ; send request
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
;			$sData = (read) number of (16-bit) registers to read
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
	Local $iDataLen = Int(StringLen($sData) / 2)                            ; number of 16-bit words in payload
	$bFunc = Number($bFunc)                                                 ; function: read(0) / write(1)
	Local $iFunction = $bFunc ? 0x10 : 0x03                                 ; use 0x10 = for multiple and single reg write.
	;Local $iFunction = $bFunc ? (($iDataLen > 2) ? 0x10 : 0x06) : 0x03      ; do not use 0x06 for F4T.   0x10 = write multiple regs.  0x06=write single reg.  0x03=read reg(s)

	Local $len = 0x0006                                                     ; read packet has len 6 for this field
	If $bFunc Then $len = 0x07 + $iDataLen                                  ; write packet has additional bytes for payload

	Local $sPayload = "0x" & Hex($iHiTrans, 2) & Hex($iLoTrans, 2) & _      ; build the frame
			$protocol & Hex($len, 4) & $unitID & Hex($iFunction, 2) & _
			Hex($iHiRegister, 2) & Hex($iLoRegister, 2)

	If $bFunc Then
		$sPayload &= Hex(Int($iDataLen / 2), 4) & Hex($iDataLen, 2) & $sData ; append data length and payload data
	Else
		$sPayload &= Hex(Number($sData), 4)                                 ; number of 16 bit registers to read
	EndIf
	Return $sPayload
EndFunc   ;==>__viMbMakeTCPframe





; ----------------------------------
; mb Open close, connect fucntions




;			__viMbConnect
; task:		ensure a connection is started
; in:		$oDev = visa instrument data structure
; out:		return 1 if successful, 0 if failed
Func __viMbConnect($oDev)
	If __viMbIsSessionOpen($oDev) Then Return True
	Return __viOpen($oDev)
EndFunc   ;==>__viMbConnect



; 			__viMbIsSessionOpen
; task:		determine if visa session is connected to device
; out:		true if either visa session handle is active, or if tcp socket handle is active
Func __viMbIsSessionOpen($oDev)
	Local $hSocket = $oDev.Item('mbSocket')
	If $hSocket = 0 Then Return False
	If __TCP_IsConnected($hSocket) Then Return True
	__viClose($oDev)                                                        ; if not active then make sure it is closed
	Return False
EndFunc   ;==>__viMbIsSessionOpen



;			__viMbOpen
; task:		open tcpsocket for modbus.  if already open, then close and reopen
; out:		True if successful, False if error
Func __viMbOpen(ByRef $oDev)
	If Not __viResolveInstrument($oDev) Then Return False
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
		Return SetError($iErr, 0, False)
	EndIf
	$oDev.Item('mbSocket') = $hSocket
	Return True
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




; -------------------------------------------------
; modbus data recieved handlers




;			__viMbReadBuf
; task:		nonblocking read - return any/all data currently received from modbus port device
; in:		$oDev = session handle
;			$iMaxLen = max number of bytes to read (default to one ethernet frame max size)
; out:		any data read as a binary data object
;
; note:		following behavior of __viReadBuf we do not reopen the connection if it is closed, we just return error code
Func __viMbReadBuf($oDev, $iMaxLen = 1460)
	Local $bR = Binary("")
	If Not __IsDictionary($oDev) Then Return SetError(-1, 0, $bR)
	Local $iErr, $iStatus
	Local $hSocket = $oDev.Item('mbSocket')
	If Not __IsTCPsocket($hSocket) Then Return SetError(-1, 0, $bR)
	If Not __TCP_IsDataAvailable($hSocket) Then Return $bR
	$bR = TCPRecv($hSocket, 64, 1)
	$iErr = @error
	If $iErr = 10093 Then
		TCPStartup()
		Sleep(50)
		If Not __viMbOpen($oDev) Then Return SetError(-1, 0, $bR)
		If Not __TCP_IsDataAvailable($hSocket) Then Return $bR
		$bR = TCPRecv($hSocket, 64, 1)
		$iErr = @error
	EndIf

	If $g_mbPrint Then __ConsolePrintVars("__viMbReadBuf, ", "bR", $bR, "iErr", $iErr)
	Return SetError($iErr, 0, $bR)
EndFunc   ;==>__viMbReadBuf




;			__viMbDecode
; task:		extract number from a register read reply modbus frame
; in:		$oDev = session handle
;			$bBufAcc = just the payload data from the modbus frame
;			$sFormat = 32i, 32f, 16i, 16f for 32 or 16 bit number, integer or floating point.  or Ns where N=number of bytes and s is string
; out:		number extracted from the payload data
Func __viMbDecode($oDev, $bBufAcc, $sFormat)                                            ; decode a number of string from modbus packet payload
	If ($g_mbPrint Or $g_mbPrintDecode Or $g_mbPrintDecodeString) And StringRight($sFormat, 1) = "s" Then __ConsolePrintVars("__viMbDecode, " & @CRLF, "cmd", $oDev.Item('cmd'), "bBufAcc", $bBufAcc, "sBufAcc", BinaryToString($bBufAcc, 4))
	If StringRight($sFormat, 1) = "s" Then Return BinaryToString($bBufAcc, $SB_UTF16BE)
	Local $iN = Int(StringTrimRight($sFormat, 1))
	Local $iB1 = Int(BinaryMid($bBufAcc, 1, 1))
	Local $iB2 = Int(BinaryMid($bBufAcc, 2, 1))
	Local $nV = ($iB1 * 256) + $iB2
	Local $iW1 = $nV, $iW2
	If $iN = "1" Then
		If StringRight($sFormat, 1) = "f" Then $nV = __viMbW16toFloat16($nV)            ; if float interpretation then convert to float
	Else
		$iB1 = Int(BinaryMid($bBufAcc, 3, 1))
		$iB2 = Int(BinaryMid($bBufAcc, 4, 1))
		$iW2 = ($iB1 * 256) + $iB2
		If $oDev.Item('f4tWordOrder') Then
			$nV = ($nV * 65536) + $iW2                                                  ; word order: high low
		Else
			$nV = ($iW2 * 65536) + $nV                                                  ; word order: low high (default)
		EndIf
		If StringRight($sFormat, 1) = "f" Then $nV = __viMbW32toFloat32($nV)            ; if float interpretation then convert to float
	EndIf
	If $g_mbPrint Or $g_mbPrintDecode Then __ConsolePrintVars("__viMbDecode, ", "bBufAcc", $bBufAcc, "sFormat", $sFormat, "iW1", Hex($iW1, 4), "iW2", Hex($iW2, 4), "nV", $nV)
	Return Number($nV)
EndFunc   ;==>__viMbDecode


Func __viMbEncode($oDev, $vValue, $sFormat)                                             ; encode a 32 or 16 bit int or float into a binary register value, returns hex digits
	If IsString($vValue) And StringRight($sFormat, 1) = "s" Then
		Local $s = StringTrimLeft(String(StringToBinary($vValue, 4)), 2)                ; convert string to hexidecmal encoding
		If Mod(StringLen($s), 4) Then $s &= "00"                                        ; ensure string is a multiple of 16-bit words
		Return $s
	EndIf
	Local $iN = Int(StringTrimRight($sFormat, 1))
	Local $sType = StringRight($sFormat, 1)
	If $g_mbPrint Or $g_mbPrintDecode Then __ConsolePrintVars("__viMbEncode, ", "nValue", $vValue, "sFormat", $sFormat)
	If $sType = "f" Then                                                                ; if needed then encode float into int
		If $iN = 16 Then
			$vValue = __viMbFloat16toW16($vValue)
		Else
			$vValue = __viMbFloat32toW32($vValue)
		EndIf
	EndIf
	Local $sHex = Hex($vValue, 8)
	Local $sW1 = StringLeft($sHex, 4)
	Local $sW2 = StringRight($sHex, 4)
	If $iN = "1" Then
		$sHex = $sW2                                                                    ; if only 16 bit then grab low word
	Else
		If Not $oDev.Item('f4tWordOrder') Then $sHex = $sW2 & $sW1                       ; if word order is low-high then swap words
	EndIf
	If $g_mbPrint Or $g_mbPrintDecode Then __ConsolePrintVars("__viMbEncode, ", "sW1", $sW1, "sW2", $sW2, "sHex", $sHex)
	Return $sHex
EndFunc   ;==>__viMbEncode




; -----------------------------------------------
; float/int conversions




;				W16toFloat16
; task:			convert 16 bit binary data into a 16 bit floating point number
Func __viMbW16toFloat16($w16)
	$w16 = Int($w16)
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
	$nValue = Number($nValue)
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
	$w32 = Int($w32)
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
	$nValue = Number($nValue)
	Local $iSign = ($nValue < 0) ? 1 : 0
	Local $nAbsVal = Abs($nValue)
	Local $iExponent = 0
	If $nAbsVal = 0 Then Return 0
	$iExponent = Floor(Log($nAbsVal) / Log(2))
	Local $nMantissa = ($nAbsVal / (2 ^ $iExponent)) - 1
	Local $iMantissaInt = Round($nMantissa * 0x800000)
	Local $r = Int(($iSign * 0x80000000) + (BitAND($iExponent + 127, 0xFF) * 0x800000) + BitAND($iMantissaInt, 0x007FFFFF))
	;__ConsolePrintVars("__viMbFloat32toW32, ", "nValue", $nValue, "r", Hex($r))
	Return $r
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
;     __viEvalExprStrs($sText,$oDev)								            convert "{expr}" into evaluated expr using autoit Execute(expr)
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
; main loop functions - service background processes



; -------------------------------------------------------------
; main loop function - service background processes
Func __viLoop()
	If Not __IsDictionary($g_oViDevs) Then Return
	Local $oDev, $sKey
	For $sKey In $g_oViDevs
		$oDev = $g_oViDevs.Item($sKey)
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
	Local $tBuf = $oDev.Item('wNotice')
	If $tBuf <> "" Then                                                                 ; if we are waiting on a notice then
		If Not $g_oNotices.Exists($tBuf) Then Return                                    ;   if notice not arrived yet then return - wait for it to come
		$tBuf = $g_oNotices.Item($tBuf)
		If IsKeyword($tBuf) = 0 Then __viRetQueuePush($oDev, $tBuf, 0)                  ;   if response received then push it onto return queue
		$oDev.Item('rdone') = True                                                      ;   signal main/client code that we have a newly received message
		__viLoopExecReqComplete($oDev)                                                  ;   signal request/command is complete
		$oDev.Item('waitReply') = False                                                 ;   signal cmd that it has received reply and can move to next command
		$oDev.Item('wNotice') = ''                                                      ;   reset wNotice flag so we do not spinlock forever
		Return                                                                          ;   return.  we are done processing here
	EndIf                                                                               ; end if.  proceed below for non-'wNotice' related processing


	Local $bModbus = $oDev.Item('rMode')                                                ; what type of reply are we expecting (modbus or visa)
	Local $aRet, $iStatus, $iRetCount

	If $bModbus Then                                                                    ; if in a modbus command then read modbus tcp port
		$tBuf = __viMbReadBuf($oDev)                                                    ;   read a chunk of data from modbus port
		$iStatus = 1                                                                    ;   1 If Not done, 0 If done
	Else                                                                                ; else we are in a visa command, read visa port
		$aRet = __viReadBuf($oDev, 0x10000)                                             ;   read a chunk of data from visa port
		$iStatus = $aRet[0]
		$tBuf = $aRet[1]
		;__ConsolePrintVars("__viLoopRead, ", "iStatus", $iStatus, "tBuf", String($tBuf))
	EndIf
	$iRetCount = BinaryLen($tBuf)

	If $iRetCount <= 0 Then                                                             ; if nothing received then check timeout and return
		If Not $oDev.Item('waitReply') Then Return                                      ; if not waiting for a reply then return
		If TimerDiff($oDev.Item('timer')) < $oDev.Item('timeout') Then Return           ; if no timeout yet then return
		$iStatus = -1073807339                                                          ; set status flag for timeout
	EndIf

	Local $hFile = $oDev.Item('download')
	Local $bBufAcc = $oDev.Item('rBuf')
	Local $bLeftOvers = Binary("")

	If $iRetCount > 0 Then                                                              ; if received data then process it
		Local $iExpLen = $oDev.Item('rExpLen')
		Local $iReadCount = $oDev.Item('rCount')

		$bBufAcc = Binary($bBufAcc & $tBuf)                                             ; add new bytes to buffer
		$oDev.Item('rBuf') = $bBufAcc
		$iReadCount += $iRetCount                                                       ; update read count
		$oDev.Item('rCount') = $iReadCount
		$oDev.Item('timer') = TimerInit()                                               ; reset timeout timer
		If $bModbus Then                                                                ; receiving MODBUS TCP frame
			If $iExpLen <= 0 Then                                                       ; check to see if we received the entire modbus frame
				If $iReadCount >= 6 Then                                                ; read frame length field
					$iExpLen = 6 + Int(BinaryMid($bBufAcc, 5, 1)) * 0x100 + Int(BinaryMid($bBufAcc, 6, 1))          ; total number of expected bytes
					$oDev.Item('rExpLen') = $iExpLen
				EndIf
			EndIf
			If $iExpLen > 0 Then
				If $iReadCount >= $iExpLen Then $iStatus = 0                            ; if full frame received then set iStatus to 0 (ok), else leave it at 1 (needs more)
			EndIf
			If $g_mbPrint Then __ConsolePrintVars("__viLoopRead modbus, ", "iReadCount", $iReadCount, "iExpLen", $iExpLen, "iStatus", $iStatus)

		Else                                                                            ; Receiving VISA SCPI data
			Local $iParse = $oDev.Item('rParse')
			;Local $iHeaderLen = Int($oDev.Item('rHeaderLen'))

			If $iParse < 0 And $iReadCount >= 1 Then                                    ; dynamic parsing for IEEE 488.2 header
				If Int(BinaryMid($bBufAcc, 1, 1)) <> 0x23 Then                          ; if not IEEE488.2 header marker then 0x23 = "#"
					$iParse = 11                                                        ;   iParse = 11 - no header found
					$oDev.Item('rParse') = 11
				Else                                                                    ; else IEEE488.2 header marker "#" found
					If $iReadCount >= 2 Then                                            ;   if at least 2 bytes received then
						$iParse = Int(BinaryMid($bBufAcc, 2, 1)) - 0x30                 ;     convert byte 2 from ascii digit to integer number
						If $iParse < 0 Or 9 < $iParse Then                              ;     if not a valid digit then
							$iParse = 11                                                ;       iParse = 11 - no header found
							$oDev.Item('rParse') = 11                                   ;
						EndIf                                                           ;     end if
						;__ConsolePrintVars("__viLoopRead, ", "iParse", $iParse)
					EndIf                                                               ;   end if
				EndIf                                                                   ; end if
			EndIf

			If 0 <= $iParse And $iParse <= 9 Then                                       ; if still processing IEEE488.2 header and we have the header length then
				If $iReadCount >= $iParse + 2 Then                                      ;   if IEEE 488.2 header found and fully received then decode and remove it from the buffer
					If $iParse = 0 Then                                                 ;     if header is "#0" then
						$iParse = 10                                                    ;       signal that header is found and parsed
						$oDev.Item('rParse') = 10
						$iExpLen = 0                                                    ;       iExpLen = 0 to signal that we parsed the header but we do not have an expected byte count
						$bBufAcc = BinaryMid($bBufAcc, 3)                               ;       strip "#0" header from the buffer
					Else                                                                ;     else we have a number of digits to extract for the expected payload length
						Local $iPayloadLen = BinaryToString(BinaryMid($bBufAcc, 3, $iParse), 1)
						If StringIsDigit($iPayloadLen) Then                             ;       if PayloadLen is a valid set of digits then
							$iExpLen = 1 + 1 + $iParse + Int($iPayloadLen)              ;         calculate the expected length of data to receive
							$oDev.Item('rExpLen') = $iExpLen                            ;         Total block footprint = '#' symbol (1) + digit counter (1) + size digits + raw payload
							$bBufAcc = BinaryMid($bBufAcc, $iParse + 3)                 ;         strip IEEE 488.2 header from the buffer
							$iParse = 10                                                ;         set iParse=10 to signal a good header found and iExpLen is the expected bytecount for iReadCount
							$oDev.Item('rParse') = 10
						Else                                                            ;       else header invalid
							$iParse = 11                                                ;         set iParse=11 to signal no header found
							$oDev.Item('rParse') = 11
						EndIf                                                           ;       end if
					EndIf                                                               ;     end if
				EndIf                                                                   ;   end if
			EndIf                                                                       ; end if

			; raw mode check for end of message
			If $oDev.Item('viIpMode') Then                                              ; if in raw socket mode then
				If $iParse = 11 Then                                                    ;   if buffer processed for IEEE488.2 header but header not valid or not found then
					Local $sBuf = BinaryToString($bBufAcc)                              ;     look for LF end of visa message marker
					Local $iLFpos = StringInStr($sBuf, @LF)                             ;
					If $iLFpos Then                                                     ;     if LF found then
						Local $iLFposBefore = $iLFpos - 1
						If StringMid($sBuf, $iLFposBefore, 1) = @CR Then $iLFposBefore -= 1
						$iLFpos += 1
						If $iReadCount > $iLFpos Then _                                 ;       save the left over data accumulated
								$bLeftOvers = BinaryMid($bBufAcc, $iLFpos)
						$bBufAcc = BinaryMid($bBufAcc, 1, $iLFposBefore)                ;       drop the CR and LF and any data accidentally read after it
						$iStatus = 0                                                    ;       successful completion of receiving visa data
					EndIf                                                               ;     end if
				EndIf                                                                   ;   end if
			EndIf                                                                       ; end if

			If $g_viPrintLoopRead Then
				ConsoleWrite(@CRLF)
				__ConsolePrintVars("__viLoopRead, ", "bBufAcc", $bBufAcc, "iReadCount", $iReadCount, "iParsed", $iParse, _
						"iExpLen", $iExpLen, "oDev", $oDev)
			EndIf

			If $hFile <> 0 And $iParse Then                                  ; write data to file instead of storing in buffer
				If $hFile > 0 Then
					FileWrite($hFile, $bBufAcc)
					If @error Then $iStatus = -1
				EndIf
				$oDev.Item('rBuf') = Binary("")
				$bBufAcc = Binary("")
			EndIf

			If $iReadCount >= 0x100000000 Then $iStatus = -3                ; buffer overflow, using an artificial buffer limit here

			; check if we received enough data to reach IEEE488.2 header expected bytes
			If $iParse = 10 And $iExpLen > 0 And $iReadCount >= $iExpLen Then ; if we have a parsed header, and the expected payload length is > 0 and we have received enough data then
				If $iReadCount > $iExpLen Then                              ;   save the left over data accumulated
					$bLeftOvers = BinaryMid($bBufAcc, $iExpLen + 1)
					If Int(BinaryMid($bLeftOvers, 1, 1)) = 0x0D Then $bLeftOvers = BinaryMid($bLeftOvers, 2)    ; strip terminating CR from buffer
					If Int(BinaryMid($bLeftOvers, 1, 1)) = 0x0A Then $bLeftOvers = BinaryMid($bLeftOvers, 2)    ; strip terminating LF from buffer
					$bBufAcc = BinaryMid($bBufAcc, 1, $iExpLen)
				EndIf
				$iStatus = 0                                                ;   stop as we received all expected bytes
			EndIf                                                           ; end if
		EndIf
	EndIf

	If $iStatus <= 0 Then                                                   ; done reading response - 0=success, negative=error
		If $bModbus Then
			If $iStatus = 0 Then                                            ; if successfully received frame
				If $iReadCount > $iExpLen Then $bLeftOvers = BinaryMid($bBufAcc, $iExpLen + 1, $iReadCount - $iExpLen)
				Local $iCount = Int(BinaryMid($bBufAcc, 9, 1))
				If $iCount > $iExpLen - 9 Then $iCount = $iExpLen - 9
				$bBufAcc = BinaryMid($bBufAcc, 10, $iCount)                 ; strip the frame header, leaving only the payload data
				Local $aCmd = StringSplit($oDev.Item('cmd'), " ")
				;__ConsolePrintVars("__viMbLoopRead bModbus=1, ", "aCmd", $aCmd)
				If $aCmd[0] >= 3 Then $bBufAcc = __viMbDecode($oDev, $bBufAcc, $aCmd[3])
			Else
				$bBufAcc = Binary("")                                       ; just in case we have error, set reply data to empty
			EndIf
		Else
			If $hFile Then
				FileClose($hFile)                                           ; close the file if response written to file
				$oDev.Item('download') = 0
			EndIf
		EndIf
		If Not $hFile Then __viRetQueuePush($oDev, $bBufAcc, $iStatus)      ; push response/reply into return queue
		$oDev.Item('rParse') = -1                                           ; reinitialize settings to look for next incomming data
		;$oDev.Item('rHeaderLen') = 0
		$oDev.Item('rExpLen') = -1
		$oDev.Item('rBuf') = $bLeftOvers
		$oDev.Item('rCount') = BinaryLen($bLeftOvers)
		$oDev.Item('rdone') = True                                          ; signal main/client code that we have a newly received message
		__viLoopExecReqComplete($oDev)                                      ; signal request/command is complete
		$oDev.Item('waitReply') = False                                     ; signal cmd that it has received reply and can move to next command
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
				__viLoopExecReqComplete($oDev)
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

	;__ConsolePrintVars("__viLoopExec, ", "oDev", $oDev, "oStack", $oStack)        ; debug

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

		$bLoopExit = True
		If __DequeIsDeque($oStackTop) Then $bLoopExit = __pQueIsParked($oStackTop)
		If $bLoopExit Then                                                                  ; if cStack is empty or the pQue on the top of the stack is parked then
			If $bQreqEmpty Then Return __viLoopExecClose($oDev)                             ;   if no more commands in qreq and cStack is empty then close connection and return 1 (ok)
			$aReq = __viReqQueuePop($oDev)                                                  ;   pull next command to process from main queue
			ExitLoop                                                                        ;   jump to command processing
		EndIf                                                                               ; end if

		If __pQueIsStart($oStackTop) Then                                                   ; if we just started processing the oStackTop queue then
			$sCmd = __pQueCmd($oStackTop)                                                   ;   $sCmd = the command that created this block
			$bCond = False
			If $sCmd = "else" Then                                                          ;   if it is an 'else' block then
				$bCond = $bSkipElse                                                         ;     if previous 'if/then' block executed then we skip this 'else' block
				If $g_viPrintpQueCond Then _
						__ConsolePrintVars("__viLoopExecStack, ", "else cond", Not $bCond)

			ElseIf $sCmd = "if" Then                                                        ;   else if it is an 'if/then' block then
				$bCond = __viEvalExpr(__pQueCond($oStackTop), $oDev)                        ;     evaluate the loop condition and if false then exit the block
				$oStackTop.Item('bCond') = $bCond
				If $g_viPrintpQueCond Then _
						__ConsolePrintVars("__viLoopExecStack, ", "if cond " & $bCond, __pQueCond($oStackTop))
				$bCond = Not $bCond

			ElseIf $sCmd = "while" Then                                                     ;   else if it is a 'while' block then
				$bCond = Not __viEvalExpr(__pQueCond($oStackTop), $oDev)                    ;     evaluate the loop condition and if false then exit the block
				If $g_viPrintpQueCond Then _
						__ConsolePrintVars("__viLoopExecStack, ", "while cond " & (Not $bCond), __pQueCond($oStackTop))

			EndIf                                                                           ;   end if

			If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> " & $sCmd & " (" & (Not $bCond) & ")" & @CRLF)

			If $bCond Then                                                                  ;   if condition is true then
				__viLoopExecStackPop($oStack, $oDev)                                        ;     exit the block
				ContinueLoop                                                                ;     loop back and recheck the stack
			EndIf                                                                           ;   end if

		ElseIf __pQueIsDone($oStackTop) Then                                                ; if we finished processing this statement block then

			If $g_viPrintCondCmds Then _
					__ConsolePrintVars("__viLoopExecStack, ", "pQue is done", $oStackTop)

			__pQueRestart($oStackTop)                                                       ;   reset PC to begining of the block
			$sCmd = __pQueCmd($oStackTop)                                                   ;   $sCmd = the command that created this block
			$bCond = True                                                                   ;   default to true to exit this block
			If $sCmd = "if" Then                                                            ;   if it is an 'if/then' block then
				$bSkipElse = $oStackTop.Item('bCond')                                       ;     if the 'if' cond was true then we skip the following 'else' block
				;$bCond = True

			ElseIf $sCmd = "while" Then                                                     ;   if it is a 'while' block then
				ContinueLoop                                                                ;     loop back and start from testing the condition

			ElseIf $sCmd = "until" Then                                                     ;   else if it is an 'until' block then
				$bCond = __viEvalExpr(__pQueCond($oStackTop), $oDev)                        ;     if loop condition is true then set flag to exit the block
				If $g_viPrintpQueCond Then _
						__ConsolePrintVars("__viLoopExecStack, ", "until cond " & $bCond, __pQueCond($oStackTop))
				If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> " & $sCmd & " (" & $bCond & ")" & @CRLF)

			EndIf                                                                           ;   end if
			If $bCond Then                                                                  ;   if condition is true then
				__viLoopExecStackPop($oStack, $oDev)                                        ;     exit the block
				ContinueLoop                                                                ;     loop back and recheck the stack
			EndIf                                                                           ;   end if

		EndIf                                                                               ; end if

		$aReq = __pQuePCitem($oStackTop)                                                    ; pull statement to execute from block
		$bLoopExit = Not __DequeIsDeque($aReq)                                              ; if aReq is a statement block then
		If Not $bLoopExit Then __viLoopExecStackPushDbg($oStack, $aReq, $oDev)              ;   push it onto the stack and loop back for processing
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

	If $oDev.Exists('debug') Then $oDev.Item('debug') &= "< '" & $sReq & "'" & @CRLF


	;
	; conditional statement processing: first time processing
	;

	If $g_viPrintCondCmds Then __ConsolePrintVars("__viLoopExec, ", "cond cmd", $aReq)      ; debug

	$sReq = StringStripWS($sReq, 3)                                                         ; trim leading and trailing white spaces
	If StringLeft($sReq, 1) = "#" Or $sReq = "" Then Return 1                               ; skip comments and blank lines


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
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg), $oDev, _
				Not __viEvalExpr($sArg, $oDev))                                             ;   push start of new 'if' statement block into cStack
		If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> " & $sCmd & " " & $sArg & @CRLF)

		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "else" Then                                                              ; else if cmd is 'else' then
		If $spCmd = "if" Then                                                               ;   close previous 'if' statement block and set 'skip' flag for this 'else' block
			$bSkip = Not $bSkip                                                             ;   'else' block 'skip' flag evaluate to opposite of 'if' block 'skip' flag
			__viLoopExecUnparkStackPop($oStack, $oStackTop, $oDev)                          ;   close the 'if' block
		EndIf
		If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> " & $sCmd & @CRLF)
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg), $oDev, $bSkip)              ;   push start of new 'else' statement block into cStack
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "while" Then                                                             ; else if cmd is 'while' then
		$bSkip = Not __viEvalExpr($sArg, $oDev)                                             ;   evaluate cond before starting loop and set 'skip' flag as needed
		If $g_viPrintCondCmds Then __ConsolePrintVars("__viLoopExec, ", "cond cmd while " & $sArg, $bSkip)
		If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> " & $sCmd & " " & $sArg & @CRLF)
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg), $oDev, $bSkip)              ;   push start of new 'while/end' statement block into cStack
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "end" Or $sCmd = "wend" Or $sCmd = "endif" Then                          ; else if cmd is 'end' then close 'if' or 'while' block
		If $g_viPrintCondCmds Then __ConsolePrintVars("__viLoopExec, ", "end cmd pre  oStack", $oStack)
		If $spCmd = "while" Then                                                            ;   if closing 'while' block then
			__pQueRelease($oStackTop)                                                       ;     unpark the block and leave it at the top of the stack for looping
			If $bSkip Then __viLoopExecUnparkStackPop($oStack, $oStackTop, $oDev)           ;     if skip flag set then pop the while block off the execution stack
			If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> end while" & @CRLF)

		ElseIf $spCmd = "if" Then                                                           ;   else if closing 'if' block then
			__viLoopExecUnparkStackPop($oStack, $oStackTop, $oDev)                          ;     close the block and pop it off the stack
			If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> end if" & @CRLF)

		ElseIf $spCmd = "else" Then                                                         ;   else if closing 'else' block then
			__viLoopExecUnparkStackPop($oStack, $oStackTop, $oDev)                          ;     close the block and pop it off the stack
			If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> end if" & @CRLF)

		EndIf                                                                               ;   end if		(else it does not match any qualified statements, we ignore it)
		If $g_viPrintCondCmds Then __ConsolePrintVars("__viLoopExec, ", "end cmd post oStack", $oStack)
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "do" Then
		__viLoopExecStackPush($oStack, __pQueNew($sCmd, $sArg), $oDev)                      ; push start of new 'do/until' statement block into cStack
		If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> do" & @CRLF)
		Return 1                                                                            ;   return, we are done processing this statement

	ElseIf $sCmd = "until" Then
		If $spCmd <> "do" Then Return 1                                                     ; script has until without do, ignore until
		__pQueSet($oStackTop, $sCmd, $sArg)                                                 ; update the 'cmd' field to 'until'
		__pQueSetDone($oStackTop)                                                           ; set the queue to the 'done' state so it is caught on next cycle for evaluating loop condition
		If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> until " & $sArg & " (" & $bSkip & ")" & @CRLF)
		If $bSkip Then __viLoopExecUnparkStackPop($oStack, $oStackTop, $oDev)               ; if skip flag set then do not loop this block
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


	If $g_viPrintCmds Then __ConsolePrintVars("__viLoopExec, ", $oDev.Item('sAddr') & " visa send", $aReq)


	__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                               ; parse the command string


	Local $bEOL = 1                                                                         ; 1 = set visa to interpret EOL, 0 = ignore EOL (for binary transfers)

	; non-conditional statement preprocessing
	Local $aMatch

	$aMatch = StringRegExp($sReq, "^\$\$\S*?=", 1)                                           ;
	If Not @error Then                                                                      ; if req starts with $$expr= then
		Local $var = StringTrimLeft(StringTrimRight($aMatch[0], 1), 2)                      ;   remove the trailing = and leading $$
		$bEOL = Int(StringRight($var, 1) <> ":")                                            ;   if $$expr:= then set bEOL to 0 for binary transfer
		If Not $bEOL Then $var = StringTrimRight($var, 1)
		$oDev.Item('rExec') = $var
		$sReq = StringStripWS(StringTrimLeft($sReq, StringLen($aMatch[0])), 3)              ;   remove the $$expr= prefix from the command
		$waitReply = True                                                                   ;   force waitReply to true so we wait for the results
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf                                                                                   ; endif

	$aMatch = StringRegExp($sReq, "^\$\S*?=", 1)                                            ;
	If Not @error Then                                                                      ; if req starts with $var= then
		Local $var = StringTrimRight($aMatch[0], 1)                                         ;   remove the trailing =, keep leading $ in case its an empty variable
		$bEOL = Int(StringRight($var, 1) <> ":")                                            ;   if $var:= then set bEOL to 0 for binary transfer
		If Not $bEOL Then $var = StringTrimRight($var, 1)
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
		$bEOL = 0                                                                           ;   bEOL = 0 for binary transfer
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf                                                                                   ; endif

	$aMatch = StringRegExp($sReq, "^((?i)download::(.*?)::)", 1)
	If Not @error Then                                                                      ; if line starts with download::filename:: then
		Local $sFile = $aMatch[1]                                                           ;   extract the filename
		$sReq = StringStripWS(StringTrimLeft($sReq, StringLen($aMatch[0])), 3)              ;   extract the command statement
		__viLoopExecDownloadPrep($oDev, $sFile)                                             ;   open download file for writing and set $oDev('download') so response is written to file
		$waitReply = True
		$bEOL = 0                                                                           ;   bEOL = 0 for binary transfer
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf                                                                                   ; endif

	If StringLeft($sCmd, 3) = "ret" Then                                                    ; if a return notice is requested then set up for response/status to go to rNotice
		$oDev.Item('rNotice') = StringTrimLeft($sCmd, 3)                                    ;   set the return notice
		$sReq = StringStripWS(StringTrimLeft($sReq, StringLen($sCmd)), 3)                   ;   extract the command statement
		__viLoopExecParseCmd($sReq, $sCmd, $sArg, $sArg1, $sArg2)                           ;   parse the new statement
	EndIf



	If $g_viPrintCondCmds Then __ConsolePrintVars("exec cmd, ", "sReq", $sReq, "sArg", $sArg, "sArg1", $sArg1, "sArg2", $sArg2, "waitReply", $waitReply)



	;
	; statement processing:  script commands
	;


	If $sCmd = "sleep" Then
		$oDev.Item('cmd') = "s"                                                             ; $oDev.Item('cmd'] = "s" for sleep
		$oDev.Item('timeout') = Int(__viEvalExpr($sArg, $oDev))                             ; $oDev.Item('timeout'] = duration
		$oDev.Item('cdone') = False
		Return 1

	ElseIf $sCmd = "close" Then                                                             ; intentionally close the connection
		__viLoopExecClose($oDev)
		Return 1

	ElseIf $sCmd = "cd" Or $sCmd = "chdir" Then                                             ; change the current working directory
		FileChangeDir(__viEvalExprStrs($sArg, $oDev))
		Return 1

	ElseIf $sCmd = "logfile" Then                                                           ; set the file name/path of the logfile
		$g_logfile = _PathFull(__viEvalExprStrs($sArg, $oDev))
		Return 1

	ElseIf $sCmd = "log" Or $sCmd = "print" Then                                            ; write a line to the logfile - output data
		Local $hFile = FileOpen($g_logfile, $FO_APPEND)
		If $hFile > 0 Then
			FileWrite($hFile, __viEvalExprStrs($sArg, $oDev) & @CRLF)
			FileClose($hFile)
		EndIf
		Return 1

	ElseIf $sCmd = "set" Then                                                                       ; set a variable to a value, perform a function or evaluate expression
		If StringLeft($sArg1, 1) = "$" Then $sArg1 = StringTrimLeft($sArg1, 1)
		AssignEx($sArg1, __viEvalExpr($sArg2, $oDev), $oDev)
		If $g_viPrintCmds Then __ConsolePrintVars("__viLoopExec, ", $oDev.Item('sAddr') & " set " & $sArg1, EvalEx($sArg1, $oDev))
		Return 1

	ElseIf $sCmd = "dset" Then                                                                      ; set a variable the global dictionary
		If StringLeft($sArg1, 1) = "$" Then $sArg1 = StringTrimLeft($sArg1, 1)
		AssignDict($sArg1, __viEvalExpr($sArg2, $oDev))
		If $g_viPrintCmds Then __ConsolePrintVars("__viLoopExec, ", $oDev.Item('sAddr') & " set " & $sArg1, EvalEx($sArg1, $oDev))
		Return 1

	ElseIf $sCmd = "sset" Then                                                                      ; set a variable in the device config dictionary (oDev)
		If StringLeft($sArg1, 1) = "$" Then $sArg1 = StringTrimLeft($sArg1, 1)
		AssignDict($sArg1, __viEvalExpr($sArg2, $oDev))
		If $g_viPrintCmds Then __ConsolePrintVars("__viLoopExec, ", $oDev.Item('sAddr') & " set " & $sArg1, EvalEx($sArg1, $oDev))
		Return 1

	ElseIf $sCmd = "flush" Then
		__viFlushInputBuffer($oDev)                                                                 ; flush input buffer
		$oDev.Item('qret') = __DequeNew()                                                           ; dump return queue
		$sReq = @CRLF & $VI_REQ_ERR                                                                 ; send an empty command to terminate any prior input to device
		$oDev.Item('rVar') = "$"                                                                    ; follow command with ERR request to flush any error codes
		;																							; fall thru to execute commands

	ElseIf $sCmd = "flushinput" Then
		__viFlushInputBuffer($oDev)                                                                 ; flush input buffer
		Return 1

	ElseIf $sCmd = "flushret" Then
		$oDev.Item('qret') = __DequeNew()                                                           ; dump return queue
		Return 1

	ElseIf $sCmd = "getret" Or $sCmd = "read" Then                                                  ; (dbgTab) take reply from previous command and assign it to a variable
		$sArg = __viEvalExprStrs($sArg, $oDev)
		If StringLeft($sArg, 1) = "$" Then $sArg = StringTrimLeft($sArg, 1)
		Local $sR = __viRetQueuePop($oDev)                                                          ; pull return value from previous command
		If $sArg <> "" Then AssignEx($sArg, $sR, $oDev)
		Return 1

		; legacy code
		;	ElseIf $sCmd = "upload" Then                                                            ; include this before the visa command that initiates the transfer
		;		__viLoopExecUploadPrep($oDev, __viEvalExprStrs($sArg,$oDev))
		;		Return 1

		;	ElseIf $sCmd = "download" Then                                                          ; include this before the visa command that initiates the transfer
		;		__viLoopExecDownloadPrep($oDev, __viEvalExprStrs($sArg,$oDev))
		;		Return 1

	ElseIf $sCmd = "parsepic" Then                                                          ; include this after download of a picture file
		Local $sFile = __viParsePicture(__viEvalExprStrs($sArg, $oDev))                     ;   fix picture file (strip extra header, find extension), and return=file name
		__viRetQueuePush($oDev, $sFile)
		Return 1

	ElseIf $sCmd = "modbuswrite" Then                                                       ; send a modbus register write command
		$aArg = StringSplit(StringRegExpReplace(__viEvalExprStrs($sArg, $oDev), "\s+", " "), " ")
		If UBound($aArg) >= 3 Then
			$oDev.Item('cmd') = "modbus write " & $aArg[1] & " " & $aArg[2] & " " & $aArg[3]
			__viMbWrite($oDev, $aArg[1], $aArg[2], $aArg[3])                                ; params: $oDev, type=(32|64)(i|f), address, value
		EndIf
		Return 1

	ElseIf $sCmd = "modbusread" Then                                                        ; send a modbus register read command
		$oDev.Item('waitReply') = True
		$oDev.Item('rMode') = 1                                                             ; expect modbus tcp frame reply
		$aArg = StringSplit(StringRegExpReplace(__viEvalExprStrs($sArg, $oDev), "\s+", " "), " ")
		If UBound($aArg) >= 2 Then
			$oDev.Item('cmd') = "modbus read " & $aArg[1] & " " & $aArg[2]
			__viMbRead($oDev, $aArg[1], $aArg[2])                                           ; params: $oDev, type=N(i|f|s), address
		EndIf
		Return 1

	EndIf




	; if we are main queue then send visa commands to target device queues

	If $oDev.Item('index') = "main" Then                                ; if we are main queue then
		If StringLeft($sCmd, 3) = "sel" Then                            ;   if we are main queue and 'select' command then select device target for visa commands
			If $g_oViSelect.Exists($sArg) Then $g_oViSelect.Item('active') = $g_oViSelect.Item($sArg)
			Return 1
		EndIf

		; 																;   else $sReq is a visa statement to send to selected/active device
		If Not $g_oViSelect.Exists('active') Then Return 1              ;   if no target device then return with nothing done
		Local $oDevT = $g_oViSelect.Item('active')
		__viReq($oDevT, "ret0 " & $sReq, $waitReply, $oDev.Item('timeout')) ; put visa command in target device queue and request notification to '0'
		$oDev.Item('wNotice') = '0'                                     ;   flag that we are waiting on notification from '0'
		$oDev.Item('cmd') = $sReq
		$oDev.Item('waitReply') = True                                  ;   set waitReply flag so we wait until wNotice reply
		Return 1
	EndIf



	;
	; statement processing:  visa/scpi statement to send to visa device
	;


	If $sCmd = "write" Or $sCmd = "send" Then _                                             ; optional prefix visa statement with 'write' or 'send'
			$sReq = StringTrimLeft($sReq, StringLen($sCmd) + 1)                             ;   remove prefix

	$sReq = __viEvalExprStrs($sReq, $oDev)                                                  ; evaluate expressions {expr} and substitute
	$oDev.Item('cmd') = $sReq                                                               ; note current command being processed
	If StringRight($sReq, 1) = "?" Then $waitReply = True                                   ; if request string ends in ? then assume we are getting a reply


	If Not __viConnect($oDev) Then                                                          ; if we cannot connect then
		If $waitReply Then                                                                  ;   if command wants a reply then push error code return
			__viRetQueuePush($oDev, "", -1)                                                 ;     push error code return
			$oDev.Item('creturn') = -1                                                      ;     set command return code to error
		EndIf                                                                               ;   end if
		__viLoopExecReqComplete($oDev)
		; note: using $waitReply local variable.  oDev(waitReply) was never set, so we do not need to clear it here. see command a couple of lines below
		Return SetError(-1, 0, 0)                                                           ;   return error
	EndIf                                                                                   ; end if
	$oDev.Item('waitReply') = $waitReply                                                    ; set waitReply to what was requested

	If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "> " & $oDev.Item('cmd') & @CRLF) ;  & "  '" & $sReq & "'" & @CRLF)

	;if $oDev.Item('viIpMode') then __viFlushInputBuffer($oDev)  							; if raw socket mode then flush input buffer before sending next command as a precaution

	If $oDev.Item('timeout') > 0 Then __viSetTimeout($oDev)                                 ; set visa timeout

	Local $hFile = $oDev.Item('upload')
	If StringLeft($hFile, 1) = "," Then                                                     ; if we are sending a file with this command then
		Local $iPos = StringInStr(StringMid($hFile, 2), ",")
		$oDev.Item('upload') = Int(StringMid($hFile, $iPos + 2))                            ;   extract the file handle
		Local $sHeader = StringMid($hFile, 2, $iPos - 1)                                    ;   extract the header
		$sReq &= $sHeader                                                                   ;   add IEEE 488.2 header
		$bEOL = 0
	Else                                                                                    ; else
		$sReq &= @CRLF                                                                      ;   add message terminator
	EndIf                                                                                   ; endif
	__viSetEOLenable($oDev, $bEOL)                                                          ; set EOL interpretation for text (1) or binary (0) file transfers



	$oDev.Item('creturn') = __viReqSend($oDev, $sReq)                                       ; send the request string to the visa device

	If $waitReply Then $oDev.Item('rdone') = False                                          ; reset read done indicator if we need a reply
	If $hFile = 0 Then                                                                      ; if not a file upload operation then
		If Not $waitReply Then __viLoopExecReqComplete($oDev)                               ;   if no reply needed, then raise the request done flag
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
;		$oDev passed in so we have access to it as a local variable for the Execute function
Func __viEvalExprStrs($sText, $oDev)
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


;		$oDev passed in so we have access to it as a local variable for the Execute function
Func __viEvalExpr($sExpr, $oDev)                                                        ; evaluate a single expression
	If StringLeft($sExpr, 1) = "{" Then $sExpr = StringTrimLeft($sExpr, 1)
	If StringRight($sExpr, 1) = "}" Then $sExpr = StringTrimRight($sExpr, 1)
	Local $vRet = Execute($sExpr)
	If @error Then $vRet = String($sExpr)
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


Func __viLoopExecStackPush($oStack, $opQue, $oDev, $bSkip = False)                      ; push new opQue item onto cStack
	Local $oStackTop = __StackPeek($oStack)
	$bSkip = __pQueSkip($opQue) Or $bSkip                                               ; merge 'skip' flag with opQue's skip flag
	If __DequeIsDeque($oStackTop) Then                                                  ; additionally if opQue at top of stack is parked then push this opQue into it as well
		If __pQueIsParked($oStackTop) Then __pQuePush($oStackTop, $opQue)
		$bSkip = __pQueSkip($oStackTop) Or $bSkip                                       ; merge 'skip' flag from current opQue on top of stack
	EndIf
	__pQueSkip($opQue, $bSkip)                                                          ; set opQue 'skip' flag to merged bSkip
	__viLoopExecStackPushDbg($oStack, $opQue, $oDev)                                    ; push opQue onto the stack
	If $g_viPrintCondCmds Then __ConsolePrintVars("__viLoopExecStackPush, ", "opQue", $opQue)
EndFunc   ;==>__viLoopExecStackPush

Func __viLoopExecStackPushDbg($oStack, $opQue, $oDev)                                   ; process execute Stack Push, update debug edit boxes if enabled
	__StackPush($oStack, $opQue)
	If $oDev.Exists('debug') Then
		If __IsDictionary($opQue) Then
			Local $s = '', $sCmd = '', $bSkip = ''
			If $opQue.Exists('cmd') Then $sCmd = $opQue.Item('cmd')
			If $opQue.Exists('skip') Then $bSkip = $opQue.Item('skip')
			$s &= $sCmd
			If $opQue.Exists('cond') Then $s &= " " & $opQue.Item('cond')
			If $sCmd = "if" Then $s &= " (" & (Not $bSkip) & ")"
			If $opQue.Exists('bCond') Then $s &= ", bCond=" & $opQue.Item('bCond')
			$s &= ", skip=" & $bSkip
			__GUICtrlEdit_StackPush($g_dbg_hStack, $s)
		EndIf
	EndIf
EndFunc   ;==>__viLoopExecStackPushDbg


Func __viLoopExecUnparkStackPop($oStack, $oStackTop, $oDev)
	__pQueRelease($oStackTop)                                                           ; unpark the statement block on the top of the stack so it will be executed on next encounter
	__viLoopExecStackPop($oStack, $oDev)                                                ; close the statement block by removing it from the stack
EndFunc   ;==>__viLoopExecUnparkStackPop

Func __viLoopExecStackPop($oStack, $oDev)                                               ; pop items off the execute stack
	__StackPop($oStack)
	If $oDev.Exists('debug') Then __GUICtrlEdit_StackPop($g_dbg_hStack)
EndFunc   ;==>__viLoopExecStackPop

Func __viLoopExecReqComplete($oDev)                                                     ; request is complete, set the flag and check on notifications
	Local $rNotice = String($oDev.Item('rNotice'))
	If $rNotice <> "" Then
		If Not $g_oNotices.Exists($rNotice) Then $g_oNotices.Item($rNotice) = Null      ; if rNotice and it is not in oNotices then set it in oNotices
	EndIf
	;$oDev.Item('waitReply') = False                                                     ; signal cmd that it has received reply and can move to next command
	$oDev.Item('reqdone') = True                                                        ; flag request done for client code
EndFunc   ;==>__viLoopExecReqComplete




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
	Local $aErr = [-1, Binary("")], $aR = [0, Binary("")]
	If Not __viIsInstrument($oDev) Then Return SetError(1, 0, $aErr)
	Local $bData = Binary("")

	; -------------------------------------------------------------------------		; Stream Mode: Raw Socket
	If $oDev.Item('viIpMode') Then                                                  ;
		Local $hSocket, $iErr = 0, $bData
		$hSocket = $oDev.Item('viSocket')
		If $hSocket = 0 Then Return $aErr
		If Not __TCP_IsDataAvailable($hSocket) Then Return SetError(@error, @extended, @error ? $aErr : $aR)
		$bData = TCPRecv($hSocket, $iMaxLen, 1)
		$iErr = @error
		If $iErr = 10093 Then
			TCPStartup()
			Sleep(50)
			If Not __viOpen($oDev) Then Return SetError(3, 0, $aErr)
			$hSocket = $oDev.Item('viSocket')
			If Not __TCP_IsDataAvailable($hSocket) Then SetError(@error, @extended, @error ? $aErr : $aR)
			$bData = TCPRecv($hSocket, $iMaxLen, 1)
			$iErr = @error
		EndIf
		$aR[0] = ($iErr = 0 ? 1 : $iErr)                                            ; return 1 = ok, but possibly more data remaining, to match vxi-11 return value
		$aR[1] = $bData
		Return SetError(($iErr <> 0), 0, $aR)
	EndIf


	; -------------------------------------------------------------------------		; Stream Mode: VXI-11 visa32.dll
	Local $hSession = $oDev.Item('viSession')
	If $hSession = 0 Then Return SetError(3, 0, $aErr)
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
		Return SetError(-1, 0, $aErr)                                               ;   return error
	EndIf                                                                           ; endif
	Local $iStatus = $aRead[0]                                                      ; status of viRead
	__viSetTMO($hSession, $iOriginalTimeout)                                        ; restore original timeout setting
	If $iStatus = $VI_ERROR_TMO Then                                                ; if timeout then we received no data - emulate nonblocking read
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



;			__viFlushInputBuffer
; task:		flush the input buffer until all previous data is emptied out of it
Func __viFlushInputBuffer(ByRef $oDev, $iTimeoutMS = 3000)
	If Not __viResolveInstrument($oDev) Then Return 0
	Local $sTrash, $iErr, $iTimer = TimerInit()
	; Set a tight timeout or loop quickly to consume all residual data
	If $oDev.Item('viIpMode') Then
		Local $hSocket = $oDev.Item('viSocket')
		Do
			$sTrash = ""
			If __TCP_IsDataAvailable($hSocket) Then _
					$sTrash = TCPRecv($hSocket, 2048, 1)        ; Read up to 2048 bytes at a time
			$iErr = @error
		Until $sTrash = "" Or $iErr Or TimerDiff($iTimer) > $iTimeoutMS
	Else
		Do
			$sTrash = __viReadBuf($oDev, 0x400)
			$iErr = @error Or $sTrash[0]
			$sTrash = $sTrash[1]
		Until $sTrash = "" Or $iErr Or TimerDiff($iTimer) > $iTimeoutMS
	EndIf
	Return 1
EndFunc   ;==>__viFlushInputBuffer



Func __viFlushErrors(ByRef $oDev)
	Local $i = 10
	While __viGetError($oDev) <> 0 And $i > 0
		$i -= 1
	WEnd
EndFunc   ;==>__viFlushErrors



Func __viGetError(ByRef $oDev)
	Local $sR = __viReqBl($oDev, $VI_REQ_ERR)
	If @error Then Return -1
	Local $i = StringInStr($sR, ",")
	If $i > 0 Then $sR = StringLeft($sR, $i - 1)
	Return Int(Number($sR))
EndFunc   ;==>__viGetError



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
	If $g_viPrintQueuePush Then __ConsolePrintVars("qout, ", "push", $aReq)
	If $oDev.Exists('debug') Then __GUICtrlEdit_QueuePush($g_dbg_hQueue, __sPrintVar($aReq, ", "))
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
	If $g_viPrintQueuePop Then __ConsolePrintVars("quot, ", "pop", $aR)
	If $oDev.Exists('debug') Then __GUICtrlEdit_QueuePop($g_dbg_hQueue)
	Return $aR
EndFunc   ;==>__viReqQueuePop



Func __viRetQueuePush($oDev, $sRet, $iStatus = 0)                                   ; push return item into the return queue.  $sRet = return string, $iStatus=error status
	If Not __viIsInstrument($oDev) Then Return SetError(-1, 0, 0)
	If __viProcRet($oDev, $sRet, $iStatus) Then Return 1                            ; process the reply.  if it returns true then we do not push the reply into qret queue

	Local $a[2]
	$a[0] = $sRet
	$a[1] = $iStatus
	__QueuePush($oDev.Item('qret'), $a)
	If $g_viPrintQueuePush Then __ConsolePrintVars("__viRetQueuePush, ", "qin  push", $a)
	If $g_viPrintCmds Or $g_viPrintReplies Then _
			__ConsolePrintVars($oDev.Item('sAddr') & " , ", "visa recv", (IsBinary($sRet) ? StringStripWS(BinaryToString($sRet), 3) : $sRet))
	Return 1
EndFunc   ;==>__viRetQueuePush


Func __viGUISetID($cDevID, $sId)
	GUICtrlSetData($cDevID, $sId)
	_GUICtrlEdit_SetSel($cDevID, 0, 0)
EndFunc   ;==>__viGUISetID


Func __viProcRet($oDev, $sRet, $iStatus = 0)  ; return true if we processed the reply completely and do not need it pushed into the return queue (qret)
	If $oDev.Item('cmd') = $VI_IDN Then                                             ; if we requested identity string then harvest it
		Local $sIdn = StringStripWS(BinaryToString($sRet), 3)
		$oDev.Item('viIdn') = $sIdn
		If $sIdn <> "" Then                                                         ; if there is a reply to the IDN request then
			Local $sClass = __viClassifyItem($sIdn)
			$oDev.Item('viType') = String($sClass)                                  ;   classify this device
			If Not $g_oViSelect.Exists($sClass) Then $g_oViSelect.Item($sClass) = $oDev ; if there is not already an entry for the device of this type they add it to the select list
			If $oDev.Exists('hDevID') Then
				__viGUISetID($oDev.Item('hDevID'), ($sIdn = '') ? 'Not Found' : $sIdn)
				$oDev.Remove('hDevID')
			EndIf
			If $oDev.Exists('bCommValid') Then
				Assign($oDev.Item('bCommValid'), Not ($sIdn = ""), 2)
				$oDev.Remove('bCommValid')
			EndIf
			;__viReq($oDev,"$=" & $VI_REQ_ERR)   									;   flush any errors from the IDN scan/query
			;__viReq($oDev,"$=" & $VI_REQ_ERR)
		EndIf                                                                       ; end if
	EndIf

	Local $rNotice = String($oDev.Item('rNotice'))
	If $rNotice <> "" Then $g_oNotices($rNotice) = $sRet                            ; if we have a request to give notice of completion then copy reply into notice

	Local $rVar
	If $oDev.Exists('rVar') Then
		$rVar = $oDev.Item('rVar')
		If $rVar <> "" Then                                                         ; if rVar is not blank then we are saving to a variable
			If StringRight($rVar, 4) <> "Data" Then                                 ;   if variable name ends in "Data" then leave the result as a binary object
				If IsBinary($sRet) Then $sRet = StringStripWS(BinaryToString($sRet), 3) ; if reply is binary then convert to string
			EndIf                                                                   ;   note: modbus replies will be decoded into int or float before they reach here
			If StringLeft($rVar, 1) = "$" Then $rVar = StringTrimLeft($rVar, 1)
			If $g_viPrintQueuePush Or $g_viPrintQueuePop Then __ConsolePrintVars("__viRetQueuePush, ", "qin $" & $rVar, $sRet)
			If $g_viPrintCmds Or $g_viPrintReplies Then __ConsolePrintVars($oDev.Item('sAddr') & " visa recv:, ", "$" & $rVar, $sRet)
			If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "< $" & $rVar & "=" & __sPrintVar($sRet) & @CRLF)

			If $rVar <> "" Then AssignEx($rVar, $sRet, $oDev)
			$oDev.Item('rVar') = ''
			Return True
		EndIf
	EndIf

	If $oDev.Exists('rExec') Then
		$rVar = $oDev.Item('rExec')
		If $rVar <> "" Then                                                         ; if rExpr is not blank then we are executing the expression
			If IsBinary($sRet) Then $sRet = StringStripWS(BinaryToString($sRet), 3) ; if reply is binary then convert to string
			Execute($rVar)                                                          ; execute the expression
			If $g_viPrintQueuePush Or $g_viPrintQueuePop Then __ConsolePrintVars("__viRetQueuePush, ", "qin $$" & $rVar, $sRet)
			If $g_viPrintCmds Or $g_viPrintReplies Then __ConsolePrintVars($oDev.Item('sAddr') & " visa recv:, ", "$$" & $rVar, $sRet)

			If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "< Execute(" & $rVar & ") with " & _
					__sPrintVar(IsBinary($sRet) ? StringStripWS(BinaryToString($sRet), 3) : $sRet, ", ", "sRet") & @CRLF)
			$oDev.Item('rExec') = ''
			Return True
		EndIf
	EndIf

	If $oDev.Exists('debug') Then __GUICtrlEdit_Append($g_dbg_hOutput, "< " & _
			__sPrintVar(IsBinary($sRet) ? StringStripWS(BinaryToString($sRet), 3) : $sRet, ", ") & @CRLF)
	Return ($rNotice <> "")
EndFunc   ;==>__viProcRet



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
	If Not $bBin And IsBinary($sRet) Then $sRet = StringStripWS(BinaryToString($sRet), 3)
	If $g_viPrintQueuePop Then __ConsolePrintVars("qin  pop , ", "creturn", $oDev.Item('creturn'), "iErr", $iErr, "sRet", $sRet)
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
Func __viReq(ByRef $oDev, $sReq, $bWait = True, $iTimeoutMS = 1000, $bForceNoWait = False)
	If $sReq = "" Then Return                                       ; skip blank command
	If StringLeft($sReq, 2) = "//" Then Return                      ; skip comment lines
	Local $iTo = StringRegExp($sReq, "^([0-9]*!)", 1)               ; parse optional timeout
	If @error Then
		$iTo = $iTimeoutMS
	Else
		$iTo = $iTo[0]
		$sReq = StringTrimLeft($sReq, StringLen($iTo))
		$iTo = Int(StringTrimRight($iTo, 1))
		If $iTo > 0 Then $bWait = True
	EndIf
	If StringRight($sReq, 1) = "?" Then $bWait = True
	If $bForceNoWait Then
		$bWait = False
		$iTo = 0
	EndIf
	Return __viReqQueuePush($oDev, $sReq, $bWait, $iTo)
EndFunc   ;==>__viReq

Func __viCmd(ByRef $oDev, $sCmd, $bForceNoWait = False)
	If $bForceNoWait Then Return __viReq($oDev, $sCmd, False, 0, True)
	Return __viReq($oDev, $sCmd, False)
EndFunc   ;==>__viCmd


Func __viUploadFile(ByRef $oDev, $sFile, $sReq, $iTimeoutMS = 5000)
	Return __viReq($oDev, "upload::" & $sFile & "::" & $sReq, False, $iTimeoutMS)
EndFunc   ;==>__viUploadFile

Func __viDownloadFile(ByRef $oDev, $sFile, $sReq, $iTimeoutMS = 5000)
	Return __viReq($oDev, "download::" & $sFile & "::" & $sReq, True, $iTimeoutMS)
EndFunc   ;==>__viDownloadFile

Func __viDownloadPicture(ByRef $oDev, $sFile, $sReq, $iTimeoutMS = 5000)
	__viDownloadFile($oDev, $sFile, $sReq, $iTimeoutMS)
	__viCmd($oDev, "parsepic " & $sFile)
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
;			$iTimeSpacer = ms to wait between commands
; out:		all names of downloaded files are pushed into the qret queue, use __viRet to retrieve
Func __viScript(ByRef $oDev, $vCmds, $sFile = "", $iTimeoutMS = 1000, $iTimeSpacer = 0)
	Local $aCmds[0]
	If __IsDictionary($vCmds) Then                          ; check script input and convert it to an array of commands for processing
		If __DequeIsDeque($vCmds) Then
			$aCmds = __DequeToArray($vCmds)                 ; convert queue to array
		Else
			Local $sKey, $iCount = $vCmds.Count             ; convert dictionary to array
			ReDim $aCmds[$iCount]
			Local $i = 0
			For $sKey In $vCmds
				$aCmds[$i] = $vCmds.Item($sKey)
				$i += 1
			Next
		EndIf
	ElseIf IsMap($vCmds) Then                               ; convert map to array
		$aCmds = MapKeys($vCmds)
		Local $i, $n = UBound($aCmds) - 1
		For $i = 0 To $n
			$aCmds[$i] = $vCmds[$aCmds[$i]]
		Next
	ElseIf IsArray($vCmds) Then                             ; convert 2D array to 1D array
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
			$aCmds = $vCmds                                 ; already a 1D array, no conversion needed
		EndIf
	Else                                                    ; convert string to array
		If IsBinary($vCmds) Then $vCmds = BinaryToString($vCmds)
		$aCmds = StringSplit($vCmds, @CR & @LF, 0)
		$aCmds[0] = ""    ; make the 1-indexed array a 0-indexed array with an empty command in the front
	EndIf

	Local $i, $sCmd, $n = UBound($aCmds) - 1, $iMode, $iTo
	For $i = 0 To $n                                        ; send commands to the queue
		$sCmd = StringStripWS($aCmds[$i], 3)
		If $sCmd = "" Then ContinueLoop                     ; skip blank lines
		If StringLeft($sCmd, 2) = "//" Then ContinueLoop    ; skip comment lines

		$iTo = StringRegExp($sCmd, "^([0-9]*!)", 1)         ; parse optional timeout
		If @error Then
			$iTo = 0
		Else
			$iTo = $iTo[0]
			$sCmd = StringTrimLeft($sCmd, StringLen($iTo))
			$iTo = Int(StringTrimRight($iTo, 1))
		EndIf

		$iMode = Number(StringLeft($sCmd, 1) = "#")         ; parse optional download/picture flag
		If $iMode Then
			$iMode += Number(StringMid($sCmd, 2, 1) = "#")  ; parse "##" picture flag
			$sCmd = StringTrimLeft($sCmd, $iMode)
			If $sFile = "" Then $iMode = 0                  ; if file not specified then store file data on return queue
		EndIf
		If $iMode Then
			$sFile = __FileNameAutoIncrement($sFile)        ; roll $sFile to next available name
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
		If $iTimeSpacer > 0 Then __viCmd($oDev, "sleep " & $iTimeSpacer)
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
;				$sDataType = "Nt", n=number of 16-bit words, t=type (i=integer, f=float, s=string)
;				$iRegAddr = register address
;				$iTimeoutMS = timeout in ms
Func __mbRead(ByRef $oDev, $sDataType, $iRegAddr, $iTimeoutMS = 1500, $sPrefix = '')
	Return __viReq($oDev, $sPrefix & "modbusread " & $sDataType & " " & $iRegAddr, True, $iTimeoutMS)
EndFunc   ;==>__mbRead

Func __mbReadBl(ByRef $oDev, $sDataType, $iRegAddr, $iTimeoutMS = 1500, $sPrefix = '')
	Return __viReqBl($oDev, $sPrefix & "modbusread " & $sDataType & " " & $iRegAddr, True, $iTimeoutMS)
EndFunc   ;==>__mbReadBl

Func __mbRet(ByRef $oDev)
	Return __viRet($oDev, True)
EndFunc   ;==>__mbRet
Func __mbHasRet($oDev)
	Return __viHasRet($oDev)
EndFunc   ;==>__mbHasRet



;				__mbWrite
; task:			write a register
; in:			$oDev = vi device handle
;				$sDataType = "Nt", n=number of 16-bit words, t=type (i=integer, f=float, s=string)
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
; __viGetIDbg($oDev)							request device id, but run in background by putting commands in the script queue
; __viReqBl($oDev, $sReq, $bWait)				send request and wait for response, return response
; __viCmdBl($oDev, $sCmd)						send command (__viReq $bWait=false)
; __viEnd($oDev)								wait for last command to finish then close the connection.  return last response if available
;



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
	While Not __viIsIdle($oDev) And TimerDiff($iTimer) < $iTimeoutMS            ; wait for command queue to empty
		__viLoop()
		Sleep(1)
	WEnd
	While $oDev.Item('waitReply') And TimerDiff($iTimer) < $iTimeoutMS          ; wait for response
		__viLoop()
		Sleep(1)
	WEnd
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
; get ID



;			__viGetID
; task:		request ID from device, if it fails, then switch to other comm protocol and try again
; in:		$oDev = the IP address of the instrument in the form [raw:]IP[:port]
; out:		response string from VISA *IDN? request
Func __viGetID(ByRef $oDev, $iTimeoutMS = 1000, $retry = 1)
	__viFlushInputBuffer($oDev)                                                    ; when initially connecting we can flush the devices input traffic from any previous interactions
	Local $sRet = __viReqBl($oDev, $VI_IDN, True, $iTimeoutMS)
	If Not @error And $sRet <> "" Then Return $sRet
	If $retry = 0 Then Return SetError(@error, 0, $sRet)
	__viToggleMode($oDev)                                   ; switch between VXI-11 and raw socket modes
	$sRet = __viGetID($oDev, $iTimeoutMS, 0)                ; try again
	If Not @error And $sRet <> "" Then Return $sRet
	$sRet = __F4TgetID($oDev, $iTimeoutMS)                  ; try modbus
	If Not @error Then Return $sRet
	Return ""
EndFunc   ;==>__viGetID



Func __viGetIDbg(ByRef $oDev, $rVar = "", $iTimeoutMS = 1000, $retry = 1)
	If StringLeft($rVar, 1) = "$" Then $rVar = StringTrimLeft($rVar, 1)
	Local $aCmds[] = [ _
			"flush", _                                      ; flush input buffer
			"$" & $rVar & "=" & $VI_IDN, _                  ; try to read IDN from device
			"sleep 50", _                                   ; add a short delay to give instrument a breath
			"if $" & $rVar & "=''", _                       ; if no IDN then
			"{__viToggleMode($oDev)}", _                    ;   switch comm mode VXI-11 / raw socket
			"$" & $rVar & "=" & $VI_IDN, _                  ;   try to read IDN from device
			"end", _                                        ; endif
			'']
	__viScript($oDev, $aCmds)
EndFunc   ;==>__viGetIDbg





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
		__viCmd($oDev, StringStripWS($sLine, 3))
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

; TCP socket functions




; =======================================================================================================================
; Function Name:    __TCP_IsConnected
; Description:      Checks if a TCP socket connection is still alive and active without blocking execution.
; Parameter(s):     $hSocket - The AutoIt TCP socket identifier variable.
; Return Value(s):  True  - The socket is open and actively connected.
;                   False - The socket has disconnected, timed out, or encountered a hardware error.
; =======================================================================================================================
Func __TCP_IsConnected($hSocket)
	If IsArray($hSocket) Then $hSocket = $hSocket[0]                        ; Extract raw Win32 socket handle descriptor if AutoIt passed it as a tracking array
	$hSocket = Number($hSocket)
	If $hSocket <= 0 Then Return False
	Local $tMode = DllStructCreate("ulong")                                 ; --- STEP 1: FORCE SOCKET INTO NON-BLOCKING MODE ---
	DllStructSetData($tMode, 1, 1)                                          ; FIONBIO constant = 0x8004667E. Mode = 1 (Non-blocking)
	DllCall("ws2_32.dll", "int", "ioctlsocket", "handle", $hSocket, _
			"long", 0x8004667E, "struct*", $tMode)
	If @error Then Return False
	Local $iErr = 0
	Local $bConnected = False
	Local $tBuffer = DllStructCreate("byte")                                ; --- STEP 2: RUN THE VERIFICATION PEEK VIA WINSOCK RECV ---
	Local $aRecv = DllCall("ws2_32.dll", "int", "recv", _                   ; MSG_PEEK = 0x02. We use a tiny 1-byte binary buffer target.
			"handle", $hSocket, _
			"struct*", $tBuffer, _
			"int", 1, _
			"int", 0x02) ; MSG_PEEK
	If Not @error Then
		Local $iBytesReturned = $aRecv[0]
		If $iBytesReturned = 0 Then
			$bConnected = False                                             ; A clean return of 0 bytes during a read indicates a graceful connection close by the remote host
		ElseIf $iBytesReturned = -1 Then
			Local $aErr = DllCall("ws2_32.dll", "int", "WSAGetLastError")   ; Grab the specific Winsock failure reason code
			If Not @error Then $iErr = $aErr[0]                             ; If it throws 10035 (WSAEWOULDBLOCK), the socket is healthy but simply empty!
			If $iErr <> 10035 Then $bConnected = False                      ; Any other code (10054 Connection Reset, 10053 Aborted, etc.) means it is dead.
		EndIf
	EndIf
	DllStructSetData($tMode, 1, 0)                                          ; --- STEP 3: RESTORE SOCKET BACK TO BLOCKING MODE ---
	DllCall("ws2_32.dll", "int", "ioctlsocket", _                           ; Mode = 0 (Standard AutoIt blocking behavior)
			"handle", $hSocket, "long", 0x8004667E, "struct*", $tMode)
	Return SetError($iErr, 0, $bConnected)                                  ; return result
EndFunc   ;==>__TCP_IsConnected



Func __TCP_IsOpen($hSocket)                                                 ; Returns True if the socket connection is open.  False if it is closed or broken.
	If IsArray($hSocket) Then $hSocket = $hSocket[0]                        ; Extract raw Win32 socket handle descriptor if AutoIt passed it as a tracking array
	$hSocket = Number($hSocket)
	If $hSocket <= 0 Then Return False
	Local $tTimeVal = DllStructCreate("long tv_sec; long tv_usec;")         ; 1. Define a TIMEVAL struct with a 0-second timeout (Forces the call to be non-blocking)
	DllStructSetData($tTimeVal, "tv_sec", 0)
	DllStructSetData($tTimeVal, "tv_usec", 0)
	Local $tFdExcept = DllStructCreate("uint fd_count; uint fd_array[1];")  ; 2. Define an fd_set struct (Contains count of sockets followed by the socket array)
	DllStructSetData($tFdExcept, "fd_count", 1)                             ; [int fd_count; int fd_array[1]]
	DllStructSetData($tFdExcept, "fd_array", $hSocket, 1)
	Local $aRet = DllCall("Ws2_32.dll", "int", "select", _                  ; 3. Use Ws2_32.dll select() to peek at exceptions on the socket
			"int", 0, _                                                     ; select(0, readfds, writefds, exceptfds, timeout)
			"ptr", 0, _ ; Not monitoring for readable data
			"ptr", 0, _ ; Not monitoring for writeable space
			"struct*", $tFdExcept, _ ; Monitoring for errors/disconnections
			"struct*", $tTimeVal)    ; Non-blocking timeout pointer
	If @error Then Return False                                             ; Handle DllCall failure
	__ConsolePrintVars("__TCP_IsOpen, ", "aRet", $aRet, "hSocket", $hSocket)
	Return (0 = $aRet[0])                                                   ; return true if status is 0 - all ok
	;Local $iReadySockets = $aRet[0]                                        ; select returns the total number of sockets matching the condition
	;If $iReadySockets > 0 Then Return False                                ; The socket triggered an exception (disconnected, reset, or broken)
	;If $iReadySockets < 0 Then Return False                                ; select returned a socket error (e.g., -1 means the descriptor is invalid/already dead)
	;Return True                                                            ; 0 sockets triggered an exception, meaning the connection is alive and healthy
EndFunc   ;==>__TCP_IsOpen




; =======================================================================================================================
; Function Name:    __TCP_IsDataAvailable
; Description:      Checks if there is incoming data waiting to be read in the socket buffer without blocking.
; Parameter(s):     $hSocket - The AutoIt TCP socket identifier variable.
; Return Value(s):  True  - Data is waiting in the buffer. Safe to call TCPRecv() instantly.
;                   False - No data is available to read at this moment.
; =======================================================================================================================
Func __TCP_IsDataAvailable($hSocket)
	If IsArray($hSocket) Then $hSocket = $hSocket[0]                        ; Extract raw Win32 socket handle descriptor if AutoIt passed it as a tracking array
	$hSocket = Number($hSocket)
	If $hSocket <= 0 Then SetError(2, 0, False)                             ;@error=2: Invalid handle
	Local $tFD_SET = DllStructCreate("uint fd_count;handle fd_array")       ; Create a Win32 fd_set structure layout template
	DllStructSetData($tFD_SET, "fd_count", 1)                               ; struct fd_set { u_int fd_count; SOCKET fd_array[1]; }
	DllStructSetData($tFD_SET, "fd_array", $hSocket, 1)
	Local $tTimeVal = DllStructCreate("long tv_sec;long tv_usec")           ; Create an immediate-timeout timeval structure (0 seconds, 0 microseconds)
	DllStructSetData($tTimeVal, "tv_sec", 0)
	DllStructSetData($tTimeVal, "tv_usec", 0)
	Local $aRet = DllCall("ws2_32.dll", "int", "select", _                  ; Call the Winsock select API targeting readfds (the second parameter)
			"int", 0, _                                                     ;   nfds (ignored in Windows)
			"struct*", $tFD_SET, _                                          ;   readfds (checks if data is ready to read)
			"ptr", 0, _                                                     ;   writefds (omitted)
			"ptr", 0, _                                                     ;   exceptfds (omitted)
			"struct*", $tTimeVal)                                           ;   timeout structure pointer
	If @error Then Return SetError(3, 0, False)                             ;@error=3: DLL Call crashed
	If $aRet[0] < 0 Then                                                    ; If select returns a negative number, the socket itself has structural errors
		Local $aWSAErr = DllCall("ws2_32.dll", "int", "WSAGetLastError")
		Return SetError(1, $aWSAErr[0], False)                              ;@error=1: Dead socket, @extended=Winsock Error Code
	EndIf
	If $aRet[0] = 0 Then Return False                                       ; Healthy socket, no data available
	Local $tBuffer = DllStructCreate("byte")                                ; If select > 0, check if it's real data or a termination notification
	Local $aRecv = DllCall("ws2_32.dll", "int", "recv", _                   ; recv, PEEK, to check status
			"handle", $hSocket, _
			"struct*", $tBuffer, _
			"int", 1, _
			"int", 2) ; MSG_PEEK
	If @error Then Return SetError(3, 0, False)                             ;@error=3: DLL Call crashed
	If $aRecv[0] <= 0 Then                                                  ; If error state returned from PEEK
		Local $aWSAErr = DllCall("ws2_32.dll", "int", "WSAGetLastError")    ; WSAGetLastError:  0=clean close, 10057=not connected, 10054=reset
		Return SetError(1, $aWSAErr[0], False)                              ;@error=1: Disconnected, @extended=Winsock Error Code
	EndIf
	Return True                                                             ; Socket is 100% healthy and data is available
EndFunc   ;==>__TCP_IsDataAvailable



;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------




Func __viClassifyItem($sId)
	Local $sType = ""
	If StringInStr($sId, ",MSO") Or StringInStr($sId, ",DPO") Then
		$sType = "sc Oscilloscope"
	ElseIf StringInStr($sId, ",F4T") Or StringInStr($sId, ",F4T") Then
		$sType = "tc Chamber"
	ElseIf StringInStr($sId, ",5323") Or StringInStr($sId, ",5313") Then
		$sType = "fc Frequency Counter"
	ElseIf StringInStr($sId, ",N670") Or StringInStr($sId, ",E363") Then
		$sType = "dc DC Power Supply"
	EndIf
	Return $sType
EndFunc   ;==>__viClassifyItem



;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------


Func __viGTL(ByRef $oDev)                               ; send universal Go-To-Local command to release control of device to local user
	__viCmd($oDev, $VI_GTL)
EndFunc   ;==>__viGTL







;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;
; Test Equity F4T thermal chamber modbus TCP communication functions
;



Global $g_F4T_REGMAP[][2] = [ _             ; DataMap 1, 2.   1=32f, 2=16i*10
		[2782, 300], _                      ; 0=Temperature setpoint (32f,16i)
		[27586, 100], _                     ; 1=measured temperature (32f,16i)
		[16594, 2000], _                    ; 2=enable (on/off) (16i,16i)
		[2804, 103], _                      ; 3=heating power
		[2806, 107], _                      ; 4=cooling power
		[6730, 901], _                      ; 5=temperature units.  BitAnd(x,1) -> 1=C, 0=F
		[0, 0]]

Global Const $g_iF4Tsetpoint = 0            ; index in F4T REGMAP for the temperature setpoint
Global Const $g_iF4Ttemperature = 1         ; index in F4T REGMAP for the temperature measurement
Global Const $g_iF4Tenable = 2              ; index in F4T REGMAP for the enable (on/off)
Global Const $g_iF4Theat = 3                ; index for heating power
Global Const $g_iF4Tcool = 4                ; index for cooling power
Global Const $g_iF4Tunits = 5               ; index for units register




; -----------------------------
; -----------------------------
; -----------------------------
; -----------------------------
;
; F4T read/write temperature and enable state




Func __F4Ttemperature(ByRef $oDev)                              ; get chamber temperature measurement in C
	Return __F4TtoC($oDev, __F4Tread($oDev, $g_iF4Ttemperature))
EndFunc   ;==>__F4Ttemperature


Func __F4Tsetpoint(ByRef $oDev, $fValue = -1000)                ; get or set chamber temperature setpoint
	;ConsoleWrite("__F4Tsetpoint()" & @CRLF)
	If @NumParams > 1 Then Return __F4Twrite($oDev, $g_iF4Tsetpoint, ($oDev.Item('f4tUnits') = 0) ? __TemperatureCtoF($fValue) : $fValue)
	Return __F4TtoC($oDev, __F4Tread($oDev, $g_iF4Tsetpoint))
EndFunc   ;==>__F4Tsetpoint


Func __F4Tenable(ByRef $oDev, $bValue = False)                  ; get chamber on/off status, or turn on/off chamber
	If @NumParams > 1 Then Return __F4Twrite($oDev, $g_iF4Tenable, $bValue)
	Return __F4Tread($oDev, $g_iF4Tenable)
EndFunc   ;==>__F4Tenable


Func __F4Theat(ByRef $oDev)                                     ; read the current heating power
	Return __F4Tread($oDev, $g_iF4Theat)
EndFunc   ;==>__F4Theat


Func __F4Tcool(ByRef $oDev)                                     ; read the current cooling power
	Return __F4Tread($oDev, $g_iF4Tcool)
EndFunc   ;==>__F4Tcool



Func __F4TtoC(ByRef $oDev, $fT)                                 ; convert T to deg C if it is in F
	If Not __F4Tresolve($oDev) Then Return SetError(-1, 0, -1000)
	If $oDev.Item('f4tUnits') = 0 Then $fT = __TemperatureFtoC($fT)
	Return $fT
EndFunc   ;==>__F4TtoC





; -----------------------------
; -----------------------------
; -----------------------------
; -----------------------------
;
;
; F4T read/write holding registers




;			__F4Tread
; task:		read a register from F4T chamber
;			if dataMap=1 then read 32 bit float
;			else read 16 bit int and divide by 10
; in:		$iRegIndex = register indexed in $g_F4T_REGMAP (0=target, 1=temperature, 2=enable)
; out:		floating point number read from register, or 0/1 if regindex=2
Func __F4Tread(ByRef $oDev, $iRegIndex)
	;ConsoleWrite("__F4Tread() before __F4TResolve " & VarGetType($oDev) & @CRLF)
	If Not __F4Tresolve($oDev) Then Return SetError(-1, 0, -1000)
	;ConsoleWrite("__F4Tread() after __F4TResolve" & @CRLF)
	If $iRegIndex < 0 Or UBound($g_F4T_REGMAP, 1) <= $iRegIndex Then Return SetError(-2, 0, -1000)
	Local $iDataMap = $oDev.Item('f4tDataMap')
	Local $r
	;ConsoleWrite("__F4Tread()" & @CRLF)
	If $iDataMap = 1 And $iRegIndex <> 2 Then _
			Return __mbReadBl($oDev, "2f", $g_F4T_REGMAP[$iRegIndex][0])                    ; datamap 1, reading temperature or setpoint
	$r = __mbReadBl($oDev, "1i", $g_F4T_REGMAP[$iRegIndex][$iDataMap - 1])
	If $iRegIndex <> 2 Then Return $r / 10                                                  ; datamap 2, read 16bit int and divide by 10
	Return BitAND(Int($r), 1) = 1                                                           ; read enable state, datamap 1: 63=on / 62=off
	;                                                                                   	; enable state datamap 2: 1=on / 0=off
EndFunc   ;==>__F4Tread



;			__F4TreadBg
; task:		read a register from F4T chamber - run in background
;			if dataMap=1 then read 32 bit float
;			else read 16 bit int and divide by 10
; in:		$iRegIndex = register indexed in $g_F4T_REGMAP (0=target, 1=temperature, 2=enable)
;			$sVar = variable name to save the data into
; out:		floating point number read from register, or 0/1 if regindex=2
Func __F4TreadBg(ByRef $oDev, $iRegIndex, $sVar)
	If $sVar <> "" Then
		If StringLeft($sVar, 1) <> "$" Then $sVar = "$" & $sVar
		$sVar &= "="
	EndIf
	If Not __F4Tresolve($oDev) Then Return SetError(-1, 0, -1000)
	If $iRegIndex < 0 Or UBound($g_F4T_REGMAP, 1) <= $iRegIndex Then Return SetError(-2, 0, -1000)
	Local $iDataMap = $oDev.Item('f4tDataMap')
	If $iDataMap = 1 And $iRegIndex <> 2 Then _
			Return __mbRead($oDev, "2f", $g_F4T_REGMAP[$iRegIndex][0], 1000, $sVar)         ; datamap 1, reading temperature or setpoint
	Return __mbRead($oDev, "1i", $g_F4T_REGMAP[$iRegIndex][$iDataMap - 1], 1000, $sVar)     ; datamap 2 or datamap 1 reading enable state
EndFunc   ;==>__F4TreadBg

Func __F4TreadBgProcReply(ByRef $oDev, $iRegIndex, $nValue)                                 ; process received value of read register after being received
	Local $iDataMap = $oDev.Item('f4tDataMap')
	If $iDataMap = 1 And $iRegIndex <> 2 Then Return $nValue                                ; datamap 1 temperature register - no conversion needed
	If $iRegIndex <> 2 Then Return Int($nValue) / 10                                        ; datamap 2 temperature register - divide integer by 10 for 1 decimal place floating point number
	Return BitAND(Int($nValue), 1) = 1                                                      ; read enable state, datamap 1: 63=on / 62=off.  datamap 2: 1=on / 0=off
EndFunc   ;==>__F4TreadBgProcReply




;			__F4Twrite
; task:		write a register in the F4T chamber
;			if dataMap=1 then  32 bit float
;			else times 10 and store as 16 bit int
; in:		$iRegIndex = register index in $g_F4T_REGMAP (0=target, 1=temperature, 2=enable)
;			$fValue = floating point number to write
; out:		@error = nonzero if error
Func __F4Twrite(ByRef $oDev, $iRegIndex, $fValue)
	;ConsoleWrite("__F4Twrite() before __F4TResolve" & @CRLF)
	If Not __F4Tresolve($oDev) Then Return SetError(-1, 0, 0)
	If $iRegIndex < 0 Or UBound($g_F4T_REGMAP, 1) <= $iRegIndex Then Return SetError(-2, 0, 0)
	;ConsoleWrite("__F4Twrite() after __F4TResolve" & @CRLF)
	Local $iDataMap = $oDev.Item('f4tDataMap')
	If $iDataMap = 1 And $iRegIndex <> 2 Then _
			Return __mbWrite($oDev, "2f", $g_F4T_REGMAP[$iRegIndex][0], $fValue)            ; datamap 1: write 32bit float for temperature
	Local $iR = Int($fValue)                                                                ; datamap 2, enable state = 1/0
	If $iDataMap = 1 Then $iR = BitOR($iR, 62)                                              ; datamap 1, enable = 63/62
	If $iRegIndex <> 2 Then $iR = Int(10 * $fValue)                                         ; datamap 2: float times 10 writen into 16 bit int
	Return __mbWrite($oDev, "1i", $g_F4T_REGMAP[$iRegIndex][$iDataMap - 1], $iR)
EndFunc   ;==>__F4Twrite




; -----------------------------
; -----------------------------
; -----------------------------
; -----------------------------
;
; F4T open functions



; task:		resovle $oDev into an instrument handle that is prepared for modbus tcp comms with F4T thermal chamber
; in:		ip address or instrument handle
; out:		false if error, true if successful
;			$oDev pointing at instrument handle if possible
Func __F4Tresolve(ByRef $oDev)
	If Not __viResolveInstrument($oDev) Then Return False
	Local $iDataMap = Int($oDev.Item('f4tDataMap'))
	If $iDataMap < 1 Or 2 < $iDataMap Then __F4TgetDataMap($oDev)
	Local $iWordOrder = Int($oDev.Item('f4tWordOrder'))
	If $iWordOrder < 0 Or 1 < $iWordOrder Then __F4TgetWordOrder($oDev)
	Local $iUnits = Int($oDev.Item('f4tUnits'))
	If $iUnits < 0 Or 1 < $iUnits Then __F4TgetUnits($oDev)
	If $g_F4T_PrintResolv Then __ConsolePrintVars("__F4Tresolve, ", "wordOrder", $iWordOrder, "dataMap", $iDataMap, "units", $iUnits)
	Return True
EndFunc   ;==>__F4Tresolve



;			Determine which DataMap setting the F4T chamber has
; task:		read register 100 and look for a return of 0x8300 (error) datamap 1 does not have register 100, datamap 2 has register 100
;			if error or no response then assume dataMap 1
; in:		$oDev = session handle
; out:		DataMap:  1 (new) or 2 (legacy F4T)
Func __F4TgetDataMap(ByRef $oDev)
	If Not __viResolveInstrument($oDev) Then Return
	Local $t = __mbReadBl($oDev, "1i", 100)
	Local $iR = ((Int($t / 0x100) = 0x83) Or (@error) Or ($t = 0)) ? 1 : 2
	$oDev.Item('f4tDataMap') = $iR
	Return $iR
EndFunc   ;==>__F4TgetDataMap



;			Determine which modbus word order setting the F4T chamber has
; task:		read16 register 6736 (ethernet) or 14092 (modbus).  1331 = low-high, 1330 = high-low
; in:		$oDev = session handle
; out:		word order 0 = low-high, 1 = high-low
Func __F4TgetWordOrder(ByRef $oDev)
	If Not __viResolveInstrument($oDev) Then Return SetError(-1, 0, 0)
	Local $iWordOrder = 1                                                   ; default to high-low word order if datamap = 2 as datamap 2 does not use 32-bit numbers
	If $oDev.Item('f4tDataMap') = 1 Then
		Local $iR = __mbReadBl($oDev, "1i", 14092)
		If BitOR($iR, 1) <> 1331 Then $iR = __mbReadBl($oDev, "1i", 6736)
		If BitOR($iR, 1) = 1331 Then $iWordOrder = Int(Not BitAND($iR, 1))
	EndIf
	$oDev.Item('f4tWordOrder') = $iWordOrder
	Return $iWordOrder
EndFunc   ;==>__F4TgetWordOrder



Func __F4TgetUnits(ByRef $oDev)                    ; returns 1 for C, 0 for F
	If Not __viResolveInstrument($oDev) Then Return SetError(-1, 0, 1)
	Local $u = 1
	If $oDev.Item('f4tDataMap') = 1 Then
		$u = (Int(__mbReadBl($oDev, "1i", 6730), 1) = 15)
	Else
		$u = Int(BitAND(__mbReadBl($oDev, "1i", 901), 1))
	EndIf
	$oDev.Item('f4tUnits') = $u
	Return $u
EndFunc   ;==>__F4TgetUnits




Func __F4TgetID(ByRef $oDev, $iTimeoutMS = 1000)
	; Manufacturer, Model, Serial Number, Firmware Level
	If Not __F4Tresolve($oDev) Then Return
	Local $sMfg, $sModel, $iSN, $iRel
	If $oDev.Item('f4tDataMap') = 1 Then
		$iSN = __mbReadBl($oDev, "2i", 12, $iTimeoutMS)
		If @error Or $iSN = 0 Then Return SetError(@error, @extended, "")
		$iRel = __mbReadBl($oDev, "2i", 3, $iTimeoutMS)
		If @error Or $iRel = 0 Then Return SetError(@error, @extended, "")
		$sMfg = __mbReadBl($oDev, "30s", 46, $iTimeoutMS)
		If @error Or $sMfg = "" Then Return SetError(@error, @extended, "")
		$sMfg = StringStripWS($sMfg, 3)
		$sModel = __mbReadBl($oDev, "15s", 16, $iTimeoutMS)
		If @error Then Return SetError(@error, @extended, "")
		$sModel = StringStripWS($sModel, 3)
	Else
		$sMfg = __mbReadBl($oDev, "1i", 3, $iTimeoutMS)
		If @error Or $sMfg = 0 Then Return SetError(@error, @extended, "")
		$sModel = __mbReadBl($oDev, "1i", 0, $iTimeoutMS)
		If @error Or $sModel = 0 Then Return SetError(@error, @extended, "")
		$iSN = "" ; __mbReadBl($oDev, "", 36)
		$iRel = StringFormat("%02i.%05i", __mbReadBl($oDev, "1i", 4, $iTimeoutMS), __mbReadBl($oDev, "1i", 30, $iTimeoutMS))
		If @error Then Return SetError(@error, @extended, "")
	EndIf        ;
	Return $sMfg & "," & $sModel & "," & $iSN & "," & $iRel
EndFunc   ;==>__F4TgetID






; -----------------------------
; -----------------------------
; -----------------------------
; -----------------------------
;
;

;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------




