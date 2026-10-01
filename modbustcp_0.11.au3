
;TCPNameToIP("127.0.0.1")                                ; ensure TCP has been initialized
;If @error = 10093 Then TCPStartup()
;Func __mbExit()                                         ; call this before exiting main script
;	TCPShutdown()                                       ; close TCP resources
;EndFunc   ;==>__mbExit

#AutoIt3Wrapper_UseX64=Y

#include-once

#include <AutoItConstants.au3>



;--------------------------------------------
; ModBus TCP functions
;
; Test Equity F4T thermal chamber modbus functions
;

; modbus session handle object (array)
Global Const $_MBipAddr = 0     ; [0] = IP address
Global Const $_MBipPort = 1     ; [1] = port
Global Const $_MBsock = 2       ; [2] = socket handle
Global Const $_MBstate = 3      ; [3] = session state (0=closed, 1=open)
Global Const $_MBtranID = 4     ; [4] = transaction ID (a rolling number for each new transaction)
Global Const $_MBdataMap = 5    ; [5] = data map (1=current, 2=legacy)
Global Const $_MBwordOrder = 6  ; [6] = modbus word order (0 = low-high, 1 = high-low)
Global Const $_MBclose = 7        ; [7] = close flag - close session after operation if this flag is set
Global Const $_MBsize = 8       ; number of items in this array



OnAutoItExitRegister("__mbExit")                        ; cleanup on exit
Func __mbExit()                                         ; call this before exiting main script
	TCPShutdown()                                       ; close TCP resources
EndFunc   ;==>__mbExit





; --------------------------------------------------------------
; modbus begin, end, read (register), write (register) functions



;			update global flag when visa communications fail
Func __mbFellOffline()
	$g_bCommValid = 0
EndFunc   ;==>__mbFellOffline



;			__mbBegin
; task:		start a modbus tcp transaction with a network device
; in:		$mbSession = ip address [: port number]
;			$mbSession can be an already existing session handle, in which case it attempts to ensure it is open
; out:		$mbSession will be replaced with an visa session handle (array)
;			return 1 if successful, 0 if failed
Func __mbBegin(ByRef $mbSession)
	$g_bCommValid = 1
	If IsArray($mbSession) Then Return __mbConfirmOpen($mbSession)    ; if $mbSession is an array, then assume it is an existing session handle
	If __mbOpen($mbSession, 1) Then Return 1
	__mbFellOffline()
	Return SetError(-1, 0, 0)
EndFunc   ;==>__mbBegin



;			close a modbus session if the flag is set for a one shot operation
Func __mbEnd(ByRef $mbSession)
	If Not IsArray($mbSession) Then Return
	If Not $mbSession[$_MBclose] Then Return
	__mbClose($mbSession) ; close session
	__mbBreakHandle($mbSession)
EndFunc   ;==>__mbEnd




;				__mbRead
; task:			read a register
; in:			$mbSession = modbus session handle
;				$iRegAddr = register address
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
;				$iTimeoutMS = timeout in ms
; out:			0 if successful or @error
Func __mbRead(ByRef $mbSession, $iRegAddr, $sDataType = "32f", $iTimeoutMS = 3000)
	Switch $sDataType
		Case "16i"
			Return __mbReadInt16($mbSession, $iRegAddr, $iTimeoutMS)
		Case "16f"
			Return __mbReadFloat16($mbSession, $iRegAddr, $iTimeoutMS)
		Case "32i"
			Return __mbReadInt32($mbSession, $iRegAddr, $iTimeoutMS)
		Case "32f"
			Return __mbReadFloat32($mbSession, $iRegAddr, $iTimeoutMS)
	EndSwitch
EndFunc   ;==>__mbRead



;				__mbWrite
; task:			write a register
; in:			$mbSession = modbus session handle
;				$iRegAddr = register address
;				$nValue = value to write to register
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
; out:			0 if successful or @error
Func __mbWrite(ByRef $mbSession, $iRegAddr, $nValue, $sDataType = "32f")
	Switch $sDataType
		Case "16i"
			Return __mbWriteInt16($mbSession, $iRegAddr, $nValue)
		Case "16f"
			Return __mbWriteFloat16($mbSession, $iRegAddr, $nValue)
		Case "32i"
			Return __mbWriteInt32($mbSession, $iRegAddr, $nValue)
		Case "32f"
			Return __mbWriteFloat32($mbSession, $iRegAddr, $nValue)
	EndSwitch
EndFunc   ;==>__mbWrite



;				__mbWriteVerify
; task:			write a register, then read back the register to verify
;				retry as needed
; in:			$mbSession = modbus session handle
;				$iRegAddr = register address
;				$nValue = value to write to register
;				$sDataType = 16 or 32 bit, integer or float = [ "16i" "16f" "32i" "32f" ]
;				$iTimeoutMS = timeout in ms
; out:			1 if successful or 0 and @error
Func __mbWriteVerify(ByRef $mbSession, $iRegAddr, $nValue, $sDataType = "32f", $iTimeoutMS = 3000)
	If Not __mbConfirmOpen($mbSession) Then Return SetError(1, 0, 0)
	Local $hTimer = TimerInit()
	Local $nRead
	While True
		;ConsoleWrite("mb reg write out [" & $iRegAddr & "] = " & $nValue & @CRLF)
		__mbWrite($mbSession, $iRegAddr, $nValue, $sDataType)
		If @error Then Return SetError(1, @error, 0)
		Sleep(200)
		$nRead = __mbRead($mbSession, $iRegAddr, $sDataType, $iTimeoutMS)
		;ConsoleWrite("mb reg write in  [" & $iRegAddr & "] = " & $nRead & @CRLF)
		If @error Then Return SetError(2, @error, 0)
		If Round($nValue, 7) = Round($nRead, 7) Then ExitLoop
		Sleep(500)
		If TimerDiff($hTimer) > $iTimeoutMS Then Return SetError(3, 0, 0)
	WEnd
	Return 1
EndFunc   ;==>__mbWriteVerify









;			__mbMakeHandle
; task:		if needed, convert $mbSession from an ip address to a session array handle
; in:		$mbSession = session handle or ip address/port
;			ip address string format: IP[:port]
Func __mbMakeHandle(ByRef $mbSession, $bClose = 0)
	If IsArray($mbSession) Then Return
	Local $a1 = __mbParseIPaddress($mbSession, "")                               ; parse IP address for port number
	Local $ipPort = $a1[1]
	$ipAddr = $a1[0]
	If $ipPort = "" Then $ipPort = 502

	Local $aSession[$_MBsize]
	$aSession[$_MBipAddr] = $ipAddr                                             ; IP address
	$aSession[$_MBipPort] = $ipPort                                             ; IP port
	$aSession[$_MBsock] = 0                                                     ; session handle
	$aSession[$_MBstate] = 0                                                    ; connection state
	$aSession[$_MBtranID] = 0x100                                               ; transaction ID
	$aSession[$_MBdataMap] = -1                                                 ; datamap not yet determined
	$aSession[$_MBwordOrder] = 0                                                ; word order
	$aSession[$_MBclose] = $bClose                                              ; close when finished flag
	$mbSession = $aSession
EndFunc   ;==>__mbMakeHandle



;			__mbBreakHandle
; task:		convert session handle back into ip adddress string
Func __mbBreakHandle(ByRef $mbSession)
	If Not IsArray($mbSession) Then Return
	Local $sP = $mbSession[$_MBipPort]                ; convert $viSession back into an ip address string
	Local $sIP = $mbSession[$_MBipAddr]
	If $sP = 502 Then $sP = ""
	If Not $sP = "" Then $sP = ":" & $sP
	$mbSession = $sIP & $sP
EndFunc   ;==>__mbBreakHandle




;			__mbOpen
; task:		start a TCP socket session with a modbus device
; in:		$mbSession = session handle variable to hold the information about the session, or a string for the ip address
; 			$bClose = 1 to close with __mbEnd or 0 to keep open
; out:		1 if successful, 0 if error
Func __mbOpen(ByRef $mbSession, $bClose = 0)
	If Not IsArray($mbSession) Then __mbMakeHandle($mbSession, $bClose)

	If $mbSession[$_MBstate] Then                                                ; if previous session open, then close it
		__mbClose($mbSession)
		Sleep(50)
		$mbSession[$_MBstate] = 0
	EndIf
	$mbSession[$_MBsock] = 0

	Local $hSocket = TCPConnect($mbSession[$_MBipAddr], $mbSession[$_MBipPort])
	If @error = 10093 Then
		TCPStartup()
		Sleep(100)
		$hSocket = TCPConnect($mbSession[$_MBipAddr], $mbSession[$_MBipPort])
	EndIf
	;ConsoleWrite("tcp connect to " & $mbSession[$_MBipAddr] & ":" & $mbSession[$_MBipPort] & ", @error=" & @error & @CRLF)
	If $hSocket = -1 Or @error Then Return SetError(-1, @error, 0)

	$mbSession[$_MBsock] = $hSocket
	$mbSession[$_MBstate] = 1            ; successfully connected the session
	Return 1
EndFunc   ;==>__mbOpen



;			__mbSessionSanityCheck
; task:		sanity check the $mbSession parameters
Func __mbSessionSanityCheck(ByRef $mbSession)
	If $mbSession[$_MBipPort] = "" Then $mbSession[$_MBipPort] = 502
	$mbSession[$_MBipPort] = Number($mbSession[$_MBipPort])
	If $mbSession[$_MBipPort] = 0 Then $mbSession[$_MBipPort] = 502
	$mbSession[$_MBstate] = Number($mbSession[$_MBstate])
	If $mbSession[$_MBtranID] = "" Then $mbSession[$_MBtranID] = 0x100
	If $mbSession[$_MBdataMap] = "" Then $mbSession[$_MBdataMap] = -1
	If $mbSession[$_MBwordOrder] = "" Then $mbSession[$_MBwordOrder] = 0
EndFunc   ;==>__mbSessionSanityCheck



;			__mbConfirmOpen
; task:		confirm if $mbSession is connected/open
; in:		$mbSession = visa session handle
; out:		1 if it is open
;			0 if it is not open and we could not reopen it - error
Func __mbConfirmOpen(ByRef $mbSession)                                ; check if session is open, reopen if no
	If Number($mbSession[$_MBstate]) Then Return 1                   ; if session is open, then return ok
	__mbSessionSanityCheck($mbSession)                                ; otherwise attempt to reopen it
	__mbOpen($mbSession)
	Return $mbSession[$_MBstate]
EndFunc   ;==>__mbConfirmOpen



;			__mbClose
; task:		close modbus tcp socket
; in:		$mbSession = session handle
; out:		none
Func __mbClose(ByRef $mbSession)
	If IsArray($mbSession) Then
		If $mbSession[$_MBsock] = 0 Then Return
		TCPCloseSocket($mbSession[$_MBsock])
		If @error Then Return SetError(@error, 0, @error)
		$mbSession[$_MBstate] = 0
		$mbSession[$_MBsock] = 0
	Else
		TCPCloseSocket($mbSession)
		If @error Then Return SetError(@error, 0, @error)
	EndIf
EndFunc   ;==>__mbClose




;			_mbParseIPaddress
; task:		parse IP address and port number from input
;			IP:Port
; in:		$ipAddr = IP address and Port number separated by a colon :
;			$defPort = default port to use if no port number found in $ipAddr
; out:		[0] = IP address
;			[1] = port number or default if not specified
Func __mbParseIPaddress($ipAddr, $defPort = 502)
	Local $aIP[2]
	Local $iPos = StringInStr($ipAddr, ":")
	If $iPos Then
		$aIP[0] = StringLeft($ipAddr, $iPos - 1)
		$aIP[1] = StringMid($ipAddr, $iPos + 1)
	Else
		$aIP[0] = $ipAddr
		$aIP[1] = $defPort
	EndIf
	Return $aIP
EndFunc   ;==>__mbParseIPaddress






; --- Modbus TCP Frame (ADU) ---
;      	Bytes 0-1: 		Transaction ID (auto increment for each new transaction)
;      	Bytes 2-3: 		Protocol ID (0x0000 = Modbus)
;      	Bytes 4-5: 		Remaining Length (number of bytes, 0x0006 bytes follow)
;      	Byte  6:   		Unit Identifier / Device Address (0x01)
;      	Byte  7:   		Function Code (0x03 = Read Holding Registers, 0x06 = single reg write, 0x10 = Write multiple Holding Registers)
;      	Bytes 8-9: 		Starting Reference Register Address (Big-Endian)
;		Bytes 10-11:  	Quantity - Number of 16-bit Registers to Read/write  (0x0001 = 2 bytes for 16-bit, 2 = 4 bytes for 32 bit)
;	   	Bytes 12...:  	Data Payload

;			__mbMakeTCPframe
; task:		build a modbus tcp frame
; in:		$mbSession = session handle
;			$bFunc = function 1=write, 0=read
;			$iRegisterAddress = register address (Big-Endian)
;			$sData = (read) number of registers to read
;				 	 (write) hex string of data payload to write
; out:		hex string of the frame to send in the tcp socket
Func __mbMakeTCPframe(ByRef $mbSession, $bFunc, $iRegisterAddress, $sData)
	Local $iTrans = $mbSession[$_MBtranID]
	$iTrans = Mod($iTrans + 1, 0xFFFF)                                      ; auto increment transaction id
	$mbSession[$_MBtranID] = $iTrans
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
EndFunc   ;==>__mbMakeTCPframe



;			__mbReadTCPframe
; task:		extract the payload data from a modbus tcp frame
; in:		$dFrame = modbus frame data, received from TCPRecv command
; out:		binary data payload data send in the frame.  all header information stripped off
Func __mbReadTCPframe($dFrame)
	Local $iCount = Int(BinaryMid($dFrame, 9, 1))    ; number of bytes of data in the payload
	If ($iCount - 9) > BinaryLen($dFrame) Then $iCount = BinaryLen($dFrame) - 9
	If $iCount <= 0 Then Return ""
	Return BinaryMid($dFrame, 10, $iCount)
EndFunc   ;==>__mbReadTCPframe



;				__mbTCPRecv
; task:			read a modbus response from TCP socket
; in:			$hSocket = socket handle
;				$iCount = minimum number of bytes to wait for
;				$iTimeoutMS = timeout in MS (default 2000)
; out:			binary data received from socket
Func __mbTCPRecv($hSocket, $iCount, $iTimeoutMS = 2000)
	Local $hTimer = TimerInit()
	Local $bBufAcc = Binary("")
	Local $bResponse
	While True
		;$bResponse = Binary($bResponse & TCPRecv($hSocket, 64, 1))
		$bResponse = TCPRecv($hSocket, 64, 1)
		$bBufAcc = Binary($bBufAcc & $bResponse)
		If BinaryLen($bBufAcc) >= $iCount Then ExitLoop
		If TimerDiff($hTimer) > $iTimeoutMS Then
			;ConsoleWrite("__mbTCPRecv, timeout, error=" & @error & @CRLF)
			Return SetError(1, 1, $bBufAcc)
		EndIf
		Sleep(5)
	WEnd
	;ConsoleWrite("__mbTCPRecv, response= 0x" & Hex($bResponse) & @CRLF)
	Return $bBufAcc
EndFunc   ;==>__mbTCPRecv



; ==============================================================================
; Task: READ 16-bit register
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
; out:			16 bit number from the register
Func __mbReadReg16(ByRef $mbSession, $iRegisterAddress, $iTimeoutMS = 2000)
	Local $sPayload = __mbMakeTCPframe($mbSession, 0, $iRegisterAddress, 1)                  ; build request frame (for one 16 bit register)
	;ConsoleWrite("[DEBUG OUT Read16] " & $sPayload & @CRLF)
	TCPSend($mbSession[$_MBsock], Binary($sPayload))                                         ; send request
	Local $bResponse = __mbTCPRecv($mbSession[$_MBsock], 11, $iTimeoutMS)                    ; receive response, expect at least 11 bytes
	;ConsoleWrite("[DEBUG IN  Read16] 0x" & Hex($bResponse) & " " & BinaryLen($bResponse) & " error=" & @error & @CRLF)
	If @error Then Return SetError(@error, @extended, 0)                                    ; if timeout then error
	If BinaryLen($bResponse) < 11 Then Return SetError(1, 1, -1)                    ;
	;ConsoleWrite("[DEBUG IN  Read16] 0x" & Hex($bResponse) & @CRLF)
	$bResponse = __mbReadTCPframe($bResponse)                                               ; strip tcp frame header
	Local $iB1 = Int(BinaryMid($bResponse, 1, 1))                                           ; extract register value from response
	Local $iB2 = Int(BinaryMid($bResponse, 2, 1))
	Local $dwRaw16 = ($iB1 * 256) + $iB2
	Return Number($dwRaw16)
EndFunc   ;==>__mbReadReg16



; ==============================================================================
; Task: WRITE a 16 bit register
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
;				$iValue = 16 bit number to write to the register
; out:			0 if successful, otherwise -1 and @error
Func __mbWriteReg16(ByRef $mbSession, $iRegisterAddress, $iValue, $iTimeoutMS = 2000)
	;ConsoleWrite("__mbWriteReg16($aSes, $iRefAddr=" & $iRegisterAddress & ", value=" & Hex($iValue,4) & ")  error=" & @error & @CRLF)
	Local $iB1 = Mod(Int($iValue / 256), 256)
	Local $iB2 = Mod($iValue, 256)
	Local $sPayload = __mbMakeTCPframe($mbSession, 1, $iRegisterAddress, Hex($iB1, 2) & Hex($iB2, 2))    ; build request frame to write
	;ConsoleWrite("[DEBUG OUT Write16] " & $sPayload & " error=" & @error & @CRLF)
	TCPSend($mbSession[$_MBsock], Binary($sPayload))                                                     ; send request
	;If @error Then ConsoleWrite("TCPSend error " & @error & @CRLF)
	Local $bResponse = __mbTCPRecv($mbSession[$_MBsock], 12, $iTimeoutMS)                                ; receive response, expect at least 12 bytes
	;ConsoleWrite("[DEBUG IN  Write16] 0x" & Hex($bResponse) & " error=" & @error & @CRLF)
	If @error Then Return SetError(@error, 0, -1)                                                        ; if timeout then error
	If BinaryLen($bResponse) < 12 Then Return SetError(1, 1, -1)                    ;
	Return 0                                                                                            ; return ok, no errors
EndFunc   ;==>__mbWriteReg16




; ==============================================================================
; Task: READ 32-bit register
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
; out:			32 bit number from register
Func __mbReadReg32(ByRef $mbSession, $iRegisterAddress, $iTimeoutMS = 2000)
	Local $sPayload = __mbMakeTCPframe($mbSession, 0, $iRegisterAddress, 2)          ; build request frame (for one 16 bit register)
	;ConsoleWrite("[DEBUG OUT Read32] " & $sPayload & @CRLF)
	TCPSend($mbSession[$_MBsock], Binary($sPayload))                                 ; send request
	Local $bResponse = __mbTCPRecv($mbSession[$_MBsock], 13, $iTimeoutMS)            ; receive response, expect at least 13 bytes
	If @error Then Return SetError(@error, 0, 0)                                    ; if timeout then error
	If BinaryLen($bResponse) < 12 Then Return SetError(1, 1, -1)                       ;
	;ConsoleWrite("[DEBUG IN  Read32] 0x" & Hex($bResponse) & @CRLF)
	$bResponse = __mbReadTCPframe($bResponse)                                       ; strip tcp frame header
	;ConsoleWrite("[DEBUG IN  Read32] 0x" & Hex($bResponse) & @CRLF)
	Local $iB1 = Int(BinaryMid($bResponse, 1, 1))                                   ; extract register value from response
	Local $iB2 = Int(BinaryMid($bResponse, 2, 1))
	Local $iB3 = Int(BinaryMid($bResponse, 3, 1))
	Local $iB4 = Int(BinaryMid($bResponse, 4, 1))
	Local $dwRaw32
	If $mbSession[$_MBwordOrder] Then
		$dwRaw32 = ($iB1 * 16777216) + ($iB2 * 65536) + ($iB3 * 256) + $iB4         ; word order: high low
	Else
		$dwRaw32 = ($iB3 * 16777216) + ($iB4 * 65536) + ($iB1 * 256) + $iB2         ; word order: low high (default)
	EndIf
	Return Number($dwRaw32)
EndFunc   ;==>__mbReadReg32



; ==============================================================================
; Task: WRITE a 32 bit register
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
;				$dw32 = 32 bit number to write to the register
; out:			0 if successful, otherwise -1 @error
Func __mbWriteReg32(ByRef $mbSession, $iRegisterAddress, $dw32, $iTimeoutMS = 2000)
	Local $iB1 = Mod(Int(Abs($dw32) / 0x1000000), 256) + (($dw32 < 0) ? 0x80 : 0)
	Local $iB2 = Mod(Int(Abs($dw32) / 0x10000), 256)
	Local $iB3 = Mod(Int(Abs($dw32) / 0x100), 256)
	Local $iB4 = Mod(Abs($dw32), 256)
	Local $sHex = ""
	If $mbSession[$_MBwordOrder] Then
		$sHex = Hex($iB1, 2) & Hex($iB2, 2) & Hex($iB3, 2) & Hex($iB4, 2)           ; word order: high low
	Else
		$sHex = Hex($iB3, 2) & Hex($iB4, 2) & Hex($iB1, 2) & Hex($iB2, 2)           ; word order: low high
	EndIf
	;ConsoleWrite("[DEBUG OUT Write32] " & $sHex & @CRLF)
	Local $sPayload = __mbMakeTCPframe($mbSession, 1, $iRegisterAddress, $sHex)      ; build request frame to write
	;ConsoleWrite("[DEBUG OUT Write32] " & $sPayload & @CRLF)
	TCPSend($mbSession[$_MBsock], Binary($sPayload))                                 ; send request
	Local $bResponse = __mbTCPRecv($mbSession[$_MBsock], 12, $iTimeoutMS)            ; receive response, expect at least 12 bytes
	If @error Then Return SetError(@error, @extended, -1)                           ; if timeout then error
	If BinaryLen($bResponse) < 12 Then Return SetError(1, 1, -1)                       ;
	;ConsoleWrite("[DEBUG IN  Write32] 0x" & Hex($bResponse) & @CRLF)
	Return 0                                                                        ; return ok, no errors
EndFunc   ;==>__mbWriteReg32



; ==============================================================================
; Task: READ a 16 bit integer
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
Func __mbReadInt16(ByRef $mbSession, $iRegisterAddress, $iTimeoutMS = 2000)
	Return __mbReadReg16($mbSession, $iRegisterAddress, $iTimeoutMS)
EndFunc   ;==>__mbReadInt16



; ==============================================================================
; Task: READ a 32 bit integer
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
Func __mbReadInt32(ByRef $mbSession, $iRegisterAddress, $iTimeoutMS = 2000)
	Return __mbReadReg32($mbSession, $iRegisterAddress, $iTimeoutMS)
EndFunc   ;==>__mbReadInt32



; ==============================================================================
; Task: WRITE a 16 bit integer
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
;				$iValue = integer to write
Func __mbWriteInt16(ByRef $mbSession, $iRegisterAddress, $iValue, $iTimeoutMS = 2000)
	Return __mbWriteReg16($mbSession, $iRegisterAddress, $iValue, $iTimeoutMS)
EndFunc   ;==>__mbWriteInt16



; ==============================================================================
; Task: WRITE a 32 bit integer
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
;				$iValue = integer to write
Func __mbWriteInt32(ByRef $mbSession, $iRegisterAddress, $iValue, $iTimeoutMS = 2000)
	Return __mbWriteReg32($mbSession, $iRegisterAddress, $iValue, $iTimeoutMS)
EndFunc   ;==>__mbWriteInt32



;				Dw16toFloat16
; task:			convert 16 bit binary data into a 16 bit floating point number
Func __mbDw16toFloat16($dwRaw16)
	Local $iSign = (BitAND($dwRaw16, 0x8000) = 0) ? 1 : -1
	Local $iExponent = BitShift(BitAND($dwRaw16, 0x7C00), 10)
	Local $iMantissa = BitAND($dwRaw16, 0x03FF)

	If $iExponent = 0 And $iMantissa = 0 Then Return 0.0
	If $iExponent = 255 Then
		If $iMantissa = 0 Then Return ($iSign / 0)            ; return +/- infinity
		Return 0 / 0                                          ; else return NaN
	EndIf

	$iExponent -= 15            ; remove bias component of exponent
	$iMantissa = 1.0 + $iMantissa / 0x0400
	Return Number($iSign * $iMantissa * (2 ^ $iExponent))
EndFunc   ;==>__mbDw16toFloat16



;				Float16toDw16
; task:			convert a floating point number into a 16 bit binary data (stored as int16)
Func __mbFloat16toDw16($nValue)
	Local $iSign = ($nValue < 0) ? 1 : 0
	Local $nAbsVal = Abs($nValue)
	Local $iExponent = 0
	If $nAbsVal = 0 Then Return 0
	$iExponent = Floor(Log($nAbsVal) / Log(2))
	Local $nMantissa = ($nAbsVal / (2 ^ $iExponent)) - 1
	Local $iMantissaInt = Round($nMantissa * 0x0400)
	Local $dwRaw16 = ($iSign * 0x8000) + (BitAND($iExponent + 15, 0x1F) * 0x0400) + BitAND($iMantissaInt, 0x03FF)
	Return Number($dwRaw16)
EndFunc   ;==>__mbFloat16toDw16



; ==============================================================================
; Task: READ a 16 bit float
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
; out:			16 bit float
Func __mbReadFloat16(ByRef $mbSession, $iRegisterAddress, $iTimeoutMS = 2000)
	Local $dw = __mbReadReg16($mbSession, $iRegisterAddress, $iTimeoutMS)
	;ConsoleWrite("$dw = 0x" & Hex($dw, 8) & @CRLF)
	If @error Then Return SetError(@error, @extended, __mbDw16toFloat16($dw))
	Return __mbDw16toFloat16($dw)
EndFunc   ;==>__mbReadFloat16



; ==============================================================================
; Task: WRITE a 16 bit float
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
;				$nValue = 16 bit float to write
; out:			1 if successful, 0 if not
Func __mbWriteFloat16(ByRef $mbSession, $iRegisterAddress, $nValue, $iTimeoutMS = 2000)
	Local $dw16 = __mbFloat16toDw16($nValue)
	Return __mbWriteReg16($mbSession, $iRegisterAddress, $dw16, $iTimeoutMS)
EndFunc   ;==>__mbWriteFloat16



;				Dw32toFloat32
; task:			convert 32 bit binary data into a 32 bit floating point number
Func __mbDw32toFloat32($dwRaw32)
	Local $iSign = (BitAND($dwRaw32, 0x80000000) = 0) ? 1 : -1
	Local $iExponent = BitShift(BitAND($dwRaw32, 0x7F800000), 23)
	Local $iMantissa = BitAND($dwRaw32, 0x007FFFFF)

	If $iExponent = 0 And $iMantissa = 0 Then Return 0.0
	If $iExponent = 255 Then
		If $iMantissa = 0 Then Return ($iSign / 0)            ; return +/- infinity
		Return 0 / 0                                          ; else return NaN
	EndIf

	$iExponent -= 127            ; remove bias component of exponent
	$iMantissa = 1.0 + $iMantissa / 0x00800000
	Return Number($iSign * $iMantissa * (2 ^ $iExponent))
EndFunc   ;==>__mbDw32toFloat32



;				Float32toDw32
; task:			convert a floating point number into a 32 bit binary data (stored as int32)
Func __mbFloat32toDw32($nValue)
	Local $iSign = ($nValue < 0) ? 1 : 0
	Local $nAbsVal = Abs($nValue)
	Local $iExponent = 0
	If $nAbsVal = 0 Then Return 0
	$iExponent = Floor(Log($nAbsVal) / Log(2))
	Local $nMantissa = ($nAbsVal / (2 ^ $iExponent)) - 1
	Local $iMantissaInt = Round($nMantissa * 0x800000)
	Local $dwRaw32 = ($iSign * 0x80000000) + (BitAND($iExponent + 127, 0xFF) * 0x800000) + BitAND($iMantissaInt, 0x007FFFFF)
	Return Number($dwRaw32)
EndFunc   ;==>__mbFloat32toDw32



; ==============================================================================
; Task: READ a 32 bit float
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
; out:			32 bit float
Func __mbReadFloat32(ByRef $mbSession, $iRegisterAddress, $iTimeoutMS = 2000)
	Local $dw = __mbReadReg32($mbSession, $iRegisterAddress, $iTimeoutMS)
	;ConsoleWrite("$dw = 0x" & Hex($dw, 8) & @CRLF)
	If @error Then Return SetError(@error, @extended, __mbDw32toFloat32($dw))
	Return __mbDw32toFloat32($dw)
EndFunc   ;==>__mbReadFloat32



; ==============================================================================
; Task: WRITE a 32 bit float
; ==============================================================================
; in:			$mbSession = session handle
;				$iRegisterAddress = register address
;				$nValue = 32 bit float to write
; out:			1 if successful, 0 if not
Func __mbWriteFloat32(ByRef $mbSession, $iRegisterAddress, $nValue, $iTimeoutMS = 2000)
	Local $dw32 = __mbFloat32toDw32($nValue)
	;ConsoleWrite("$dw = 0x" & Hex($dw32, 8) & @CRLF)
	Return __mbWriteReg32($mbSession, $iRegisterAddress, $dw32, $iTimeoutMS)
EndFunc   ;==>__mbWriteFloat32

