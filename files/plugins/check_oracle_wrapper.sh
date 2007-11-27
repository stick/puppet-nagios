#!/bin/sh

if [ -f /etc/profile.d/oracle.sh ]; then
	source /etc/profile.d/oracle.sh
else
	echo "Can't find /etc/profile.d/oracle.sh"
fi

/usr/lib/nagios/plugins/check_oracle $*
