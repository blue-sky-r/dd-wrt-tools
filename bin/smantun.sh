#!/usr/bin/env bash

# Smart Antenna Tuning
# ====================
# DD-WRT wifi antenna position tuning utility - see usage help

# version
#
VER='2020.06.17'

# author
#
AUTH='Robert'

# github repository
#
REPO="https://github.com/blue-sky-r/dd-wrt-tools"

# copyright
#
COPY="= DD-WRT = Smart Antenna Tuning = (c) $VER by $AUTH ="

# DEFAULTS
# --------

# display statistics
#
STATS="mac,sig,noi,snr,q10"

# frequency offset in Hz
#
BEEP_LOW=100

# multiplication factor
#
BEEP_MULT=2

# beep length in ms
#
BEEP_LEN=50

# wget timeout in sec
#
TIMEOUT=3

# sleep between probes in sec
#
SLEEP=3

# characters for bar display
#
BAR='#_'

# kernel module for pc speaker
#
KMOD=pcspkr

# demo values (Q*10 values separated by comma)
#
DEMO="0,250,500,750,1000"

# filter only MAC (defualt no filtering)
#
MAC=

# debug/verbose output to stderr
#
DBG=

# END of DEFAULTS
# ---------------

# usage
#
[ $# -lt 1 ] && cat <<< """
$COPY

usage: $( basename $0 ) [-v] [-a mac] [-s 'c1,c2'] [-b 'xX'] [-l ms] [-o Hz] [-m k] [-r sec] [-d] ['q10,q10']] [-t sec] [router]

-v             ... verbose (debug) mode
-a|mac mac     ... filter only MAc address (case insensitive, partial match supported, watch out for masking MAC addr.)
-s[tats] c1,c2 ... display statistics (comma separated 3-char column names, default: $STATS)
                   mac = MAC address
                   sig = Signal dBm
                   noi = Noise dBm
                   snr = Signal to Noise Ratio
                   q10 = Quality percent * 10
-b[ar]         ... bar plot characters (default '$BAR', set to '' to disable plot)
-l[en]         ... beep length in ms (default $BEEP_LEN, set to 0 to disable beeping)
-o[ffset]      ... the lowest beep (offset) in Hz (default $BEEP_LOW)
-m[ult]        ... beep frequency multiplication (sensitivity) factor (default $BEEP_MULT)
-r[efresh]     ... update frequency in seconds, float accepted (default $SLEEP)
-d[emo]        ... demonstration mode (comma separated Q10 values, default '$DEMO')
-t[imeout]     ... router connection timeout in sec (default $TIMEOUT)
router         ... router/host as target client running DD-WRT with accessible info page (hostname or ip address)

Note: the beep freq. formula (Q is the signal quality between 0..100): frequency = mult x Q*10 + offset [Hz]

This script will display statistics, plot signal level (text-mode) and trigger audible beep reflecting signal quality.
This is very useful for router antenna adjustment as you don't need to watch the screen, just listen to the beeps.
The sound is generated by PC-SPEAKER. Make sure it is connected and functional.

Use demo mode to verify you can hear the beeping sound from your PC-SPEAKER clearly:

> $( basename $0 ) -d

> $( basename $0 ) -d '500,1000'

To supress bar plot just assign empty string to -b[ar] parameter:

> $( basename $0 ) -b '' router

To execute demo and real signal plot:

> $( basename $0 ) -d router

Quick (low precision) adjustment (refresh 0.5 sec):

> $( basename $0 ) -r 0.5 router

To suppress audible beeps (silent execution) just set beep length to 0:

> $( basename $0 ) -l 0 router

Display only Q10 and SNR statistics columns:

> $( basename $0 ) -s q10,snr 0 router

Filter only MAC XX:XX:XX:XX:56:78

> $( basename $0 ) -mac xx:56:78 router

This script executes infinite loop so use standard CTRL-C to stop and return to the command prompt.

REQUIRES:
- kernel module [ $KMOD ] (usually blackisted and not loaded so script will load module at the startup if required)
- connected and functional PC-SPEAKER
- beep executable
- wget, grep, awk
- dd-wrt running on the target router (connected to the access point)

The script does not make any changes to your system configuration. It loads kernel module [ $KMOD ] temporarily till the next reboot.
The kernel module stays loaded after the script has been ended so if you experience any [ $KMOD ] related problems
you might try to remove kernel module [ $KMOD ] manually by:

> sudo rmmod $KMOD

Tips:
- for quick antenna adjustment use fast refresh, but be aware that you are affecting the signal by your presence
- for high precision adjustment use slower refresh and always distance yourself from antenna after manipulation
- you can adjust multiplication factor for increased sensitivity, higher value will trigger bigger pitch change
- wifi card in your router needs some time to settle down so be smart with refresh speed
""" && exit 1

# FUNCTIONS
# =========

# Q10 = 10 * Quality <0-100> = <0 ... 1000>

# debug output to stderr
#
function debug()
{
    [ $DBG ] && >&2 echo 'DBG:' $@
}

# center text for optional width (100) with optional pad character (space)
#
function echo_center()
{
    local txt=$1
    local width=${2:-100}
    local padchr=${3:- }

    local len=$(( ($width - ${#txt} - 2)/2 ))
    local pad
    for i in $( seq $len ); do pad="$pad$padchr"; done

    printf "%s %s %s" "$pad" "$txt" "$pad"
}

# display signal plot 100 char wide (0-100%)
#
function visual_plot()
{
         local q10=$1
         local bar=$2

         [ -n "$bar" ] && for (( i=0; i<1000; i+=10 ))
         {
                  [ $i -le $q10 ] && echo -n ${bar:0:1} && continue
                  echo -n ${bar:1:1}
         }
}

# make beep (no sound if global $BEEP_LEN == 0)
#
function audible_signal()
{
         local q10=$1

         local f=$(( $BEEP_LOW + $BEEP_MULT * $q10 ))

         [ $BEEP_LEN -gt 0 ] && beep -l $BEEP_LEN -f $f && debug "beep($f Hz)"
}

# display statistics
#
function display_stats()
{
         local mac=$1
         local signal=$2
         local noise=$3
         local snr=$4
         local q10=$5

         for col in ${STATS//,/ }
         {
            [ "$col" == "mac" ] && printf "%17s " "$mac" && continue
            [ "$col" == "sig" ] && printf "%3s " "$signal" && continue
            [ "$col" == "noi" ] && printf "%3s " "$noise" && continue
            [ "$col" == "snr" ] && printf "%3s " "$snr" && continue
            [ "$col" == "q10" ] && printf "%4s " "$q10" && continue
         }
         printf "= "
}

# check if beep is installed (show msg and enforce silent mode if not)
#
function check_beep()
{
    ! which beep > /dev/null && BEEP_LEN=0 && echo "BEEP is not installed !"
}

# try to load kernel module if not loaded
#
function load_kmod()
{
    local module=$1

    while ! lsmod | grep -q "$module"
    do
        echo "Loading kernel module [ $module ], please provide sudo password ..."
        sudo modprobe $module
    done
}

# get JS fnc call from DD-WRT info page - section wireless / access point
# r22000M - 'xx:xx:xx:xx:25:87',   'eth1','0:02:45','104M','78M',       '-54','-79','25','490'
# r41328  - 'xx:xx:xx:xx:25:87','','wl0', '0:01:30','6M',  '19M','HT20','-52','-83','31','960'
function get_dd_wrt_wifi_table()
{
        local http=$1
        local mac=${2:-:}

        # get info page and grep setWirelessTable fnc call
        # setWirelessTable('xx:xx:xx:xx:25:87','','wl0','2:12:14','13M','26M','HT20','-55','-80','25','900');
        # setWirelessTable('xx:xx:xx:xx:CB:E7','','wl0','0:01:36','11M','18M','LEGACY','-71','-87','16','580');setWDSTable();setDHCPTable( 'ze4325','192.168.3.132','xx:xx:xx:xx:BE:08','0 days 00:00:00','132')
        
        wget -q --timeout=$TIMEOUT -O - "$http" \
        | sed 's/;set/;\nset/g' \
        | grep -o "setWirelessTable('\([0-9A-Fx]\{2\}:\)\{5\}[0-9A-Fx]\{2\}','.\+','[0-9]\+');" \
        | grep -o "'.*'" | sed -e "s/,\('\([0-9A-FX]\{2\}:\)\{5\}[0-9A-FX]\{2\}',\)/\n\1/g" \
        | grep -iF "$mac"

        #  MAC                    if    uptime    tx    rx    info   sig   noise snr  q*10
        # 'xx:xx:xx:xx:25:87','','wl0','2:12:14','13M','26M','HT20','-55','-80','25','900'

        #  MAC                 if     uptime    tx    rx   sig   noise snr  q*10
        # '10:BF:48:E6:71:E9','eth1','2:09:05','52M','39M','-55','-79','24','478','00:15:61:F1:CB:0A','eth1','
}

# get n-th value from table - (-1 = the last one, 1 = the first one)
#
function get_nth()
{
    local nth=$1
    local tab=$2

    echo "$tab" | awk -v nth=$nth -F, '{ print $(nth < 0 ? NF+nth+1 : nth) }' | tr -d \'
}

function header()
{
        local txt=$1

        # header
        display_stats 'MAC-address' 'Sig' 'Noi' 'SNR' 'Q*10'
        #visual_plot 1000 "$BAR"
        [ -n "$BAR" ] && echo_center "$txt"
        echo

        # separator
        display_stats "=================" "===" "===" "===" "===="
        [ -n "$BAR" ] && for i in $(seq 100); do echo -n "="; done
        echo
}


function test_run()
{
        local q10s=$1
        local mac='11:22:33:44:55:66'

        header "DEMO $q10s"

        for q10 in ${q10s//,/ }
        {
            display_stats "$mac" -78 -89 0 $q10
            visual_plot $q10 "$BAR"
            audible_signal $q10
            echo
            sleep $SLEEP
        }

        echo
}

# =======
#  MAIN
# ======

# check and load kernel module
#
load_kmod $KMOD

# parse cli pars
#
while [ $# -gt 0 ]
do
    case $1 in

    -v)
        DBG=1
        ;;

    -a|-mac)
        shift
        MAC=$1
        debug "PAR: mac($MAC)"
        ;;

    -s|-stats)
        shift
        STATS=$1
        debug "PAR: stats($STATS)"
        ;;

    -d|-demo)
        [ -n "$2" ] && [[ $2 =~ ^[0-9]+(,[0-9]+)* ]] && shift && DEMO=$1
        debug "PAR: demo($DEMO)"
        test_run "$DEMO"
        ;;

    -b|-bar)
        shift
        BAR=$1
        debug "PAR: bar($BAR)"
        ;;

    -l|-len)
        shift
        BEEP_LEN=$1
        debug "PAR: beep_len($BEEP_LEN)"
        ;;

    -o|-offset)
        shift
        BEEP_LOW=$1
        debug "PAR: beep_low($BEEP_LOW)"
        ;;

    -m|-mult)
        shift
        BEEP_MULT=$1
        debug "PAR: beep_mult($BEEP_MULT)"
        ;;

    -r|-refresh)
        shift
        SLEEP=$1
        debug "PAR: sleep($SLEEP)"
        ;;

    -t|-timeout)
        shift
        TIMEOUT=$1
        debug "PAR: timeout($TIMEOUT)"
        ;;

    *)
        # host
        URL=$1
        # add http proto prefix if not provided
        [[ $URL != http://* ]] && URL="http://$URL"
        debug "PAR: url($URL)"
        ;;

    esac

    shift
done

# exit if no host provided
[ -z "$URL" ] && exit

# check beep and force silent mode if not present
#
check_beep

# info line
#
echo "${COPY} stats columns: ${STATS} = demo: $DEMO = plot bar: $BAR ="
echo "= Filter MAC: ${MAC:- n/a} = BEEP freq: ${BEEP_MULT} x Q*10 + ${BEEP_LOW} Hz, length: ${BEEP_LEN} ms =" \
     "Refresh: ${SLEEP} s = http timeout: ${TIMEOUT} s = DD-WRT: $URL ="
echo

header "$URL"

# loop
#
while sleep $SLEEP
do

      # JS setWirelessTable() call with real values from dd-wrt info page
      #
      table=$( get_dd_wrt_wifi_table "$URL" "$MAC" )

      debug "setWirelessTable($table)"

      if [ -z "$table" ]
      then
            maca='- -'
            signal='-'
            noise='-'
            snr='-'
            q10=0
      else
            maca=$( get_nth 1 "$table" )
            signal=$( get_nth -4 "$table" )
            noise=$( get_nth -3 "$table" )
            snr=$( get_nth -2 "$table" )
            q10=$( get_nth -1 "$table" )
      fi

      display_stats "$maca" $signal $noise $snr $q10

      visual_plot $q10 "$BAR"

      audible_signal $q10

      echo
done
