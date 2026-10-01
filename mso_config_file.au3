#include-once

#include <File.au3>

;#include <ProgressConstants.au3>
;#include <GuiEdit.au3>
;#include <GuiComboBox.au3>
;#include <ButtonConstants.au3>
;#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
;#include <GuiScrollBars.au3>
;#include <StructureConstants.au3>
#include <MsgBoxConstants.au3>

; ---------------------- config file functions



ConfigFileInit("Oscilloscope_Tektronix_MSO5")



Func ConfigFileInit($section)                                                        ; Config file
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	Global $configFile = $sDrive & $sDir & $sFileName & ".ini"                      ; config file path
	Global $configSection = $section                                                ; config file section
EndFunc   ;==>ConfigFileInit



;			Prompt user for config file name and save config
Func ConfigSave()
	#forcedef $hMainGUI
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($configFile, $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFile = FileSaveDialog("Save Settings", $sDrive & $sDir, "(*.ini)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $hMainGUI)
	If $sFile = "" Then Return
	$configFile = $sFile
	ConfigWrite()
EndFunc   ;==>ConfigSave


;			Save config to config file
Func ConfigWrite()
	#forcedef $hIpAddr, $hTunits, $hSP, $hSPunits, $hTnote, $hMainGui, $g_ipAddrList, $g_ipAddr, $g_screenShotFile

	IniWrite($configFile, $configSection, "IpAddrList", $g_ipAddrList)          ; IP address list
	IniWrite($configFile, $configSection, "IpAddr", $g_ipAddr)                  ; IP address of VISA device

	IniWrite($configFile, $configSection, "scopeShot", $g_screenShotFile)        ; file name of the screenshot file

	Local $aPos = WinGetPos($hMainGui)                                          ; window position
	IniWrite($configFile, $configSection, "wx", $aPos[0])
	IniWrite($configFile, $configSection, "wy", $aPos[1])
	IniWrite($configFile, $configSection, "ww", $aPos[2])
	IniWrite($configFile, $configSection, "wh", $aPos[3])
EndFunc   ;==>ConfigWrite



Func ConfigRead()
	#forcedef $hIpAddr, $hTunits, $hSP, $hSPunits, $hTnote, $hMainGui, $g_screenShotFile, $g_ipAddr, $g_ipAddrList

	If $configFile = "" Then Return
	If Not FileExists($configFile) Then Return
	Local $s
	Local $a

	$g_ipAddr = IniRead($configFile, $configSection, "IpAddr", $g_ipAddr)                          ; IP address
	$g_ipAddrList = IniRead($configFile, $configSection, "IpAddrList", $g_ipAddrList)            ; IP address list
	$g_screenShotFile = IniRead($configFile, $configSection, "scopeShot", $g_screenShotFile)

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

	;scopeGetID()
	;scopeNavigate()
EndFunc   ;==>ConfigRead





