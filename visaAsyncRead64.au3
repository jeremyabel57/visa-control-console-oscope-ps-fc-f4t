#AutoIt3Wrapper_UseX64=y
#include <StructureConstants.au3>

; --- Core Initialization ---
Local $hDll = DllOpen("visa32.dll")
Local Const $VI_EVENT_IO_COMPLETION = 0x3FFF2041
Local Const $VI_QUEUE = 2
Local Const $VI_NULL = 0
Local Const $iMaxTimeoutMs = 5000 ; Individual timeout threshold (5 seconds)
Local Const $iMaxReadBytes = 4096

; Instantiate our Dictionary Object to track instrument tracking-states
Local $oInstrumentMap = ObjCreate("Scripting.Dictionary")

; --- Simulating Instrument Sessions ---
; Replace these values with your actual initialized 64-bit session handles
Local $aActiveSessions = [0x1111222233334444, 0x5555666677778888, 0x9999AAAABBBBCCCC]

; --- Phase 1: Trigger Async Calls on All Instruments ---
For $hSession In $aActiveSessions
	; 1. Enable completion event queuing for this specific session
	DllCall($hDll, "long", "viEnableEvent", "uint64", $hSession, "uint", $VI_EVENT_IO_COMPLETION, "ushort", $VI_QUEUE, "uint64", $VI_NULL)

	; 2. Allocate a unique dedicated memory buffer structure for this instrument
	Local $tBuffer = DllStructCreate("char[" & $iMaxReadBytes & "]")

	; 3. Fire the non-blocking read operation
	Local $aAsyncCall = DllCall($hDll, "long", "viReadAsync", _
			"uint64", $hSession, _
			"ptr", DllStructGetPtr($tBuffer), _
			"uint", $iMaxReadBytes, _
			"uint64*", 0) ; Receives the Job ID

	Local $status = $aAsyncCall
	Local $iJobId = $aAsyncCall

	If $status >= 0 Then
		ConsoleWrite("Session [0x" & Hex($hSession) & "]: Async read started successfully. Job ID: " & $iJobId & @CRLF)

		; 4. Pack tracking metadata into a sub-dictionary object for clean referencing
		Local $oMetadata = ObjCreate("Scripting.Dictionary")
		$oMetadata.Item("JobId") = $iJobId
		$oMetadata.Item("Buffer") = $tBuffer
		$oMetadata.Item("Timer") = TimerInit() ; Individual start clock

		; Save the metadata using the unique Session Handle as the key
		$oInstrumentMap.Item(String($hSession)) = $oMetadata
	Else
		ConsoleWrite("Session [0x" & Hex($hSession) & "]: Failed to initiate read. Error: 0x" & Hex($status) & @CRLF)
	EndIf
Next

; --- Phase 2: Single Unified Multi-Polling Loop ---
ConsoleWrite(@CRLF & "Entering background tracking polling loop..." & @CRLF)

While $oInstrumentMap.Count > 0
	; Extract array of all currently active session handle string keys
	Local $aKeys = $oInstrumentMap.Keys

	For $sSessionKey In $aKeys
		Local $hSession = UInt64($sSessionKey)
		Local $oMeta = $oInstrumentMap.Item($sSessionKey)

		Local $iJobId = $oMeta.Item("JobId")
		Local $tBuffer = $oMeta.Item("Buffer")
		Local $hTimer = $oMeta.Item("Timer")

		; Poll the instrument instantly (0ms timeout)
		Local $iEventType = 0
		Local $iEventHandle = 0
		Local $aWait = DllCall($hDll, "long", "viWaitOnEvent", _
				"uint64", $hSession, _
				"uint", $VI_EVENT_IO_COMPLETION, _
				"uint", 0, _
				"uint*", $iEventType, _
				"uint64*", $iEventHandle)

		Local $iWaitStatus = $aWait

		If $iWaitStatus >= 0 Then
			; --- Success Scenario: Data is ready ---
			Local $sData = DllStructGetData($tBuffer, 1)
			ConsoleWrite("Session [0x" & Hex($hSession) & "]: Finished! Data Received: " & $sData & @CRLF)

			; Clean up the event handle and stop tracking this device
			DllCall($hDll, "long", "viClose", "uint64", $aWait)
			$oInstrumentMap.Remove($sSessionKey)

		Else
			; --- Ongoing Tracking Scenario: Check for timeouts ---
			If TimerDiff($hTimer) >= $iMaxTimeoutMs Then
				ConsoleWrite("Session [0x" & Hex($hSession) & "]: Max Timeout breached! Force terminating..." & @CRLF)

				; Force close the operation via viTerminate
				_viTerminate($hDll, $hSession, $iJobId)

				; Flush any pending "Operation Aborted" events out of the queue
				DllCall($hDll, "long", "viWaitOnEvent", "uint64", $hSession, "uint", $VI_EVENT_IO_COMPLETION, "uint", 0, "uint*", $iEventType, "uint64*", $iEventHandle)

				; Stop tracking this instrument
				$oInstrumentMap.Remove($sSessionKey)
			EndIf
		EndIf
	Next

	; Keep your main CPU usage low or handle application GUI states here
	Sleep(100)
WEnd

ConsoleWrite(@CRLF & "All active concurrent instrumentation queues are clear." & @CRLF)
DllClose($hDll)

; --- Helper Type Cast Utility for Dictionary String Keys ---
Func UInt64($sVal)
	Local $tVal = DllStructCreate("uint64")
	DllStructSetData($tVal, 1, $sVal)
	Return DllStructGetData($tVal, 1)
EndFunc   ;==>UInt64

; --- 64-Bit Reusable Terminate Function ---
Func _viTerminate($hDll, $hSession, $iJobId)
	Local $aResult = DllCall($hDll, "long", "viTerminate", _
			"uint64", $hSession, _
			"ushort", 0, _
			"uint64", $iJobId)
	If @error Then Return -1
	Return $aResult
EndFunc   ;==>_viTerminate



