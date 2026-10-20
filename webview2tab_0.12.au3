#include-once

; webview2 functions

#cs

		WebView functions

provides:  a web page element in the gui window

usage:

	include this at the top of your main script to initialize the functions

	__WebViewNagivate($aWebView,$sUrl)
		navigate the webpage to the given url

	__WebViewVisible($aWebView,True|False)		show or hide the browser


#ce



#include <File.au3>
#include <Math.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include "winmgmt.au3"
#include <GuiTab.au3>


#include ".\webview2\Include\WebView2_Native.au3"


;Global $__mWebView2[], $__aWebView2
Global $g_webview2_tempFolder, $g_webview2_userFolderBase
Global $g_aCanvas

__WebView2init()
OnAutoItExitRegister("__WebView2exit")






; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------

; api functions



Func __WebView2_CanvasGuiCreate($iTabIdx, $oCanvas, $hCanvas)
	Local $sUserFolder = $g_webview2_userFolderBase & $iTabIdx
	DirCreate($sUserFolder)
	Local $iW = $oCanvas.Item('iW')
	Local $iH = $oCanvas.Item('iH')
	Local $aWebView = _WebView2_Create($hCanvas, 0, 0, $iW, $iH, $g_webview2_tempFolder & "\WebView2Loader.dll", $sUserFolder)
	If @error Then MsgBox($MB_ICONERROR, "Error", "Error: Failed to create WebView2 (Error " & @error & ")")
	$oCanvas.Item('aWebView') = $aWebView
EndFunc   ;==>__WebView2_CanvasGuiCreate




Func __WebView2Visible($aWebView, $bState)
	If Not IsArray($aWebView) Then Return
	If UBound($aWebView) < 2 Then Return
	_WebView2_SetVisibleInternal($aWebView[1], $bState)
EndFunc   ;==>__WebView2Visible



Func __WebView2Navigate($aWebView, $sUrl)
	_WebView2_Navigate($aWebView, "about:blank")    ; flush out the old URL
	Sleep(100)
	_WebView2_Navigate($aWebView, $sUrl)            ; navigate to browser to the given URL
	Sleep(100)
	;__WebView2_WM_SIZE($hWnd, 0, 0, 0)  			; for some reason the webview2 window is being reset to a small size, this fixes it
EndFunc   ;==>__WebView2Navigate







; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------
; -----------------------------------------------------



Func __WebView2init()
	;$__aWebView2 = False

	; Create a temporary storage folder
	$g_webview2_tempFolder = @TempDir & "\webview"
	Local $n = Random(100, 899, 1)
	While FileExists($g_webview2_tempFolder & $n) And ($n < 905)
		$n = $n + 1
	WEnd
	$g_webview2_tempFolder = $g_webview2_tempFolder & $n
	DirCreate($g_webview2_tempFolder)

	; --- Embed and Extract the Correct Loader DLL ---
	If @AutoItX64 Then
		; Embeds the 64-bit loader into the compiled executable
		FileInstall(".\webview2\bin\WebView2Loader_x64.dll", $g_webview2_tempFolder & "\WebView2Loader.dll", $FC_OVERWRITE)
		FileInstall(".\webview2\bin\WebView2Helper_x64.dll", $g_webview2_tempFolder & "\WebView2Helper.dll", $FC_OVERWRITE)
	Else
		; Embeds the 32-bit loader into the compiled executable
		FileInstall(".\webview2\bin\WebView2Loader_x86.dll", $g_webview2_tempFolder & "\WebView2Loader.dll", $FC_OVERWRITE)
		FileInstall(".\webview2\bin\WebView2Helper_x86.dll", $g_webview2_tempFolder & "\WebView2Helper.dll", $FC_OVERWRITE)
	EndIf

	$g_webview2_userFolderBase = $g_webview2_tempFolder & "\WebView2AppData_"
	;DirCreate($g_webview2_userFolderBase)



	; webview2
	;Local $sRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
	;If RegRead($sRegPath, "pv") = "" Then
	;	MsgBox(16, "Error", "WebView2 Runtime is required. Please install it.")
	;	; Optionally launch a bundled or downloaded bootstrapper here
	;	;ShellExecute("https://developer.microsoft.com/en-us/microsoft-edge/webview2/")
	;EndIf

	_WebView2Runtime_CheckAndPromptInstall(True)

	If Not _WebView2_IsRuntimeInstalled() Then
		MsgBox(0x10, "Error", "WebView2 Runtime is not installed!" & @CRLF & @CRLF & _
				"Please download from:" & @CRLF & _
				"https://developer.microsoft.com/en-us/microsoft-edge/webview2/")
		Exit
	EndIf
	If Not _WebView2_GetLoaderDll($g_webview2_tempFolder & "\WebView2Loader.dll") Then
		MsgBox(0x10, "Error", "WebView2Loader.dll not found!" & @CRLF & @CRLF & _
				"Please run bin\extract_dll.bat to extract it from the NuGet package." & _
				@CRLF & @CRLF & $g_webview2_tempFolder & "\WebView2Loader.dll")
		Exit
	EndIf

	$__g_sWV2_HelperPath = $g_webview2_tempFolder & "\WebView2Helper.dll"            ; point to the webview2 helper dll.  this variable is internal to WebView2

EndFunc   ;==>__WebView2init





Func __WebView2exit()
	Local $i, $n = UBound($g_aCanvas) - 1
	For $i = 0 To $n
		If __IsDictionary($g_aCanvas[$i]) Then
			Local $oCanvas = $g_aCanvas[$i]
			If $oCanvas.Exists('aWebView') Then
				Local $aWebView = $oCanvas.Item('aWebView')
				If IsArray($aWebView) Then _WebView2_Close($aWebView)
			EndIf
		EndIf
	Next
	;Sleep(200)
	;DirRemove($g_webview2_tempFolder, 1)
	Run(@ComSpec & ' /c timeout 2 & rmdir /q/s "' & $g_webview2_tempFolder & '"', "", @SW_HIDE)
EndFunc   ;==>__WebView2exit












;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------




