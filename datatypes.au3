#include-once



Func __IsDictionary($vVar)                                                      ; confirm $vVar is a scripting dictionary or not
	If Not IsObj($vVar) Then Return False
	Return ObjName($vVar) = "Dictionary"
EndFunc   ;==>__IsDictionary
Func __IsScriptingDictionary($vVar)
	Return __IsDictionary($vVar)
EndFunc   ;==>__IsScriptingDictionary




; Function Name:    __viIsDllHandleValid
; Description:      Queries kernel32.dll directly to check if a DllOpen handle is live and active.
; Parameter(s):     $hDll - The handle returned from DllOpen() to test
; Return Value(s):  True  - The handle is open and valid.
;                   False - The handle is dead, closed, or corrupted.
Func __IsDllHandleValid($hDll)
	If $hDll = "" Or $hDll = True Or $hDll = False Then Return False            ; sanity checks
	If Number($hDll) = 0 Then Return False
	Local $aRet = DllCall("kernel32.dll", "dword", "GetModuleFileNameW", _      ; Call GetModuleFileNameW. It returns the path string length on success, or 0 on failure.
			"handle", $hDll, _                                                  ;    We provide a tiny 2-character buffer because we only care about the success/failure return status code.
			"wstr", "", _
			"dword", 2)
	If @error Then Return False                                                 ; The DLL call itself failed entirely
	Return ($aRet[0] > 0)                                                       ; If the return value is greater than 0, the handle is valid!
EndFunc   ;==>__IsDllHandleValid



Func __IsFileHandle($hFile)
	If Not IsInt($hFile) And Not IsPtr($hFile) Then Return False                ; 1. Quick structural check: Handles must be valid integers or pointers
	FileGetPos($hFile)                                                          ; 2. Functional check: Attempt to read its position
	If @error Then Return False                                                 ; If the handle is fake or has been closed, @error will be set to non-zero
	Return True
EndFunc   ;==>__IsFileHandle



Func __IsTCPsocket($hSocket)
	If Not IsInt($hSocket) And Not IsPtr($hSocket) Then Return False            ; 1. Check if the variable data type is a basic integer/pointer format above 0
	If Int($hSocket) <= 0 Then Return False
	__SocketToIP($hSocket)                                                      ; 2. Test the handle against a network function to see if it is still live/recognized
	If @error Then Return False                                                 ; If the socket handle is closed, corrupted, or fake, @error will be set to non-zero
	Return True
EndFunc   ;==>__IsTCPsocket



; Function:     __SocketToIP
; Description:  Queries Windows Winsock API to fetch the remote IP Address of an active socket handle
; Returns:      String (IP Address) on Success, 0 on Failure
Func __SocketToIP($hSocket)
	Local $tSockAddr = DllStructCreate("short;ushort;uint;char[8]")
	Local $iSockAddrSize = DllStructGetSize($tSockAddr)
	Local $aRet = DllCall("Ws2_32.dll", "int", "getpeername", "uint_ptr", $hSocket, "struct*", $tSockAddr, "int*", $iSockAddrSize)
	If Not @error And $aRet[0] = 0 Then
		$aRet = DllCall("Ws2_32.dll", "str", "inet_ntoa", "int", DllStructGetData($tSockAddr, 3))
		If Not @error Then Return $aRet[0]
	EndIf
	Return 0
EndFunc   ;==>__SocketToIP


