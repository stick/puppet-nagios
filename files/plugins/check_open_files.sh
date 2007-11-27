#!/bin/sh
#
# $Id: check_open_files.sh,v 1.1 2006/04/04 17:54:29 cmacleod Exp $

usage() {
    echo "Usage:"
    echo "$0 [OPTIONS]"
    echo "Checks number of open file descriptors for a given process"
    echo
    echo "  OPTIONS:"
    echo "    -p        process name"
    echo "    -w        warning level" 
    echo "    -c        critical level"
    echo
    exit $1
}

while true; do
    case "$1" in
        --help)
            usage 0
            ;;
        -p)
            case "$2" in
                "") echo "No parameter specified for -p"; break;;
                *)  PROCESS_NAME=$2; shift 2;;
            esac;;
        -w)
            case "$2" in
                "") echo "No parameter specified for -w"; break;;
                *)  WARNING_LEVEl=$2; shift 2;;
            esac;;
        -c)
            case "$2" in
                "") echo "No parameter specified for -c"; break;;
                *)  CRITICAL_LEVEl=$2; shift 2;;
            esac;;
        "") break;;
        *) echo "Unknown keywords $*"; usage 1;;
    esac
done

[ -z "$PROCESS_NAME" ] && echo "Missing -p" && usage 1
[ -z "$WARNING_LEVEl" ] && echo "Missing -w" && usage 1
[ -z "$CRITICAL_LEVEl" ] && echo "Missing -c" && usage 1


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

if [ "$WARNING_LEVEl" -gt "$CRITICAL_LEVEl" ]; then
    echo "Unknown: Warning level ($WARNING_LEVEl) cannot be greater than critical level ($CRITICAL_LEVEl)"
    exit $STATE_UNKNOWN
fi

PID=$( pgrep -d, $PROCESS_NAME )
if [ -z "$PID" ]; then
    echo "Unknown: pid could not be determined from process name"
    exit $STATE_UNKNOWN
fi

if [ $( echo $PID | grep -c , ) -gt 0 ]; then
    echo "More than 1 pid matched process name ($PROCESS_NAME): unsupported"
    exit $STATE_UNKNOWN
fi

FDLIST=$( ls /proc/$PID/fd/ | wc -l )
if [ -z "$FDLIST" ]; then
    echo "Could not get a list of file descriptors for pid ($PID/$PROCESS_NAME)"
    exit $STATE_UNKNOWN
fi

if [ "$FDLIST" -ge "$WARNING_LEVEl" ] && [ "$FDLIST" -lt "$CRITICAL_LEVEl" ]; then
    echo "Warning: $PROCESS_NAME/$PID has $FDLIST open files"
    exit $STATE_WARNING
elif [ "$FDLIST" -ge "$CRITICAL_LEVEl" ]; then
    echo "Critical: $PROCESS_NAME/$PID has $FDLIST open files"
    exit $STATE_CRITICAL
else
    echo "OK: $PROCESS_NAME/$PID has $FDLIST open files"
    exit $STATE_OK
fi
