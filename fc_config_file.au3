#include-once

#include "windowresize.au3"
#include "fc_visadll.au3"

#include <File.au3>

#include <ProgressConstants.au3>
#include <GuiEdit.au3>
#include <GuiComboBox.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <GuiScrollBars.au3>
#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>

; ---------------------- config file functions


ConfigFileInit("FrequencyCounter")                   ; set config file global variables



Func ConfigFileInit($section)                                                    ; Config file
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	Global $configFile = $sDrive & $sDir & $sFileName & ".ini"                    ; config file path
	Global $configSection = $section                                            ; config file section
EndFunc   ;==>ConfigFileInit



Func ConfigWrite()
	#forcedef $hIpAddr, $hCaptureData, $hScreenShot, $hCaptureCount, $hMainGui, $hRefreshInterval, $hCaptureInitCheck

	IniWrite($configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($hIpAddr))                 ; IP address list
	IniWrite($configFile, $configSection, "IpAddr", GUICtrlRead($hIpAddr))                                  ; IP address of VISA device

	IniWrite($configFile, $configSection, "CountRequired", GUICtrlRead($hCaptureCount))                     ; autocapture sample minimum count
	IniWrite($configFile, $configSection, "RefreshInterval", GUICtrlRead($hRefreshInterval))                ; refresh interval
	IniWrite($configFile, $configSection, "ScreenShotFile", GUICtrlRead($hScreenShot))                      ; screen shot file
	IniWrite($configFile, $configSection, "CaptureDataFile", GUICtrlRead($hCaptureData))                    ; data shot file
	IniWrite($configFile, $configSection, "CaptureInitialize", Number(GUICtrlRead($hCaptureInitCheck) = $GUI_CHECKED))    ; init checkbox

	Local $aPos = WinGetPos($hMainGui)                                                                      ; window position
	IniWrite($configFile, $configSection, "wx", $aPos[0])
	IniWrite($configFile, $configSection, "wy", $aPos[1])
	IniWrite($configFile, $configSection, "ww", $aPos[2])
	IniWrite($configFile, $configSection, "wh", $aPos[3])
EndFunc   ;==>ConfigWrite



Func ConfigRead()
	#forcedef $hIpAddr, $hCaptureData, $hScreenShot, $hCaptureCount, $hMainGui, $hRefreshInterval, $hCaptureInitCheck

	If $configFile = "" Then Return
	If Not FileExists($configFile) Then Return
	Local $s
	Local $a

	$s = IniRead($configFile, $configSection, "IpAddr", GUICtrlRead($hIpAddr))                                                  ; IP address
	$a = IniRead($configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($hIpAddr))                                 ; IP address list
	GUICtrlSetData($hIpAddr, "|" & $a, $s)                                                                                      ; IP Address

	GUICtrlSetData($hCaptureCount, IniRead($configFile, $configSection, "CountRequired", GUICtrlRead($hCaptureCount)))          ; autocapture sample minimum count
	GUICtrlSetData($hRefreshInterval, IniRead($configFile, $configSection, "RefreshInterval", GUICtrlRead($hRefreshInterval)))  ; refresh interval

	GUICtrlSetData($hScreenShot, IniRead($configFile, $configSection, "ScreenShotFile", GUICtrlRead($hScreenShot)))             ; screen shot file
	GUICtrlSetData($hCaptureData, IniRead($configFile, $configSection, "CaptureDataFile", GUICtrlRead($hCaptureData)))          ; data shot file

	GUICtrlSetState($hCaptureInitCheck, _
			Number(IniRead($configFile, $configSection, "CaptureInitialize", Number(GUICtrlRead($hCaptureInitCheck) = $GUI_CHECKED))) ? _
			$GUI_CHECKED : $GUI_UNCHECKED)

	Local $aPos = WinGetPos($hMainGui)
	Local $iX = IniRead($configFile, $configSection, "wx", $aPos[0]) + 0
	Local $iY = IniRead($configFile, $configSection, "wy", $aPos[1]) + 0
	Local $iW = IniRead($configFile, $configSection, "ww", $aPos[2]) + 0
	Local $iH = IniRead($configFile, $configSection, "wh", $aPos[3]) + 0
	If IsNumber($iW) And IsNumber($iH) Then
		If ($iW > 200) And ($iH > 200) Then
			Local $aPos = _WinSnapToDesktop($iX, $iY, $iW, $iH)
			WinMove($hMainGui, "", $aPos[0], $aPos[1], $aPos[2], $aPos[3])
		EndIf
	EndIf

	GetID()
EndFunc   ;==>ConfigRead




