#!/usr/bin/env bash

# Audible ASUS Ping
# =================
# Audible ping for ASUS routers - see usage help

# version
#
VER='2020.07.25'

# author
#
AUTH='Robert'

# github repository
#
REPO="https://github.com/blue-sky-r/dd-wrt-tools"

# copyright
#
COPY="= Audible-Asus-PING = (c) $VER by $AUTH ="

# DEFAULTS
# --------

# lookup table (ASUS specific): ttl:mode:beep_Hz:beep_ms
# note: use _ instead os spaces in mode field
TTL_MODE_HZ_MS="ttl=64:Normal:1000:50 ttl=100:TFTP_Recovery:500:100 \
ttl=63:Normal/L-1:900:50 ttl=99:TFTP_Recovery/L-1:400:100 *:no_response_?:200:100"

# limit number of pings
#
COUNT=0

# wait interval seconds between sending packets
#
INTERVAL=1

# pass-through ping options
#
PING_OPT=

# scroll output lines = no (one-line), all (always), err (only errors)
#
SCROLL='err'

# silent mode (default audible mode)
#
SILENT=0

# timestamp date format (empty for no timestamping)
#
DATE_FRM='%x %X'

# kernel module for pc speaker
#
KMOD=pcspkr

# END of DEFAULTS
# ---------------

# usage
#
[ $# -lt 1 ] && cat <<< """
$COPY

usage: $( basename $0 ) [-v][-aa 'ttL:mode:hz:ms ttl2:mode2:hz2:m2 *:mode3:hz3:ms3'][-scroll mode][-timestamp frm][-silent][-c count][-i interval][ping_opt] target

-v               ... verbose (debug) mode
-aa ttl=xx:mode:hz:ms ... audible settings where xx is the ttl to match to generate beep with frequency of hz Hz and
                          length of ms ms to pc speaker. Mode is descriptive information about mode (do not use spaces,
                          use _ in text, all undescores will be displayed as spaces). Multiple entries are separated by space,
                          the last entry should match all (* this will beep in case of any error). To make specific entry silent
                          use empty Hz and ms like ttl=123:no_sound_for_this_ttl:::
                          Default lookup table is:
                          $TTL_MODE_HZ_MS
-scroll mode     ... activate scroll mode (default $SCROLL, useful to see error distribution history), mode is:
                     all = always scroll with each ping
                     no  = never scroll, keep output limited to one-line
                     err = only scroll errors
                     anything else will keep default value ($SCROLL) unchanged
-timestamp frm   ... timestamping output, frm is date format or yes or no:
                     yes = use default format ($DATE_FRM), use if you want to be explicit
                     no  = no timestamps
                     frm = valid date format string, see man date for details
                     invalid string (without %) is treated as no timestamping
-silent          ... activate globally silent mode despite lookup table, only display output, no audible sound (default audible mode)
-c count         ... limit to count, stop after executing count pings (default $COUNT = infinite loop)
-i interval      ... wait interval between sending the packets (default each ${INTERVAL}s)
ping_opt         ... other ping options pass-through to ping
target           ... target (hostname or ip address)

> $( basename $0 ) target

This will execute infinite loop so use standard CTRL-C to stop and return to the command prompt.

> $( basename $0 ) -silent -scroll all -count 100 -s 12345 target

This will execute only 100 pings with packet size of 12345 in silent mode and scrolling everything output.

REQUIRES (only in audible mode):
- kernel module [ $KMOD ] (usually blackisted and not loaded so script will load module at the startup if required)
- connected and functional PC-SPEAKER
- beep executable

The script does not make any changes to your system configuration. It loads kernel module [ $KMOD ] temporarily till the next reboot.
The kernel module stays loaded after the script has been ended so if you experience any [ $KMOD ] related problems
you might try to remove kernel module [ $KMOD ] manually by:

> sudo rmmod $KMOD

NOTE:  default lookuo table TTL_MODE_HZ_MS is very ASUS centric. For diffenet manufacturer you have to find out
proper TTL responses and build your lookup table. My entire network runs exclusively on ASUS routers only ...
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
    # global silent mode
    [ $SILENT -eq 1 ] && return

    # empty parametes -> this one is silent
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

# conditional new-line for printout based on $TTL and dependent on global $SCROLL mode
#
function nl()
{
    local ttl=$1
    local n=$'\n'$'\r'

    # always scroll
    [[ $SCROLL == all ]] && echo "$n" && return
    # never scroll
    [[ $SCROLL == no  ]] && return
    # scroll only errors ( err || ok )
    #[[ $SCROLL == err ]] && { [[ -z $ttl ]] && echo "$n" || echo ''; }
    [[ $SCROLL == err ]] && [[ -z $ttl ]] && echo "$n"
}


# =======
#  MAIN
# ======

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
        shift
        case $1 in
        all|always|yes)
            SCROLL='all'
            ;;
        err|errors)
            SCROLL='err'
            ;;
        no|one-line)
            SCROLL='no'
            ;;
        esac
        $msg "PAR: scrolling mode $1 (SCROLL=$SCROLL)"
        ;;

    -si|-silent)
        SILENT=1
        $msg "PAR: silent mode activated (SILENT=$SILENT)"
        ;;

    -timestamp)
        shift
        [[ $1 == *%* || $1 != yes ]] && DATE_FRM=$1
        $msg "PAR: date format (DATE_FRM=$DATE_FRM)"
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

# dbg
#
$msg "PAR: PING_OPT($PING_OPT)"

# summary
#
echo "$COPY limit: $COUNT = each: ${INTERVAL}s = scroll: $SCROLL = timestamp: $DATE_FRM = silent: $SILENT = ping-options: ${PING_OPT% *} = target: ${PING_OPT##* } ="
echo "= lookup table [ttl=val:mode_text:Hz:ms]: $TTL_MODE_HZ_MS ="

# check and load kernel module
#
[ $SILENT -eq 0 ] && load_kmod $KMOD

# check beep
#
[ $SILENT -eq 0 ] && check_beep

# ping deadline = 2 x interval
#
deadline=$(( INTERVAL+INTERVAL ))

# main loop
#
min_avg_max="-/0/-"

for (( loop=1; loop<=$COUNT || $COUNT==0; ++loop))
{
        # conditional timestamp
        [[ $DATE_FRM = *%* ]] && ts=$(date +"$DATE_FRM ")
        # ping
        ping=$( ping -c 1 -w $deadline $PING_OPT )
        # extract ttl
        ttl=$(  echo "$ping" |  grep -o "ttl=[[:digit:]]\+" )
        # extract time
        time=$( echo "$ping" |  grep -o "time=[[:digit:]]\+\.\?[[:digit:]]\+" )
        # dbg
        $msg "ping $PING_OPT -> returns($ttl, $time)"
        # beep by the lookup table and get mode from lookup table
        mode=$( ttl_beep $ttl )
        # count statisctics
        [ -n "$ttl" ] && (( ++ok )) || (( ++err ))
        # calculate statistics - time=xx/min/avg/max
        min_avg_max=$( echo "$time/$min_avg_max" | awk -v N=$loop -F/ '/time=/ \
          { gsub("time=", "", $1); act=$1; \
            low  = $2; if (low  == "-" || act < low)  low  = act; \
            avg  = $3; avg = (avg * (N-1) + act) / N; \
            high = $4; if (high == "-" || act > high) high = act; \
            printf "%.2f/%.3f/%.2f", low,avg,high }' )
        # display stats
        printf '\r%sOK: %4d / ERR: %4d / %-6s %-9s ms [ %-s ms ] %s %s' \
            "$ts" "$ok" "$err" "$ttl" "$time" "$min_avg_max" "${mode//_/ }" "$(nl $ttl)"
        # sleep between pings for $INTERVAL
        sleep $INTERVAL
}

# output new-line
[[ $SCROLL != all ]] && echo

# statistics
echo "= stats = $COUNT iterations = rtt min/avg/max = $min_avg_max ms ="