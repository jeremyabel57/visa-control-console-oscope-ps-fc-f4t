#include-once

; webview2 functions


#include <File.au3>

#include "webview2\Include\WebView2_Native.au3"



Global $g_aWebView2
Global $g_WVtempFolder

__webview2init()
OnAutoItExitRegister("__webview2exit")


Func __webview2init()
	$g_aWebView2 = ""

	; Create a temporary storage folder
	$g_WVtempFolder = @TempDir & "\webview"
	Local $n = Random(100, 899, 1)
	While FileExists($g_WVtempFolder & $n) And ($n < 905)
		$n = $n + 1
	WEnd
	$g_WVtempFolder = $g_WVtempFolder & $n
	DirCreate($g_WVtempFolder)

	; --- Embed and Extract the Correct Loader DLL ---
	If @AutoItX64 Then
		; Embeds the 64-bit loader into the compiled executable
		FileInstall("...\scripts\ManualStationControl\webview2\bin\WebView2Loader_x64.dll", $g_WVtempFolder & "\WebView2Loader.dll", $FC_OVERWRITE)
		FileInstall("...\scripts\ManualStationControl\webview2\bin\WebView2Helper_x64.dll", $g_WVtempFolder & "\WebView2Helper.dll", $FC_OVERWRITE)
	Else
		; Embeds the 32-bit loader into the compiled executable
		FileInstall("...\scripts\ManualStationControl\webview2\bin\WebView2Loader_x86.dll", $g_WVtempFolder & "\WebView2Loader.dll", $FC_OVERWRITE)
		FileInstall("...\scripts\ManualStationControl\webview2\bin\WebView2Helper_x86.dll", $g_WVtempFolder & "\WebView2Helper.dll", $FC_OVERWRITE)
	EndIf

EndFunc   ;==>__webview2init



Func __webview2exit()
	If $g_aWebView2 <> "" Then _WebView2_Close($g_aWebView2)
	Sleep(200)
	DirRemove($g_WVtempFolder, 1)
	Run(@ComSpec & ' /c timeout 2 & rmdir /q/s "' & $g_WVtempFolder & '"', "", @SW_HIDE)
EndFunc   ;==>__webview2exit



;#forcedef $V_WIDTH, $V_HEIGHT

;			webview2init
; task:		initialize webview2 and create a gui element of the web browser
; in:		$hGUI = gui window handle
; 			$iX, $iY = position of upper left of where to place the webview element within the gui window
;			$iW, $iH = width and height of the webview element
Func __webview2gui($hGUI, $iX = 0, $iY = 0, $iW = 800, $iH = 600)

	; webview2
	;Local $sRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
	;If RegRead($sRegPath, "pv") = "" Then
	;	MsgBox(16, "Error", "WebView2 Runtime is required. Please install it.")
	;	; Optionally launch a bundled or downloaded bootstrapper here
	;	;ShellExecute("https://developer.microsoft.com/en-us/microsoft-edge/webview2/")
	;EndIf

	_WebView2Runtime_CheckAndPromptInstall()

	Local $sUserDataFolder = $g_WVtempFolder & "\MyWebView2App_Data"
	;DirCreate($sUserDataFolder)
	If Not _WebView2_IsRuntimeInstalled() Then
		MsgBox(0x10, "Error", "WebView2 Runtime is not installed!" & @CRLF & @CRLF & _
				"Please download from:" & @CRLF & _
				"https://developer.microsoft.com/en-us/microsoft-edge/webview2/")
		Exit
	EndIf
	If Not _WebView2_GetLoaderDll($g_WVtempFolder & "\WebView2Loader.dll") Then
		MsgBox(0x10, "Error", "WebView2Loader.dll not found!" & @CRLF & @CRLF & _
				"Please run bin\extract_dll.bat to extract it from the NuGet package." & _
				@CRLF & @CRLF & $g_WVtempFolder & "\WebView2Loader.dll")
		Exit
	EndIf

	$__g_sWV2_HelperPath = $g_WVtempFolder & "\WebView2Helper.dll"            ; point to the webview2 helper dll
	$g_aWebView2 = _WebView2_Create($hGUI, $iX, $iY, $iW, $iH, $g_WVtempFolder & "\WebView2Loader.dll", $sUserDataFolder)

	If @error Then MsgBox(0, "Error", "Error: Failed to create WebView2 (Error " & @error & ")")

EndFunc   ;==>__webview2gui





Func _RemoveAll($dir, $sMask = "*", $iReturn = 0, $iRecur = 0, $sProgress = "Progress")
	If StringRight($dir, 1) <> "\" Then $dir &= "\"
	Local $aList = _FileListToArrayRec($dir, $sMask, $iReturn, $iRecur)
	If Not IsArray($aList) Then Return
	ProgressOn($sProgress, "0% completed")
	For $i = 1 To $aList[0]
		Local $sFilePath = $dir & $aList[$i]
		If StringInStr(FileGetAttrib($sFilePath), "D") = 0 Then
			FileDelete($sFilePath)
		Else
			DirRemove($sFilePath, $DIR_REMOVE)
		EndIf
	Next
EndFunc   ;==>_RemoveAll




