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


ConfigFileInit("Chamber")                   ; set config file global variables



Func ConfigFileInit($section)                                                    ; Config file
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	Global $configFile = $sDrive & $sDir & $sFileName & ".ini"                    ; config file path
	Global $configSection = $section                                            ; config file section
EndFunc   ;==>ConfigFileInit



Func ConfigWrite()
	#forcedef $hIpAddr, $hTunits, $hSP, $hSPunits, $hTnote, $hMainGui

	IniWrite($configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($hIpAddr))    ; IP address list
	IniWrite($configFile, $configSection, "IpAddr", GUICtrlRead($hIpAddr))      ; IP address of VISA device
	IniWrite($configFile, $configSection, "TemperatureUnits", GuiGetUnits($hTunits))
	IniWrite($configFile, $configSection, "SetPoint", GUICtrlRead($hSP))        ; temperature set point
	IniWrite($configFile, $configSection, "SetPointUnits", GuiGetUnits($hSPunits))
	IniWrite($configFile, $configSection, "Tnotify", (GUICtrlRead($hTnote) = $GUI_CHECKED) + 0)    ; notify checkbox

	Local $aPos = WinGetPos($hMainGui)                                          ; window position
	IniWrite($configFile, $configSection, "wx", $aPos[0])
	IniWrite($configFile, $configSection, "wy", $aPos[1])
	IniWrite($configFile, $configSection, "ww", $aPos[2])
	IniWrite($configFile, $configSection, "wh", $aPos[3])
EndFunc   ;==>ConfigWrite



Func ConfigRead()
	#forcedef $hIpAddr, $hTunits, $hSP, $hSPunits, $hTnote, $hMainGui

	If $configFile = "" Then Return
	If Not FileExists($configFile) Then Return
	Local $s
	Local $a

	$s = IniRead($configFile, $configSection, "IpAddr", GUICtrlRead($hIpAddr))                        ; IP address
	$a = IniRead($configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($hIpAddr))        ; IP address list
	GUICtrlSetData($hIpAddr, "|" & $a, $s)                                                             ; IP Address
	GUICtrlSetData($hSP, IniRead($configFile, $configSection, "SetPoint", GUICtrlRead($hSP)))                ; temperature set point
	$s = IniRead($configFile, $configSection, "Tnotify", (GUICtrlRead($hTnote) = $GUI_CHECKED)) + 0
	GUICtrlSetState($hTnote, ($s ? $GUI_CHECKED : $GUI_UNCHECKED))
	;GUICtrlSetState($hTnote, IniRead($configFile, $configSection, "Tnotify", (GUICtrlRead($hTnote) = $GUI_CHECKED)) ? $GUI_CHECKED : $GUI_UNCHECKED)              ; notify checkbox
	GuiSetUnits($hTunits, IniRead($configFile, $configSection, "TemperatureUnits", GuiGetUnits($hTunits)))  ; temperature units
	GuiSetUnits($hSPunits, IniRead($configFile, $configSection, "SetPointUnits", GuiGetUnits($hSPunits)))   ; setpoint units

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




