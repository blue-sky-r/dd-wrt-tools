#!/usr/bin/env bash

# Audible ASUS Ping
# =================
# Audible ping for ASUS routers - see usage help

# version
#
VER='2020.06.24'

# author
#
AUTH='Robert'

# github repository
#
REPO="https://github.com/blue-sky-r/dd-wrt-tools"

# copyright
#
COPY="= audible-asus-ping = (c) $VER by $AUTH ="

# DEFAULTS
# --------

# lookup table: ttl:mode:beep_Hz:beep_ms
# note: use _ instead os spaces in mode field
TTL_MODE_HZ_MS="ttl=64:Normal/Working:1000:50 ttl=100:TFTP_Recovery:750:100 *:Unknown:500:100"

# limit number of pings
#
COUNT=0

# wait interval seconds between sending packets
#
INTERVAL=1

# pass-through ping options
#
PING_OPT=

# kernel module for pc speaker
#
KMOD=pcspkr

# END of DEFAULTS
# ---------------

# usage
#
[ $# -lt 1 ] && cat <<< """
$COPY

usage: $( basename $0 ) [-v] [-aa 'ttL:mode:hz:ms ttl2:mode2:hz2:m2 *:mode3:hz3:ms3'] [-c count] [-i interval] [ping_opt] target

-v               ... verbose (debug) mode
-aa ttl=xx:mode:hz:ms ... audible settings where xx is the ttl to match to generate beep with frequency of hz Hz and
                          length of ms ms to pc speaker. Mode is descriptive information about mode (do not use spaces,
                          use _ in text, all undescores will be displayed as spaces). Multiple entries are separated by space,
                          the last entry should match all (* this will beep in case of any error).
                          Default table is:
                          $TTL_MODE_HZ_MS
-scroll          ... scroll mode (default one-line mode), useful to see history
-c count         ... stop after executing count pings (default $COUNT = infinite loop)
-i interval      ... wait interval between sending the packets (default $INTERVAL)
ping_opt         ... other ping options pass-through to ping
target           ... target (hostname or ip address)

> $( basename $0 ) target

This script executes infinite loop so use standard CTRL-C to stop and return to the command prompt.

REQUIRES:
- kernel module [ $KMOD ] (usually blackisted and not loaded so script will load module at the startup if required)
- connected and functional PC-SPEAKER
- beep executable

The script does not make any changes to your system configuration. It loads kernel module [ $KMOD ] temporarily till the next reboot.
The kernel module stays loaded after the script has been ended so if you experience any [ $KMOD ] related problems
you might try to remove kernel module [ $KMOD ] manually by:

> sudo rmmod $KMOD

""" && exit 1

# FUNCTIONS
# =========

# msg - debug or no output
#
msg="true"

# check if beep is installed (show msg and enforce silent mode if not)
#
function check_beep()
{
    ! which beep > /dev/null && echo "BEEP is not installed !"
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

# beep Hz:ms (freq.Hz for ms)
#
function beep_hz_ms()
{
    # empty parametes -> silent mode
    [ -z "$1" ] && return

    local hz=${1%:*}
    local ms=${1#*:}

    $msg "beep_hz_ms($1) hz($hz) ms($ms)"

    beep -f $hz -l $ms
}

# beep according to TTL and return mode to display
#
function ttl_beep()
{
    local pingttl=$1

    # iterate ttl:mode:hz:ms lookup table
    for entry in $TTL_MODE_HZ_MS
    {
        # split lookup table entry to pieces
        local ttl=${entry%%:*}
        local mode_hz_ms=${entry#*:}
        local mode=${mode_hz_ms%%:*}
        local hz_ms=${mode_hz_ms#*:}

        $msg "ttl_beep($pingttl) entry($entry) -> ttl($ttl) mode_hz_ms($mode_hz_ms) mode($mode) hz_ms($hz_ms)"

        [[ $pingttl == $ttl ]] && beep_hz_ms "$hz_ms" && break
    }

    # return mode
    echo "mode=$mode"
}

# =======
#  MAIN
# ======

# check and load kernel module
#
load_kmod $KMOD

# printout mode
# single line (default)
head=$'\r'; tail=' '
# scroll
#head=' '; tail=$'\n'

# parse cli pars
#
while [ $# -gt 0 ]
do
    case $1 in

    -v)
        msg="echo -e "
        ;;

    -aa)
        shift
        TTL_MODE_HZ_MS=$1
        $msg "PAR: TTL_MODE_HZ_MS($TTL_MODE_HZ_MS)"
        ;;

    -sc|-scroll)
        head=' '; tail=$'\n'
        $msg "PAR: scroll mode activated"
        ;;

    -c)
        shift
        COUNT=$1
        $msg "PAR: COUNT($COUNT)"
        ;;

    -i)
        shift
        INTERVAL=$1
        $msg "PAR: INTERVAL($INTERVAL)"
        ;;

    *)
        PING_OPT="$PING_OPT $1"
        ;;

    esac

    shift
done

$msg "PAR: PING_OPT($PING_OPT)"

# check beep
#
check_beep

# infinite loop
#
ok=0; err=0; loop=0
while sleep $INTERVAL
do
        (( ++loop ))
        ping=$( ping -c 1 -w $INTERVAL $PING_OPT )
        ttl=$(  echo "$ping" |  grep -o "ttl=[[:digit:]]\+" )
        time=$( echo "$ping" |  grep -o "time=[[:digit:]]\+\.\?[[:digit:]]\+" )
        $msg "ping $PING_OPT -> returns($ttl, $time)"
        # beep by the lookup table and get mode from lookup table
        mode=$( ttl_beep $ttl )
        # count statisctics
        [ -n "$ttl" ] && (( ++ok )) || (( ++err ))
        # display stats
        printf '%sOK: %4d / ERR: %4d / %-6s %-9s %s %s' "$head" $ok $err "$ttl" "$time" "${mode//_/ }" "$tail"
        # limit number of packets to count
        [ $COUNT -gt 0 ] && [ $loop -ge $COUNT ] && break
done
