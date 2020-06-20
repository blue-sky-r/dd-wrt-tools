#!/usr/bin/env bash

# Audible ASUS Ping
# =================
# Audible ping for ASUS routers - see usage help

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
COPY="= audible-asus-ping = (c) $VER by $AUTH ="

# DEFAULTS
# --------

# beep ok, Hz:ms
#
PING_HZ_MS="ttl=64:1000:50 ttl=100:750:100 *:500:100"

PING_OPT=

# kernel module for pc speaker
#
KMOD=pcspkr

# debug/verbose output to stdout
#
DBG=

# END of DEFAULTS
# ---------------

# usage
#
[ $# -lt 1 ] && cat <<< """
$COPY

usage: $( basename $0 ) [-v] [-aa 'ttL:hz:ms ttl2:hz2:m2 *:hz3:ms3'] [ping_opt] target

-v         ... verbose (debug) mode
-ok hz:ms  ...
ping_opt   ... other ping options apped to ping
target     ... target (hostname or ip address)

> $( basename $0 ) -mac xx:56:78 router

This script executes infinite loop so use standard CTRL-C to stop and return to the command prompt.

REQUIRES:
- kernel module [ $KMOD ] (usually blackisted and not loaded so script will load module at the startup if required)
- connected and functional PC-SPEAKER
- beep executable

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

# msg - debug or logger output
#
msg="true"

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

# beep according to TTL
#
function ttl_beep()
{
    local pingttl=$1

    for ttl_hz_ms in $PING_HZ_MS
    {
        local ttl=${ttl_hz_ms%%:*}
        local hz_ms=${ttl_hz_ms#*:}

        $msg "ttl_beep($pingttl) ttl($ttl) hz_ms($hz_ms)"

        [[ $pingttl == $ttl ]] && beep_hz_ms "$hz_ms" && break
    }
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
        msg="echo -e "
        ;;

    -aa)
        shift
        PING_HZ_MS=$1
        $msg "PAR: PING_HZ_MS($PING_HZ_MS)"
        ;;

    *)
        PING_OPT="$PING_OPT $1"
        ;;

    esac

    shift
done

$msg "PAR: PING_OPT($PING_OPT)"

# check beep and force silent mode if not present
#
check_beep

# loop
#
ok=0; err=0
while sleep 1
do

        ttl=$( ping -c 1 -W 1 $PING_OPT | grep -o "ttl=[[:digit:]]\+" )
        $msg "ping $PING_OPT -> returns($ttl)"
        # beep
        ttl_beep $ttl
        # statisctics
        [ -n "$ttl" ] && (( ++ok )) || (( ++err ))
        printf "\r OK: %4d / ERR: %4d " $ok $err
done
