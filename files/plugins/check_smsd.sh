#!/bin/bash
smsd_proc=$(ps auxww |grep smsd |wc -l)
failed_file=$(/usr/bin/find /var/spool/sms/failed -type f -amin -5)
if [ -s "\${failed_file}" ] ; then
	echo "CRITICAL :SMSD was not able to deliver the file $failed_file. Please check smsd on smsgateway.pnq "
	exit 2
elif [ $smsd_proc -lt 1 ] ; then
	echo "CRITICAL:No smsd process running"
	exit 2
else 
	echo "OK :SMSD working"
	exit 0 
fi
