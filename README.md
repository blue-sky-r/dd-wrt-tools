# dd-wrt-tools

Various command line CLI tools related to DD-WRT but intended for use on linux desktop (console).

scripts:

* [smantun](bin/smatun "Tools for Tuning the Antenna")  - Smart Antenna Tuning tool for linux CLI
* colog - colorize and enrich dd-wrt remote log file

---

# smantun = sma-ant-tun = smart antenna tuning

CLI (console) script to display client wifi parameters (Signal dBm, Noise floor dBm, SNR ratio, Quality) and semi-graphical 
signal quality bar plot as well as audible beeping (with pitch related to signal Quality). Many
configurable options (with sensible default values) are useful for adjusting the antenna / router
position to maximize signal quality (coverage). To get usage help simply run the script without any parameter:

    = DD-WRT = Smart Antenna Tuning = (c) 2020.04.07 by Robert =
    
    usage: smantun.sh [-v] [-b[ar] 'xX'] [-l[en] ms] [-o[ffset] Hz] [-m[ult] k] [-r[efresh] sec] [-d[emo] ['q10,q10']] [-t[imeout] sec] [router]
    
    -v         ... verbose (debug) mode
    -b[ar]     ... bar plot characters (default '#_', set to '' to disable plot)
    -l[en]     ... beep length in ms (default 50, set to 0 to disable beeping)
    -o[ffset]  ... the lowest beep (offset) in Hz (default 100)
    -m[ult]    ... beep frequency multiplication (sensitivity) factor (default 2)
    -r[efresh] ... update frequency in seconds, float accepted (default 3)
    -d[emo]    ... demonstration mode (comma separated Q10 values, default '0,250,500,750,1000')
    -t[imeout] ... router connection timeout in sec (default 3)
    router     ... router/host as target client running DD-WRT and with accessible info page (hostname or ip address)    
    
    Note: the beep freq. formula (Q is the signal quality between 0..100): frequency = offset + 10 * Q * mult
    
    This script will display statistics, plot signal level (text-mode) and trigger audible beep reflecting signal quality.
    This is very useful for router antenna adjustment as you don't need to watch the screen, just listen to the beeps.
    The sound is generated by PC-SPEAKER. Make sure it is connected and functional. Use demo mode to verify
    you cen hear the beeping sound from your PC-SPEAKER clearly:
    
    > smantun.sh -d
    
    > smantun.sh -d '500,1000'
    
    To supress bar plot just assign empty string to -b[ar] parameter:
    
    > smantun.sh -b '' router
    
    To execute demo and real signal plot:
    
    > smantun.sh -d router
    
    Quick (low precision) adjustment (refresh 0.5 sec):
    
    > smantun.sh -r 0.5 router
    
    To suppress audible beeps (silent execution) just set beep length to 0:
    
    > smantun.sh -l 0 router
    
    This script executes infinite loop so use standard CTRL-C for stop and return to the command prompt.
    
    REQUIRES:
    - kernel module [ pcspkr ] (usually blackisted and not loaded so script will load module at the startup if required)
    - connected and functional PC-SPEAKER
    - wget, grep, awk
    - dd-wrt running on the target router (connected to the access point)
    
    The script does not make any changes to your system configuration. It loads kernel module [ pcspkr ] temporarily till the next reboot.
    The kernel module stays loaded after the script has been ended so if you experience any [ pcspkr ] related problems
    you might try to remove kernel module [ pcspkr ] manually by:
    
    > sudo rmmod pcspkr
    
    Tips:
    - for quick antenna adjustment use fast refresh, but be aware that you are affecting the signal by your presence
    - for high precision adjustment use slower refresh and always distance yourself from antenna after manipulation
    - you can adjust multiplication factor for increased sensitivity, higher value will trigger bigger pitch change
    - wifi card in your router needs some time to settle down so be smart with refresh speed
    
### smantun - dd-wrt
   
The wireless parameters are from DD-WRT info page - section Wireless - Access Point.
Therefore it is mainly for Client / Client-Bridge mode on the target router. However
with a little creativity you can use temporary dd-wrt client to adjust the antenna
on AP (access point) to get optimal coverage. Of course you can connect remotely to the
target router to monitor Q (quality) which is very handy in case of wifi inter-building
crossing link. You got the idea ...

    Note: DD-WRT is using Q!0 as parameter for quality, which is just 10 * Q. 
    So when quality is 0..100% the 10x multiplication Q10 is 0..1000.
 
The Signal Quality Q is internally processed by DD-WRT and it is build version dependent.
So the same SNR (signal-to-noise-ratio) value will display different quality Q in different
dd-wrt build. This might be caused by various factors like different wifi
drivers so don't get obsessed with absolute number, just look for relative changes (Q dropping vs Q rising). 

![dd-wrt info page](screen/dd-wrt-info-wifi.png)

### smantun - implementation

The simplified workflow:
* the required kernel module is loaded if needed 
* the html page is retrieved by wget and java script function call setWirelessTable() is filtered out
* numerical parameter Signal [dBm], Noise [dBm], SNR, Q10 [%] are extracted from JS setWirelessTable() call
* values are diplayed as numbers in columns: MAC address, Signal, Noise, SNR, Q10
* optional signal plot bar is displayed with fixed width 100 chars (1 char = 1 %)
* optional audible beep is generated through PC speaker
* loop forever (until CTRL+C)

[smantun video - screen recording](screen/smantun.mp4 "video")

[![click to play video](screen/smantun.png)](https://raw.github.com/blue-sky-r/dd-wrt-tools/master/screen/smantun.mp4)

![smantun screenshot](screen/smantun.png)

### smantun - ideas for possible future improvements

* ANSI colors
* console auto-scaling (columns, width)
* PyQt graphical GUI
* sound generated by sound system (and not PC speaker, then kernel module will not be required)
* optional history
* systray icon

---
