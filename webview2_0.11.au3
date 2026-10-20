#include-once

; webview2 functions

#cs

		WebView functions

provides:  a web page element in the gui window

usage:

	include this at the top of your main script to initialize the functions

	__WebView2gui($hGUI, $hCtrl, $iX = 0, $iY = 0, $iW = 800, $iH = 600)
		$hGUI = windows handle of the GUI window to place this gui element into
		$hCtrl = windows handle of the gui control element for this
		$iX, $iY = coordinates of upper left corner within the GUI to place
		$iW, $iH = width and height of this element

	__WebView2nagivate($sUrl)
		navigate the webpage to the given url

	__WebView2visible(True|False)		show or hide the browser


#ce



#include <File.au3>
#include <Math.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include "winmgmt.au3"
#include <GuiTab.au3>


#include ".\webview2\Include\WebView2_Native.au3"
;#include ".\webview2\Include\WebView2_Runtime.au3"


Global $__mWebView2[], $__aWebView2


__WebView2init()
OnAutoItExitRegister("__WebView2exit")



Func __WebView2navigate($sUrl)
	_WebView2_Navigate($__aWebView2, "about:blank")     ; flush out the old URL
	Sleep(200)
	_WebView2_Navigate($__aWebView2, $sUrl)             ; navigate to browser to the given URL
	Sleep(200)
	__WebView2_WM_SIZE($__mWebView2['hWnd'], 0, 0, 0)   ; for some reason the webview2 window is being reset to a small size, this fixes it
EndFunc   ;==>__WebView2navigate



Func __WebView2visible($bState)
	If Not IsArray($__aWebView2) Then Return
	If UBound($__aWebView2) < 2 Then Return
	_WebView2_SetVisibleInternal($__aWebView2[1], $bState)
EndFunc   ;==>__WebView2visible






Func __WebView2init()
	$__aWebView2 = False

	; Create a temporary storage folder
	$__mWebView2['tempFolder'] = @TempDir & "\webview"
	Local $n = Random(100, 899, 1)
	While FileExists($__mWebView2['tempFolder'] & $n) And ($n < 905)
		$n = $n + 1
	WEnd
	$__mWebView2['tempFolder'] = $__mWebView2['tempFolder'] & $n
	DirCreate($__mWebView2['tempFolder'])

	; --- Embed and Extract the Correct Loader DLL ---
	If @AutoItX64 Then
		; Embeds the 64-bit loader into the compiled executable
		FileInstall(".\webview2\bin\WebView2Loader_x64.dll", $__mWebView2['tempFolder'] & "\WebView2Loader.dll", $FC_OVERWRITE)
		FileInstall(".\webview2\bin\WebView2Helper_x64.dll", $__mWebView2['tempFolder'] & "\WebView2Helper.dll", $FC_OVERWRITE)
	Else
		; Embeds the 32-bit loader into the compiled executable
		FileInstall(".\webview2\bin\WebView2Loader_x86.dll", $__mWebView2['tempFolder'] & "\WebView2Loader.dll", $FC_OVERWRITE)
		FileInstall(".\webview2\bin\WebView2Helper_x86.dll", $__mWebView2['tempFolder'] & "\WebView2Helper.dll", $FC_OVERWRITE)
	EndIf

	$__mWebView2['userFolder'] = $__mWebView2['tempFolder'] & "\MyWebView2App_Data"
	DirCreate($__mWebView2['userFolder'])


EndFunc   ;==>__WebView2init


Func __WebView2init2()
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
	If Not _WebView2_GetLoaderDll($__mWebView2['tempFolder'] & "\WebView2Loader.dll") Then
		MsgBox(0x10, "Error", "WebView2Loader.dll not found!" & @CRLF & @CRLF & _
				"Please run bin\extract_dll.bat to extract it from the NuGet package." & _
				@CRLF & @CRLF & $__mWebView2['tempFolder'] & "\WebView2Loader.dll")
		Exit
	EndIf

	$__g_sWV2_HelperPath = $__mWebView2['tempFolder'] & "\WebView2Helper.dll"            ; point to the webview2 helper dll.  this variable is internal to WebView2
EndFunc   ;==>__WebView2init2



;			webview2gui
; task:		initialize webview2 and create a gui element of the web browser
; in:		$hWnd = main gui window handle
;			$hCtrl = control window handle to put this webview into
; 			$iX, $iY = position of upper left of where to place the webview element within the gui window
;			$iW, $iH = width and height of the webview element
Func __WebView2gui($hWnd, $iX = 0, $iY = 0, $iW = 800, $iH = 600)
	__WebView2init2()

	$__aWebView2 = _WebView2_Create($hWnd, $iX, $iY, $iW, $iH, $__mWebView2['tempFolder'] & "\WebView2Loader.dll", $__mWebView2['userFolder'])
	If @error Then MsgBox(0, "Error", "Error: Failed to create WebView2 (Error " & @error & ")")

	$__mWebView2['hWnd'] = $hWnd                                            ; window handle
	$__mWebView2['iLeft'] = $iX                                             ; left margin
	$__mWebView2['iTop'] = $iY                                              ; top margin
	$__mWebView2['iRight'] = _WinAPI_GetClientWidth($hWnd) - $iW - $iX      ; right margin
	$__mWebView2['iBottom'] = _WinAPI_GetClientHeight($hWnd) - $iH - $iY    ; bottom margin

	__WebView2init3()
EndFunc   ;==>__WebView2gui



Func __WebView2guiTab($hWnd, $cTab, $sWebViewTabName, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0)     ; add webview so it takes up the space inside a tab control
	__WebView2init2()


	$__mWebView2['cTab'] = $cTab                                                                            ; save the gui ctrl id for the tab
	GUICtrlGetHandle($cTab)
	;__viConsoleWrite($cTab, "", "cTab")
	;__viConsoleWrite($__mWebView2['iTabIdx'], "", "iTabIdx")
	Local $hTab = GUICtrlGetHandle($cTab)
	Local $aPageRect = _GUICtrlTab_GetDisplayRect($hTab)                                                    ; Pass the windows handle of the main Tab Container ($idTab). It returns: [0]=Left, [1]=Top, [2]=Right, [3]=Bottom
	Local $iX = $aPageRect[0] + $iLeft
	Local $iY = $aPageRect[1] + $iTop
	Local $iW = $aPageRect[2] - $iRight
	Local $iH = $aPageRect[3] - $iBottom
	$__mWebView2['iTabIdx'] = _GUICtrlTab_FindTab($hTab, $sWebViewTabName)                                  ; save tab index number of webview2gui for later reference

	$__aWebView2 = _WebView2_Create($hTab, $iX, $iY, $iW, $iH, $__mWebView2['tempFolder'] & "\WebView2Loader.dll", $__mWebView2['userFolder'])
	If @error Then MsgBox(0, "Error", "Error: Failed to create WebView2 (Error " & @error & ")")

	$__mWebView2['hWnd'] = $hWnd                                            ; window handle
	$__mWebView2['iLeft'] = $iX                                             ; left margin
	$__mWebView2['iTop'] = $iY                                              ; top margin
	$__mWebView2['iRight'] = _WinAPI_GetClientWidth($hWnd) - $iW - $iX      ; right margin
	$__mWebView2['iBottom'] = _WinAPI_GetClientHeight($hWnd) - $iH - $iY    ; bottom margin

	;__viConsoleWrite($__mWebView2['cTab'], "", "cTab")
	;__viConsoleWrite($__mWebView2['iTabIdx'], "", "iTabIdx")
	__WebView2init3()
EndFunc   ;==>__WebView2guiTab



Func __WebView2init3()
	_GUIRegisterMsgResize("__WebView2_WM_SIZE")
EndFunc   ;==>__WebView2init3




; --- RESIZING AND TAB HANDLING ---

Func __WebView2_UpdateBounds($hWnd = $__mWebView2['hWnd'])
	If Not IsArray($__aWebView2) Then Return

	; Get the updated width and height of the main client area
	Local $aSize = WinGetClientSize($hWnd)
	Local $iGuiWidth = $aSize[0]
	Local $iGuiHeight = $aSize[1]

	;__viConsoleWrite($hWnd, "", "_WM_SIZE hWnd")
	;__viConsoleWrite($iGuiWidth, "", "W")
	;__viConsoleWrite($iGuiHeight, " ", "H")

	_WebView2_SetBounds($__aWebView2, _
			$__mWebView2['iLeft'], $__mWebView2['iTop'], _
			$iGuiWidth - $__mWebView2['iRight'], $iGuiHeight - $__mWebView2['iBottom'])
EndFunc   ;==>__WebView2_UpdateBounds



; call this inside window resize events
Func __WebView2_WM_SIZE($hWnd, $Msg, $wParam, $lParam)
	Local $cTab = $__mWebView2['cTab']
	Local $iTabIdx = $__mWebView2['iTabIdx']
	Local $iTab = GUICtrlRead($cTab)

	;__viConsoleWrite($iTabIdx, " ", "__mWebView2 iTabIdx")
	;__viConsoleWrite($cTab, " ", "cTab")
	;__viConsoleWrite($iTab, " ", "iTab")
	; Only adjust positions if the browser object exists and the web tab is active
	If IsArray($__aWebView2) And _
			$hWnd = $__mWebView2['hWnd'] And _
			$iTab = $iTabIdx Then __WebView2_UpdateBounds($hWnd)
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__WebView2_WM_SIZE








Func __WebView2exit()
	If IsArray($__aWebView2) Then _WebView2_Close($__aWebView2)
	Sleep(200)
	DirRemove($__mWebView2['tempFolder'], 1)
	Run(@ComSpec & ' /c timeout 2 & rmdir /q/s "' & $__mWebView2['tempFolder'] & '"', "", @SW_HIDE)
EndFunc   ;==>__WebView2exit



#cs
Func _RemoveAll($dir, $sMask = "*", $iReturn = 0, $iRecur = 0)
	If StringRight($dir, 1) <> "\" Then $dir &= "\"
	Local $aList = _FileListToArrayRec($dir, $sMask, $iReturn, $iRecur)
	If Not IsArray($aList) Then Return
	For $i = 1 To $aList[0]
		Local $sFilePath = $dir & $aList[$i]
		If StringInStr(FileGetAttrib($sFilePath), "D") = 0 Then
			FileDelete($sFilePath)
		Else
			DirRemove($sFilePath, $DIR_REMOVE)
		EndIf
	Next
EndFunc   ;==>_RemoveAll
#ce



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




