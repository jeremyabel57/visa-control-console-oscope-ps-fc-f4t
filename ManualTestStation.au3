#cs


add other instruments to the gui and then validate the visa functions
  getid and other simple strings
  download file
  download picture / take screenshot
  modbus
  all scripting commands possible - and create simple documentation for the scripting


once we get all of that done, then look into converting to python.  make sure the visa/modbus comm and script queue is solid in python before proceeding
use pywin32 for generic windows gui elements
chatgpt or gemini can help do conversions so some of the stuff works like autoit commands, so the code does not look so messy

finally, add manual test station scripts for i2c, spi, and clocks





next steps 10/12/2026

handle minimize - it caused the visa scan to fail

	do until validated
	while end validated

	test if/then/else/end

	finish integrating FC into gui
	integrate DC PS into gui
	integrate chamber into gui

	validate everything

	add settings/config tab where you can set variables - used for pn/sn/ipn/...
	chamber temperature selections
	signal/item list (clocks, I2c busses, spi busses, etc...)
	folder of where to store data

automating the manual test sequence

	option to save data direct to test plan in its existing format.  add profile config file to tell where to save which piece of data

	add tab for each test I2C, SPI, Clocks
	   add general picture file for the timing diagram for each test

	during the test sequence, add option to show a picture before each measurement.
	  the picture will be a file showing the timing diagram with the particular measurement highlighted and a text field superimposed with notes
	  of what to measure

	for each measurement, or group of measurements, list them out in the gui, then have buttons for setup scope and capture scope
	  make a generic framework for this so we can have a config file for each test profile.
	  the file can list the measurements needed, and point to the visa scripts to setup the scope and capture from the scope
	  also use common variables names to pull the chamber temperature and other info for the scopeshot titles and file names
	  and have pointers to where to park the captured data in the excel spreadsheet


on the scope
    for the automated captures, see if we can get the scope to show where it measured each item.  may have to take multiple scope shots
	use the generic text files as script files to take each measurement

	add option









#ce











; todo
;
; test additional vi script functions
; PASSING read to file command in vi script - can be used for scope shots and other file transfers
;   file upload function to visascpi
;   write from file command to visa target as a command in vi script
;
; add a tab menu button on the title bar to switch between oscope view and other tabs
; - control dashboard with power supply, chamber, and frequency counter - including showing current status
; - profile page with input fields for IPN, SN, and other information as well as temperature ranges and test item names (clocks/i2c busses/...)
;
; add a small status section to the title bar
; - chamber temperature (if available)
; - power supply on/off
; - test profile name (I2C, SPI, SMBus...)
; - current test item name
;

; next steps:
;   add prefixes to all functions and variable names so that the entire set of 4 instrument controls can be added together into one
; main program.
; - use a tab in the main window
; - see if you can have it allow the separate tabs to undock from the main window and become their own window
; - add a settings tab that will have all the paths and ip addresses in it, complete with a scan network and auto populate
; - add a dashboard tab that will have
;   . chamber temperature and setpoint and on/off button
;   . power supply voltages, on/off status (grayed out if off, colored if on), and up/down sequence buttons
;   . oscope screen capture button that will have a minature of the picture shown in the dashboard after it is captured
;
;






; Oscilloscope Tektronix MSO5 remote control and screenshot capture
;
;


#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Icon=mts.ico

Global $g_hMainGui, $g_cTab, $g_hTab, $g_oMainCanvas


Global $g_configFile, $g_configSection                                                          ; config file variables
Global $g_instConfigSection = "VISA_Devices"                                                    ; device list section
Opt("GUIOnEventMode", 1)                                                                        ; ACTIVATE ONEVENT MODE GLOBALLY BEFORE CREATING WINDOWS

#include <File.au3>
#include <AutoItConstants.au3>
#include <GuiComboBox.au3>
#include <GuiTab.au3>


OnAutoItExitRegister("MainExit")                ; register before any other exit functions so this one will be executed last

#include "visascpi.au3" ; visa functions (must be included before most other include files
#include "misc.au3" ; miscellaneous
#include "myconstants.au3" ; character And other misc constants
#include "winmgmt.au3" ; window manager functions
#include "tableEdit.au3" ; 2D array editor




#cs
Local $oDev = "192.168.0.14"
Local $sR = __viReqBl($oDev,"*OPC?",true)
;__ConsoleWriteVar($oDev,", ","oDev")
__ConsoleWriteVar(BinaryToString($sR),", ","Response")
Local $sR = __viReqBl($oDev,"*IDN?",true,2000)
;__ConsoleWriteVar($oDev,", ","oDev")
__ConsoleWriteVar(BinaryToString($sR),", ","Response")

Exit
#ce

#cs
; debug begin
#include "visascpi.au3"


Local $oDev = "192.168.0.16"
Local $sR = __viReqBl($oDev,"*IDN?",true)
;__ConsoleWriteVar($oDev,", ","oDev")
__ConsoleWriteVar(BinaryToString($sR),", ","Response")

Exit

Local $oDev = "raw:192.168.0.25"
Local $sR = __viReqBl($oDev,"*IDN?",true)
__ConsoleWriteVar($oDev,", ","oDev")
__ConsoleWriteVar(BinaryToString($sR),", ","Response")

$oDev = "192.168.0.14"
Local $sR = __viReqBl($oDev,"*IDN?",true)
__ConsoleWriteVar($oDev,", ","oDev")
__ConsoleWriteVar(BinaryToString($sR),", ","Response")

Exit
; debug end

#ce






ProgressOn("Hello", "Starting up", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
ProgressSet(50)

ConfigFileInit("mts")

#include "tab_oscope.au3" ; oscope tab
#include "tab_FrequencyCounter.au3" ; frequency counter tab
#include "tab_DC_Power_Supply.au3" ; DC Power Supply tab
#include "tab_Chamber.au3" ; thermal chamber tab


CreateMainGUI()                                     ; create main gui window
GUISetState(@SW_SHOW, $g_hMainGui)                  ; show the main window

Local $hProgress = WinGetHandle("[TITLE:Hello; CLASS:AutoIt v3]")
WinSetOnTop($hProgress, "", $WINDOWS_ONTOP)         ; bring the progress dialog back above your Main GUI
ProgressSet(70)

Canvas_MainInit()                                   ; initialize the tab zoom feature
winmgmt_Init()                                      ; initialize Tabs, Zoom, Scrollbars and more
ProgressSet(80)

oscopeTab_init()                                    ; initialize oscopeTab
fcTab_init()                                        ; initialize fcTab
dcpsTab_init()                                      ; initialize dcpsTab
chamberTab_init()                                   ; initialize chamberTab
ProgressSet(90)

ConfigReadAll()                                     ; Load config
ProgressSet(100)
ProgressOff()



;
; CLEAN NON-BLOCKING WAIT LOOP FOR ONEVENT CORE
While 1
	LoopExec()
	Sleep(10)
WEnd

Exit



; ----------------------------------------------
; support functions



; ---------  AutoIT GUI event handlers -----------

Func CloseApp()
	ProgressOn("Goodbye", "Cleaning up...", "")
	ProgressSet(5)
	ConfigWriteAll()
	ProgressSet(75)
	;GUIDelete($g_hMainGui)
	;Sleep(200)
	Exit
EndFunc   ;==>CloseApp

Func MainExit()
	ProgressSet(85)
	GUISetState(@SW_HIDE, $g_hMainGui)
	GUIDelete($g_hMainGui)
	ProgressOff()
EndFunc   ;==>MainExit




; -------------------------------------------------------------------

Func Canvas_MainInit()
	;create zoominit structure with just the $g_hTab in it
	Local $aSize = WinGetClientSize($g_hMainGui)
	Local $aDef[2] = [800, 600]
	If Not IsArray($aSize) Then $aSize = $aDef
	$g_oMainCanvas = __Canvas_Create(-1, $aSize[0], $aSize[1])
	$g_oMainCanvas.Item('hWnd') = $g_hMainGui
	Local $aCtrls[1] = [ $g_hTab ]
	$g_oMainCanvas.Item('aCtrls') = $aCtrls
;ConsoleWrite(@CRLF & "Canvas_MainInit" & @CRLF)
;__ConsolePrintVar("Canvas_MainInit","oMainCanvas",$g_oMainCanvas)
	__Canvas_ZoomCatalog($g_oMainCanvas)
EndFunc   ;==>Canvas_MainInit




Func CreateMainGUI()
	Local $V_WIDTH = 800
	Local $V_HEIGHT = 600

	$g_hMainGui = GUICreate("ManualTestStation", $V_WIDTH, $V_HEIGHT, -1, -1, _
			BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX))      ; main window

	$g_cTab = GUICtrlCreateTab(0, 0, $V_WIDTH, $V_HEIGHT)                                                   ; Create the main Tab Control container
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM))             ; resize with entire window
	$g_hTab = GUICtrlGetHandle($g_cTab)

	TabCreateCanvas("Oscilloscope", "oscopeTab_CanvasGuiCreate", "oscopeTab_TabGuiCreate", _                ; Tab 0
			$CANVASZOOMTYPE_MIN)

	TabCreateCanvas("DC Power Supply", "dcpsTab_GuiCreate")                                                 ; Tab 1

	TabCreateCanvas("Chamber", "chamberTab_GuiCreate")                                                      ; Tab 2

	TabCreateCanvas("Frequency Counter", "fcTab_GuiCreate")                                                 ; Tab 3

	GUICtrlCreateTabItem("Settings")                                                                        ; Tab 4

	GUICtrlCreateTabItem("I2C")                                                                             ; Tab 5

	GUICtrlCreateTabItem("SPI")                                                                             ; Tab 6

	GUICtrlCreateTabItem("Clocks")                                                                          ; Tab 7

	;GUICtrlSetState(-1, $GUI_SHOW)                                                                          ; set this as initial tab to show so that the tab 0 buttons do not initially appear
	GUICtrlCreateTabItem("")                                                                                ; Close the tab item definition structure


	GUISetOnEvent($GUI_EVENT_CLOSE, "CloseApp", $g_hMainGui)                                                ; Register the close button action for the main layout frame

EndFunc   ;==>CreateMainGUI






;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------

; config file functions





Func ConfigFileInit($section)                                               ; Config file
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit(@ScriptFullPath, $sDrive, $sDir, $sFileName, $sExtension)
	$g_configFile = $sDrive & $sDir & $sFileName & ".ini"                   ; config file path
	$g_configSection = $section                                             ; mts config file section

	;Vars_ConfigRead()
	;Instruments_ConfigRead()
EndFunc   ;==>ConfigFileInit





; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; write to config file



;			Prompt user for config file name and save config
Func ConfigSave()
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($g_configFile, $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFile = FileSaveDialog("Save Settings", $sDrive & $sDir, "(*.ini)", BitOR($FD_PATHMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $g_hMainGui)
	If $sFile = "" Then Return
	$g_configFile = $sFile
	ConfigWrite()
EndFunc   ;==>ConfigSave



;			Save config to config file
Func ConfigWriteAll()
	ConfigWrite()
	oscopeTab_ConfigWrite()
	dcpsTab_ConfigWrite()
	chamberTab_ConfigWrite()
	fcTab_ConfigWrite()
EndFunc   ;==>ConfigWriteAll
Func ConfigWrite()
	Local $aPos = WinGetPos($g_hMainGui)                                                    ; window position
	If IsArray($aPos) Then
		If UBound($aPos) >= 4 Then
			IniWrite($g_configFile, $g_configSection, "wx", $aPos[0])
			IniWrite($g_configFile, $g_configSection, "wy", $aPos[1])
			IniWrite($g_configFile, $g_configSection, "ww", $aPos[2])
			IniWrite($g_configFile, $g_configSection, "wh", $aPos[3])
		EndIf
	EndIf
	IniWrite($g_configFile, $g_configSection, "ws", $g_oMainCanvas.Item('fzScale'))      ; main window zoom scale

	IniWrite($g_configFile, $g_configSection, "vpx", $g_iViewportX)                         ; viewport position
	IniWrite($g_configFile, $g_configSection, "vpy", $g_iViewportY)
	IniWrite($g_configFile, $g_configSection, "vpw", $g_iViewportW)
	IniWrite($g_configFile, $g_configSection, "vph", $g_iViewportH)

	If IsArray($g_aCanvas) Then                                                             ; tab canvases scroll x,y, and zoom scale
		Local $oCanvas, $i, $n = UBound($g_aCanvas) - 1
		Local $sKey
		For $i = 0 To $n
			$oCanvas = $g_aCanvas[$i]
			If Not __IsDictionary($oCanvas) Then ContinueLoop
			Local $a = ['fzScale', 'iSX', 'iSY']
			For $sKey In $a
				If $oCanvas.Exists($sKey) Then _
						IniWrite($g_configFile, $g_configSection, "tab" & $i & "_" & $sKey, $oCanvas.Item($sKey))
			Next
		Next
	EndIf

	IniWrite($g_configFile, $g_configSection, "tab", GUICtrlRead($g_cTab))                  ; currently selected tab

	Instruments_ConfigWrite()
	Vars_ConfigWrite()
EndFunc   ;==>ConfigWrite




Func Instruments_ConfigWrite()
	If Not IsArray($g_aFoundVisaDevices) Then Return
	If UBound($g_aFoundVisaDevices, 0) <> 2 Then Return
	Local $i, $n = UBound($g_aFoundVisaDevices, 1) - 1
	IniWrite($g_configFile, $g_instConfigSection, "n", $n)                                                  ; number of items found minus one
	For $i = 0 To $n
		IniWrite($g_configFile, $g_instConfigSection, "IP" & $i, $g_aFoundVisaDevices[$i][0])               ; IP address
		IniWrite($g_configFile, $g_instConfigSection, "Adr" & $i, $g_aFoundVisaDevices[$i][1])              ; full address
		IniWrite($g_configFile, $g_instConfigSection, "IDN" & $i, $g_aFoundVisaDevices[$i][2])              ; IDN string
		IniWrite($g_configFile, $g_instConfigSection, "Typ" & $i, $g_aFoundVisaDevices[$i][3])              ; classification
	Next
EndFunc   ;==>Instruments_ConfigWrite








; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; -------------------------------------------------------
; read from config file



;			Prompt user for config file to open
Func ConfigOpen()
	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit($g_configFile, $sDrive, $sDir, $sFileName, $sExtension)
	Local $sFile = FileOpenDialog("Open Settings", $sDrive & $sDir, "(*.ini)", BitOR($FD_FILEMUSTEXIST, $FD_PATHMUSTEXIST), $sFileName, $g_hMainGui)
	If $sFile = "" Then Return
	$g_configFile = $sFile
	ConfigRead()
EndFunc   ;==>ConfigOpen



;		main configread
Func ConfigReadAll()
	ConfigRead()
	oscopeTab_ConfigRead()
	dcpsTab_ConfigRead()
	chamberTab_ConfigRead()
	fcTab_ConfigRead()
EndFunc   ;==>ConfigReadAll
Func ConfigRead()
	If $g_configFile = "" Then Return
	If Not FileExists($g_configFile) Then Return

	Local $aPosDef[4] = [20, 20, 800, 600]
	Local $aPos = WinGetPos($g_hMainGui)
	If Not IsArray($aPos) Then $aPos = $aPosDef
	If UBound($aPos) < 4 Then $aPos = $aPosDef
	Local $iX = IniRead($g_configFile, $g_configSection, "wx", $aPos[0])                            ; Window position
	Local $iY = IniRead($g_configFile, $g_configSection, "wy", $aPos[1])
	Local $iW = IniRead($g_configFile, $g_configSection, "ww", $aPos[2])
	Local $iH = IniRead($g_configFile, $g_configSection, "wh", $aPos[3])
	If StringIsInt($iW) And StringIsInt($iH) Then
		If ($iW > 200) And ($iH > 200) Then
			Local $aPos = _WinSnapToDesktop($iX, $iY, $iW, $iH)
			WinMove($g_hMainGui, "", $aPos[0], $aPos[1], $aPos[2], $aPos[3])
		EndIf
	EndIf

	If __IsDictionary($g_oMainCanvas) Then                                                          ; main window zoom scale
		$g_oMainCanvas.Item('fzScale') = Number(IniRead($g_configFile, $g_configSection, "ws", $g_oMainCanvas.Item('fzScale')))
		__Canvas_SetZoom($g_oMainCanvas, $g_oMainCanvas.Item('fzScale'))
	EndIf

	$g_iViewportX = IniRead($g_configFile, $g_configSection, "vpx", $g_iViewportX)                  ; viewport position
	$g_iViewportY = IniRead($g_configFile, $g_configSection, "vpy", $g_iViewportY)
	$g_iViewportW = IniRead($g_configFile, $g_configSection, "vpw", $g_iViewportW)
	$g_iViewportH = IniRead($g_configFile, $g_configSection, "vph", $g_iViewportH)

	If IsArray($g_aCanvas) Then                                                                     ; tab canvases scroll x,y, and zoom scale
		Local $oCanvas, $i, $n = UBound($g_aCanvas) - 1
		Local $sKey
		For $i = 0 To $n
			$oCanvas = $g_aCanvas[$i]
			If Not __IsDictionary($oCanvas) Then ContinueLoop
			Local $a = ['fzScale', 'iSX', 'iSY']
			For $sKey In $a
				$oCanvas.Item($sKey) = Number(IniRead($g_configFile, $g_configSection, "tab" & $i & "_" & $sKey, $oCanvas.Item($sKey)))
			Next
			$sKey = 'fzScale'
			If $oCanvas.Item($sKey) <= 0 Then $oCanvas.Item($sKey) = 1.0
		Next
	EndIf

	TabSwitch(IniRead($g_configFile, $g_configSection, "tab", _GUICtrlTab_GetCurSel($g_hTab)))      ; active tab

	Instruments_ConfigRead()
	Vars_ConfigRead()
EndFunc   ;==>ConfigRead





Func Instruments_ConfigRead()
	Local $n = IniRead($g_configFile, $g_instConfigSection, "n", -1)                            ; number of items found minus one
	If $n < 0 Then Return
	Local $i, $j = 0, $a[$n + 1][4]
	For $i = 0 To $n
		$a[$j][0] = IniRead($g_configFile, $g_instConfigSection, "IP" & $i, "")                 ; IP address
		$a[$j][1] = IniRead($g_configFile, $g_instConfigSection, "Adr" & $i, "")                ; full address
		$a[$j][2] = IniRead($g_configFile, $g_instConfigSection, "IDN" & $i, "")                ; IDN string
		$a[$j][3] = IniRead($g_configFile, $g_instConfigSection, "Typ" & $i, "")                ; classification
		If $a[$j][0] <> "" Then $j += 1
	Next
	If $j <= $n Then ReDim $a[$j][4]
	If $j > 0 Then $g_aFoundVisaDevices = $a
EndFunc   ;==>Instruments_ConfigRead






;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------
;-------------------------------------------------------------------------------------------------------------

;

