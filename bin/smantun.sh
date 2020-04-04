#!/usr/bin/env bash

# Smart Antenna Tuning
# ====================
# DD-WRT wifi antenna position tuning utility


# CONFIG
# ------

# frequency offset in Hz
#
BEEP_LOW=100

#
#
BEEP_MULT=2

# beep length in ms
#
BEEP_LEN=50

# BEEP_HIGH = BEEP_LOW + 100 * BEEP_MULT * 10 * Q

# wget timeout in sec
#
TIMEOUT=3

# sleep between probes in sec
#
SLEEP=1

# characters for bar display
#
BAR='#_'

# kernel module for pc speaker
#
KMOD=pcspkr

# END of CONFIG
# -------------

# version
#
VER='2020.04.04'
AUTH='Robert Blue-Sky-r'
COPY="= DD-WRT = Smart Antenna Tuning = version $VER = (c) $AUTH ="
DBG=1

# usage
#
[ $# -lt 1 ] && cat <<< """
$COPY

usage: $( basename $0 ) [-t[est]] [-d[ebug]] [router]

-t[est]  ... diagnostic test (kernel module $KMOD, display formatted output)
-d[ebug] ... debug output
router   ... router/host with installed DD-WRT and accessible info page

""" && exit 1

# FUNCTIONS
# =========

# Q10 = 10 * Quality <0-100> = <0 ... 1000>

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

# make beep
#
function audible_signal()
{
         local q10=$1

         local f=$(( $BEEP_LOW + $BEEP_MULT * $q10 ))

         beep -l $BEEP_LEN -f $f
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

         printf "%17s %3s %3s %3s %4s = " $mac $signal $noise $snr $q10
}

# beep for signal quality 0% - 50% - 100% to demonstrate
#
function demo_beep()
{
         local slp=${1:-0.5}

         sound 0
         sleep $slp
         sound 500
         sleep $slp
         sound 1000
}

#
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
# 'xx:xx:xx:xx:25:87','','wl0','2:12:14','13M','26M','HT20','-55','-80','25','900'
function get_dd_wrt_wifi_table()
{
        local http=$1

        # get info page and grep setWirelessTable fnc call
        # setWirelessTable('xx:xx:xx:xx:25:87','','wl0','2:12:14','13M','26M','HT20','-55','-80','25','900');
        wget -q --timeout=$TIMEOUT -O - "$http" \
        | grep -o "setWirelessTable('\([0-9A-Fx]\{2\}:\)\{5\}[0-9a-fx]\{2\}','.\+','[0-9]\+');" \
        | grep -o "'.*'"

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

    echo "$tab" | awk -v nth=$nth -F, '{print $(nth < 0 ? NF+nth+1 : nth) )'
}

function header()
{
        # header
        display_stats 'MAC-address' 'Sig' 'Noi' 'SNR' 'Q*10'
        visual_plot 1000 "$BAR"
        echo
        for i in $(seq 34); do echo -n "="; done
        echo -n " = "
        [ -n "$BAR" ] && for i in $(seq 100); do echo -n "="; done
        echo
}


function test_run()
{
        local q10s=$1
        local delay=${2:-1}
        local mac='11:22:33:44:55:66'

        header

        for q10 in ${q10s//,/ }
        {
            display_stats "$mac" -99 -99 0 $q10
            visual_plot $q10 "$BAR"
            audible_signal $q10
            echo
            sleep $delay
        }
}

# ====
# MAIN
# ====

#
#
echo "$COPY"
echo

# check and load kernel module
#
load_kmod $KMOD

# parse cli pars
#
while [ $# -gt 0 ]
do
    case $1 in

    -t|-test)
        test_run "0,250,500,750,1000"
        ;;

    *)
        # host
        URL=$1
        # add http proto prefix if not provided
        [[ $URL != http://* ]] && URL="http://$URL"
        ;;

    esac
    shift
done

# exit if no host provided
[ -z "$URL" ] && exit

# loop
#
while sleep $SLEEP
do

      # JS setWirelessTable() call with real values from dd-wrt info page
      #
      table=$( get_dd_wrt_wifi_table "$URL" )

      mac=$( get_nth 1 "$table" )
      signal=$( get_nth -4 "$table" )
      noise=$( get_nth -3 "$table" )
      snr=$( get_nth -2 "$table" )
      q10=$( get_nth -1 "$table" )

      display_stats "$mac" $signal $noise $snr $q10

      visual_plot $q10

      audible_signal $q10
done
