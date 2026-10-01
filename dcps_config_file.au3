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
;#include <MsgBoxConstants.au3>

; ---------------------- config file functions



ConfigFileInit("DC_Power_Supply")



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
	#forcedef $hIpAddr, $hMainGui, $g_ipAddrList, $g_ipAddr, $g_screenShotFile, $sv, $si, $upseqch, $upseqtm, $dnseqch, $dnseqtm, $lbl

	Local $j
	For $j = 0 To 3
		IniWrite($configFile, $configSection, "V" & ($j + 1), StringTrimRight(GUICtrlRead($sv[$j]), 2))
		IniWrite($configFile, $configSection, "I" & ($j + 1), StringTrimRight(GUICtrlRead($si[$j]), 2))
		IniWrite($configFile, $configSection, "upseqch" & ($j + 1), $upseqch[$j])
		IniWrite($configFile, $configSection, "upseqtm" & ($j + 1), $upseqtm[$j])
		IniWrite($configFile, $configSection, "dnseqch" & ($j + 1), $dnseqch[$j])
		IniWrite($configFile, $configSection, "dnseqtm" & ($j + 1), $dnseqtm[$j])
		IniWrite($configFile, $configSection, "chlbl" & ($j + 1), GUICtrlRead($lbl[$j]))
	Next

	IniWrite($configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($hIpAddr))    ; IP address list
	IniWrite($configFile, $configSection, "IpAddr", GUICtrlRead($hIpAddr))      ; IP address of VISA device

	IniWrite($configFile, $configSection, "screenShot", $g_screenShotFile)        ; file name of the screenshot file

	Local $aPos = WinGetPos($hMainGui)                                          ; window position
	IniWrite($configFile, $configSection, "wx", $aPos[0])
	IniWrite($configFile, $configSection, "wy", $aPos[1])
	IniWrite($configFile, $configSection, "ww", $aPos[2])
	IniWrite($configFile, $configSection, "wh", $aPos[3])
EndFunc   ;==>ConfigWrite



Func ConfigOpen()
	#forcedef $hMainGui
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($configFile, $sDrive, $sDir, $sFileName, $sExtension)
	;msgbox(0,"hi","sDrive=" & $sDrive & @CRLF & "sDir=" & $sDir & @CRLF & "sFileName=" & $sFileName & @CRLF & "sExtension=" & $sExtension)

	Local $sFile = FileOpenDialog("Open Settings", $sDrive & $sDir, "(*.ini)", BitOR($FD_FILEMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $hMainGui)

	If $sFile = "" Then Return
	$configFile = $sFile
	ConfigRead()
EndFunc   ;==>ConfigOpen



Func ConfigRead()
	#forcedef $hIpAddr, $hMainGui, $g_ipAddrList, $g_ipAddr, $g_screenShotFile, $sv, $si, $upseqch, $upseqtm, $dnseqch, $dnseqtm, $lbl

	If $configFile = "" Then Return
	If Not FileExists($configFile) Then Return
	Local $s, $a, $j

	For $j = 0 To 3
		GUICtrlSetData($sv[$j], IniRead($configFile, $configSection, "V" & ($j + 1), StringTrimRight(GUICtrlRead($sv[$j]), 2)) & " V")
		GUICtrlSetData($si[$j], IniRead($configFile, $configSection, "I" & ($j + 1), StringTrimRight(GUICtrlRead($si[$j]), 2)) & " A")
		$upseqch[$j] = IniRead($configFile, $configSection, "upseqch" & ($j + 1), $upseqch[$j])
		$upseqtm[$j] = IniRead($configFile, $configSection, "upseqtm" & ($j + 1), $upseqtm[$j])
		$dnseqch[$j] = IniRead($configFile, $configSection, "dnseqch" & ($j + 1), $dnseqch[$j])
		$dnseqtm[$j] = IniRead($configFile, $configSection, "dnseqtm" & ($j + 1), $dnseqtm[$j])
		GUICtrlSetData($lbl[$j], IniRead($configFile, $configSection, "chlbl" & ($j + 1), GUICtrlRead($lbl[$j])))
	Next

	$s = IniRead($configFile, $configSection, "IpAddr", GUICtrlRead($hIpAddr))                          ; IP address
	$a = IniRead($configFile, $configSection, "IpAddrList", _GUICtrlComboBox_GetList($hIpAddr))         ; IP address list
	GUICtrlSetData($hIpAddr, "|" & $a, $s)                                                              ; IP Address
	$g_screenShotFile = IniRead($configFile, $configSection, "screenShot", $g_screenShotFile)           ; screen shot file

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

	ConfigAssert()
EndFunc   ;==>ConfigRead





; task:			Assert config in the GUI onto the DC Power supply
;				if voltage and current settings are the same, then the channel is left alone
;				if voltage or current are updated, then the output state is turned off for safety
Func ConfigAssert()
	#forcedef $sv, $si
	Local $i, $cv, $nv, $viSession, $aReadV, $aReadI
	$viSession = GetIP()
	If Not __viBegin($viSession) Then Return SetError(-1, 0, 0)
	__viCmd($viSession, $VI_CLS)
	$aReadV = StringSplit(__dcps_viChRequest($viSession, "VOLT?", $DCPS_CH_ALL), ",")
	If $aReadV[0] < 4 Then
		__viEnd($viSession)
		Return SetError(-1, 0, 0)
	EndIf
	$aReadI = StringSplit(__dcps_viChRequest($viSession, "CURR?", $DCPS_CH_ALL), ",")
	If $aReadI[0] < 4 Then
		__viEnd($viSession)
		Return SetError(-1, 0, 0)
	EndIf

	For $i = 0 To 3
		; voltage setpoint
		$cv = StringFormat("%.3f", $aReadV[$i + 1])
		$nv = StringTrimRight(GUICtrlRead($sv[$i]), 2)
		If Not ($cv = $nv) Then
			__dcps_SetState($viSession, $i + 1, 0)                ; turn off the channel power output
			__dcps_SetVoltage($viSession, $i + 1, Number($nv))    ; set the voltage
		EndIf

		; max current setpoint
		$cv = StringFormat("%.3f", $aReadI[$i + 1])
		$nv = StringTrimRight(GUICtrlRead($si[$i]), 2)
		If Not ($cv = $nv) Then
			__dcps_SetState($viSession, $i + 1, 0)                ; turn off the channel power output
			__dcps_SetCurrent($viSession, $i + 1, Number($nv))    ; set the max current
		EndIf
	Next

	__viEnd($viSession)
EndFunc   ;==>ConfigAssert
