This code run in AutoIt https://www.autoitscript.com/site/

Chamber_Control controls the Test Equity F4T Thermal Chamber, giving readings of the
current temperature and controlling the target temperature setpoint.

DC_Power_Supply controls the Keysight N67... DC Power supply with 4 output channels

FrequencyCounter controls an Agilent Frequency counter with a specific script to have it
measure channel 1 for a given number of cycles and calculate Allan Deviation

Oscilloscope_Tek_MSO5 gives a control window into the MSO5 series Tektronics oscilloscope
(using the web interface on the scope).  It also has a screen capture function

All of these use VISA/SCPI commands to talk to the equipment over the network.
The Chamber control uses ModBusTCP as I was having trouble using SCPI commands to control
the chamber.

Each of these has a field to enter the IP address of the target device.  Next to it is a
search button that will search the 192.168.0.x subnet for devices, and give you a selection
list.
