#!/bin/sh
#
# $Id: check_ntp_peers.sh,v 1.1 2005/09/09 17:27:46 cmacleod Exp $
# check ntp peers to insure they are using cdma
# stratum 1 ok everthing else is critical

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

NTP=$(which ntpdate)
NTP_OPTIONS='-sq'
SERVER=$1

usage() {
    echo "$0 [ntp server]"
    exit $STATE_UNKNOWN
}

[ -z "$SERVER" ] && usage

OUTPUT=$( $NTP $NTP_OPTIONS $SERVER )
STRATUM=$( echo $OUTPUT | awk -F, '{ print $2 }' | awk '{ print $2 }' )

if [ -n "$OUTPUT" ]; then
    if [ "$STRATUM" -eq 1 ]; then
        echo "OK: $OUTPUT"
        exit $STATE_OK
    else
        echo "CRITICAL: $OUTPUT"
        exit $STATE_CRITICAL
    fi
else
    echo "UNKNOWN: $OUTPUT"
    exit $STATE_UNKNOWN
fi

