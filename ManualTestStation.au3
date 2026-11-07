#cs


tabMeasure:
change tabmeasure channel selection box to be a full combo box
inclrease width of channel selection
move channel selection to the right of the bus name - increasing the number of columns
check the position of bus selection, and bus count input fields
change height of combo boxes to 20, not 22

change height of aMeas rows from 20 to 25

when setting up the variables for the measurement viscript, add one that pulls the chamber setpoint


    __viGetID
	  - try ping first?  to verify ip address?
	  - first try a modbus command to read a register, if successful then do complete modbus IDN sequence to get string and set sAddr to raw mode or use a different string to indicate modbus only mode "modbus:ipaddr:502"
	  - next try visa vxi-11 protocol *IDN? string, if successful then set sAddr to vxi-11 string
	  - finally try raw mode, if successful then set sAddr to "raw:..."
	  - if nothing worked, then leave sAddr at raw mode or empty string to signal no communications and if any new items added to queue to maybe try communications again

	debug __viGetIDbg
	  solved the issue with the excess traffic - that was a receive binary request when in raw socket mode.  this is now fixed
	  this routine still has issues, now everytime it is run it toggles the mode (vxi/raw) but does not appear to detect that the first mode was working


	debug tab pushes stuff on stack, but the last item on the stack does not appear to drop.
	  / add a debug button that dumps oDev into the output window any time you want
	  / add to the sPrintVar routine to detect if it is a stack, queue, or pQueue and print them as just a list of items (without head and tail pointers)

	when closing conditional script statement, there appears to be a pause - guessing a timeout as if it thinks there is a command running
	  for this, check the end of LoopExec to see what it does with a sCmd or sReq string that evaluates to a blank string.  If waitReply is true this might account for the pause

	add checkbox inbetween set and capture - if checked then pause for technician to verify measurement
	when building tab, add array of elements to save and restore states/data into ini file.  the list will be just the ctrl handles and the save/restore function will
	  identify the type of control and save/restore using the index number in the array as the key



	test config files:
	- add separate picture window for verifying the measurement
	  - read from test ini file or use the index number of the measurement as the picture file name and text to show below the picture for each measurement
	  - start with the one timing diagram picture for the overall test.  clone it and highlight each measurement, then in the measurement info / picture window pull it up for each measurement
	  - add test below the picture to help indicate what is being measured and what conditions to look for
	- main test template
	  . title / name of the test (I2C, SPI/Flash, QSPI, fNIC-I2C, clocks, ...)
	  . list of measurements to be taken (each one is done on the oscope, a screenshot is grabbed)
	    - variables to pull from include PN, name (dev/hw)
	  . list of signals for the bus.  these will be the variable names to assin the channels on the scope to, and also label for the channel
	  . this template will be used to make the Test Tab
	    . left section will have 4 columns and list the measurements to take
		  - 1 = checkbox to include this measurement
		  - 2 = measurement name (i.e. Tr, Tf for rise and fall time)
		  - 3 = button to set up scope badges 'Setup' with tip 'configure scope for measurement'
		  - 4 = button to capture measurement 'Capture' with tip 'Capture measurement on scope'
		. right section will be the signal names and scope channel selection
		  - first have a drop down of 1-4 for how many busses to measure
		  - under this will be the 2 column list
		    . this will be one set of signals for each bus iteration number above (1-4)
		    . column 1 = signal/net name (i.e. SCL or SDA)
			. column 2 = drop down selector for scope channel
		. below the left and right sections will be a run/pause button (play arrow/pause bars), back (rewind button), skip (forward button), and abort (stop button)
		. indicator fields - measurement info window
		  - put this stuff in the information picture frame
		  - which bus iteration is being measured (0=no iteration, do not include this in any screen capture information)
		  - chamber temperature - a signle reading when starting to measure
		  - which test measurement is being made
		  - message field for messages to the client
		. how it will work
		  - if the client pushes the setup or capture buttons then it will immediately perform the operation
		  - if the client pushes the play button to run the selected tests, then
		    . first iterate thru each bus number
			  - next iterate thru each selected test
			    . perform the scope setup scipt
				. change play button to play arrow to indicate we are paused.  update client message field telling them to verify measurement on scope and click play to continue
				. after user/client hits play again, then run scope capture script
			  - continue to next iteration
			. continue to next iteration
			. other button functions
			  - stop: abort all testing
			  - rewind - go back to previous measurement and redo it
			  - skip - skip current measurement and start working on the next one
		. all user settings in the tab will be saved to a special ini file with the name of the template file that created this tab.  example: i2c.txt, i2c.ini
	- each measurement script file
	  . named with main template file and measurement being taken.  example:  i2c_tf.txt
	  . two sections - setup and capture
	  . setup section adds all the badges and settings to the scope
	    - use signal net names as variables (i.e. $scl $sda...) in place of channel numbers so that we follow what the client specified for which channel is connected to which signal
		  . set the channel label to the signal name
		- use a variable like $bus for which bus number we are currently measuring
		- visa/scpi commands to set up the scope
		- variable like $f for bus frequency if needed (i.e. 100k, 400k, 1M)
		- variable $temp for chamber temperature setpoint (-5C 25C 70C)
		- set up all labels as well - title and such.  referr to MTF for title convension
	  . capture section
	    - use a variable to tell which folder the screenshot should be saved to
		  . append $temp, $f, $port, and any other information appropriate for the file name
		- pull measurements from the badges
		  . place them in an excel spreadsheet
		  . allow for a variable to specify the filename of the spreadsheet
		  . allow for it to place each measurement in a specific sheet, row, and column of the spreadsheet
		  . check to see if we can edit both excel spreadsheets on a file location like local or coos
		  . check to see if we can also edit excel files on a shared onedrive link.  If so, then we can save the information directly to the test plan
		  . allow for arithmetic and expression evaluation so we can select column number from temperature setting, and other ideas
		  . for Jitter measurement, pull stddev and mean, put stddev first in the cell





	? add file browser tab for scope to transfer files to and from scope using visa,  ask ai to write it in autoit
	  now needs debug and initial tuning



	make each tab canvas able to pop out and become its own window
    - add extra ctrls list to oCanvan,
	  . change aCtrls to aCanvasCtrls
	  . make aTabCtrls for the controls outside of the canvas that belong to the tab
	  . set zoom function will adjust one or the other depending on where the mouse is (inside the canvas or the main window tab area)
	  . when you pop out the tab, create a new temporary window canvas to contain the viewport and a tab section on top with the tab controls
	  . also adjust to zoom on the main window for the control bar at the bottom - scale the vertical offset of the control bar based on the zoom
    -
	- change from one view port to each tab having its own viewport
	- add a flag in the oCanvas to indicate if canvas is inside or outside the main window
	- adjust how WM_SIZE, WM_MOUSEWHEEL, WM_VSCROLL, WM_HSCROLL and other events affect the window
	  . hWnd will point to the outside window instead of hMainGui
	  . resize calculations will need to shift their margin to not include the tab enclosure
	- save all window positions in the ini file
	- key: click and drag tab selector tab outside of main window to pop out.
	- minimize window or drag and drop on main window to pop back in
	- if popped out then leave tab area shown in main window with a single button/message to click and pull it back in


	add master queue for a script that runs all instruments.  use simple id prefix for which instrument gets the visa command
	  dc - power supply
	  tc - thermal chamber
	  fc - frequency counter
	  sc - oscope
	  i.e.:  sc:visastring

	debug box needs debug - monitoring commands and results is not working
		debug edit box to enter script/visa commands and a combo select box to select which item to send it to
		another edit box to show the results, an execute button, save and load buttons for the edit field
		have this debug box only use the main queue



	; todo
	;
	;
	;

	; next steps:
	; - see if you can have it allow the separate tabs to undock from the main window and become their own window
	; - add a dashboard tab that will have
	;   . chamber temperature and setpoint and on/off button
	;   . power supply voltages, on/off status (grayed out if off, colored if on), and up/down sequence buttons
	;   . oscope screen capture button that will have a minature of the picture shown in the dashboard after it is captured
	;


	  all scripting commands possible - and create simple documentation for the scripting


	once we get all of that done, then look into converting to python.  make sure the visa/modbus comm and script queue is solid in python before proceeding
	use pywin32 for generic windows gui elements
	chatgpt or gemini can help do conversions so some of the stuff works like autoit commands, so the code does not look so messy

	finally, add manual test station scripts for i2c, spi, and clocks





	next steps 10/12/2026

	handle minimize - it caused the visa scan to fail

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










;






; Oscilloscope Tektronix MSO5 remote control and screenshot capture
;
;


#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Icon=mts.ico

Global $g_hMainGui, $g_cTab, $g_hTab
Global $g_oMainCanvas = ObjCreate("Scripting.Dictionary")
Global $g_cb_iH

Global $g_sTestProfile, $g_sTPiniFile = ""  													; test measurement tabs

Global $g_configFile, $g_configSection                                                          ; config file variables
Global $g_instConfigSection = "VISA_Devices"                                                    ; device list section
Opt("GUIOnEventMode", 1)                                                                        ; ACTIVATE ONEVENT MODE GLOBALLY BEFORE CREATING WINDOWS

#include <File.au3>
#include <AutoItConstants.au3>
#include <GuiComboBox.au3>
#include <GuiTab.au3>


OnAutoItExitRegister("MainExit")                ; register before any other exit functions so this one will be executed last

#include "visascpi.au3" ; visa functions(must be included before most other include files
#include "misc.au3" ; miscellaneous
#include "myconstants.au3" ; character And other misc constants
#include "winmgmt.au3" ; window manager functions
#include "tableEdit.au3" ; 2D array editor
#include "controlBar.au3" ; control bar below the main window For controlling Select visa devices



#cs
	Local $oDev = "192.168.0.14"
	Local $sR = __viReqBl($oDev,"*OPC?",true)
	Local $sR = __viReqBl($oDev,"*IDN?",true,2000)

	Exit
#ce

#cs
	; debug begin
	#include "visascpi.au3"


	Local $oDev = "192.168.0.16"
	Local $sR = __viReqBl($oDev,"*IDN?",true)

	Exit

	Local $oDev = "raw:192.168.0.25"
	Local $sR = __viReqBl($oDev,"*IDN?",true)

	$oDev = "192.168.0.14"
	Local $sR = __viReqBl($oDev,"*IDN?",true)

	Exit
	; debug end

#ce






ProgressOn("Hello from MTS suppliment", "Starting up", "", -1, -1, BitOR($DLG_NOTONTOP, $DLG_MOVEABLE))
ProgressSet(50)

ConfigFileInit("mts")

#include "tabOscope.au3" ; oscope tab
#include "tabFrequencyCounter.au3" ; frequency counter tab
#include "tabDCpowerSupply.au3" ; DC Power Supply tab
#include "tabChamber.au3" ; thermal chamber tab
#include "tabDiag.au3" ; visa / scpi debug tool
#include "tabOscopeFM.au3" ; oscope file manager tab
#include "tabMeasure.au3" ; measurment tab


CreateMainGUI()                                     ; create main gui window
GUISetState(@SW_SHOW, $g_hMainGui)                  ; show the main window

Local $hProgress = WinGetHandle("[TITLE:Hello; CLASS:AutoIt v3]")
WinSetOnTop($hProgress, "", $WINDOWS_ONTOP)         ; bring the progress dialog back above your Main GUI
ProgressSet(70)

Canvas_MainInit()                                   ; initialize the tab zoom feature
winmgmt_Init()                                      ; initialize Tabs, Zoom, Scrollbars and more
ProgressSet(80)

scTab_init()                                        ; initialize oscopeTab
fcTab_init()                                        ; initialize fcTab
dcTab_init()                                        ; initialize dcpsTab
tcTab_init()                                        ; initialize chamberTab
tpTab_init()                                        ; initialize tpTab
dgTab_init()                                        ; initialize dgTab
ProgressSet(90)

ControlBar_Init()                                   ; initialize the control bar, must be done after dcTab_init as it pulls labels from dcTab after it reads the config file

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
	__Canvas_Create($g_oMainCanvas, $aSize[0], $aSize[1])
	;__Canvas_Add($g_oMainCanvas, -1, -1)
	$g_oMainCanvas.Item('hCanvas') = $g_hMainGui
	Local $aCtrls[0], $n
	If $g_oMainCanvas.Exists('aTabCtrls') Then $aCtrls = $g_oMainCanvas.Item('aTabCtrls')
	$n = UBound($aCtrls)
	ReDim $aCtrls[$n + 1]
	$aCtrls[$n] = $g_hTab
	$g_oMainCanvas.Item('aTabCtrls') = $aCtrls
	;__Canvas_ZoomCatalog($g_oMainCanvas)
	__Canvas_ZoomCatalog($g_oMainCanvas, 'aTabCtrls')
EndFunc   ;==>Canvas_MainInit




Func CreateMainGUI()
	Local $V_WIDTH = 800
	Local $V_HEIGHT = 600
	Local $iCBH = 20
	$g_cb_iH = $iCBH

	$g_hMainGui = GUICreate("ManualTestStation", $V_WIDTH, $V_HEIGHT, -1, -1, _
			BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX))      ; main window

	$g_cTab = GUICtrlCreateTab(0, 0, $V_WIDTH, $V_HEIGHT - $iCBH)                                           ; Create the main Tab Control container
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKTOP, $GUI_DOCKLEFT, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM))             ; resize with entire window
	$g_hTab = GUICtrlGetHandle($g_cTab)

	TabCanvasCreate("Oscilloscope", "scTab_CanvasGuiCreate", "scTab_TabGuiCreate", _                        ; Tab 0
			$CANVASZOOMTYPE_MIN)

	TabCanvasCreate("Chamber", "tcTab_GuiCreate")                                                           ; Tab 1

	TabCanvasCreate("DC Power Supply", "dcTab_GuiCreate")                                                   ; Tab 2

	TabCanvasCreate("Frequency Counter", "fcTab_GuiCreate")                                                 ; Tab 3

	TabCanvasCreate("ScopeFM", "sfTab_GuiCreate")                                                           ; Tab 4

	GUICtrlCreateTabItem("Settings")                                                                        ; Tab 5

	TabCanvasCreate("I2C", "tpTab_GuiCreate", "", "", "I2C")                                                ; Tab 6

	;GUICtrlCreateTabItem("SPI")                                                                             ; Tab 7

	;GUICtrlCreateTabItem("Clocks")                                                                          ; Tab 8

	TabCanvasCreate("Diagnostic", "dgTab_GuiCreate", "", $CANVASZOOMTYPE_MIN)                               ; Tab 9

	GUICtrlCreateTabItem("")                                                                                ; Close the tab item definition structure

	CreateControlBar(0, $V_HEIGHT, $V_WIDTH, $iCBH)                                                         ; add aux control bar to bottom

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
	scTab_ConfigWrite()
	dcTab_ConfigWrite()
	tcTab_ConfigWrite()
	fcTab_ConfigWrite()
	dgTab_ConfigWrite()
	cb_ConfigWrite()
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
	IniWrite($g_configFile, $g_configSection, "ws", $g_oMainCanvas.Item('fzScale'))         ; main window zoom scale

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

	__IniWriteGui($g_cTab, "tab")
	;IniWrite($g_configFile, $g_configSection, "tab", GUICtrlRead($g_cTab))                  ; currently selected tab

	Instruments_ConfigWrite()
	Vars_ConfigWrite()
EndFunc   ;==>ConfigWrite




Func Instruments_ConfigWrite()
	__IniWriteArray($g_aVisaDevices, "i", $g_instConfigSection)
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
	scTab_ConfigRead()
	dcTab_ConfigRead()
	tcTab_ConfigRead()
	fcTab_ConfigRead()
	dgTab_ConfigRead()
	__viScanDistribute()
	cb_ConfigRead()
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
	$g_aVisaDevices = __IniReadArray($g_aVisaDevices, "i", $g_instConfigSection)
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

