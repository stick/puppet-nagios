#!/bin/sh
# vi: ai sw=4 si ts=4:

LOGFILE=/var/log/nagios/notify.log
MAIL="/bin/mail -s"
PAGE="/usr/bin/qpage -s ${$this->net_gethostbyname(${qpage_server})}"
TEE="/usr/bin/tee -a"

( 
ALERT_CLASS=$1
case "$ALERT_CLASS" in
	host)
	;;
	service)
	;;
	*)
		echo "Unknown alert_class: $ALERT_CLASS" | $MAIL "Nagios Notification Problem" $NAGIOS_NAGIOSADMIN
		exit 255
	;;
esac

if [ "$ALERT_CLASS" = "host" ]; then

ACKNOWLEDGMENT="
Ack:
$NAGIOS_HOSTACKAUTHOR - $NAGIOS_HOSTACKCOMMENT
"

MAILBODY="
Notificaition Type: $NAGIOS_NOTIFICATIONTYPE
Host: $NAGIOS_HOSTNAME
State: $NAGIOS_HOSTSTATE
Address: $NAGIOS_HOSTADDRESS
Info: $NAGIOS_HOSTOUTPUT
https://$HOSTNAME/nagios/cgi-bin/extinfo.cgi?type=1&host=$NAGIOS_HOSTNAME

Date: $NAGIOS_LONGDATETIME
"

PAGEBODY="
$NAGIOS_NOTIFICATIONTYPE 
$NAGIOS_HOSTNAME is $NAGIOS_HOSTSTATE 
Address: $NAGIOS_HOSTADDRESS 
Info: $NAGIOS_HOSTOUTPUT 
$NAGIOS_LONGDATETIME 
"

SUBJECT="** $NAGIOS_NOTIFICATIONTYPE alert - $NAGIOS_HOSTALIAS is $NAGIOS_HOSTSTATE **"
fi

if [ "$ALERT_CLASS" = "service" ]; then
ACKNOWLEDGMENT="
Ack:
$NAGIOS_SERVICEACKAUTHOR reported $NAGIOS_SERVICEACKCOMMENT
"

MAILBODY="
Notification Type: $NAGIOS_NOTIFICATIONTYPE

Service: $NAGIOS_SERVICEDESC
Host: $NAGIOS_HOSTALIAS
Address: $NAGIOS_HOSTADDRESS
State: $NAGIOS_SERVICESTATE

Date/Time: $NAGIOS_LONGDATETIME
https://$HOSTNAME/nagios/cgi-bin/extinfo.cgi?type=2&host=$NAGIOS_HOSTNAME&service=$NAGIOS_SERVICEDESC

Additional Info:
$NAGIOS_SERVICEOUTPUT
"

PAGEBODY="
$NAGIOS_NOTIFICATIONTYPE 
$NAGIOS_HOSTNAME/$NAGIOS_SERVICEDESC is $NAGIOS_SERVICESTATE 
Address: $NAGIOS_HOSTADDRESS 
Info: $NAGIOS_SERVICEOUTPUT 
$NAGIOS_LONGDATETIME 
"

SUBJECT="** $NAGIOS_NOTIFICATIONTYPE alert - $NAGIOS_HOSTALIAS/$NAGIOS_SERVICEDESC is $NAGIOS_SERVICESTATE **"
fi

notify_by_page() {
	if [ ! -z "$DEBUG" ]; then
		echo "paging $NAGIOS_CONTACTEMAIL  ($NAGIOS_NOTIFICATIONTYPE/$NAGIOS_HOSTALIAS/$NAGIOS_SERVICEDESC/$NAGIOS_SERVICESTATE)"
	else
            EMAILPAGE=$( echo $NAGIOS_CONTACTPAGER | grep \@ )
            if [ -n "$EMAILPAGE" ]; then
		echo -e "$PAGEBODY" | $MAIL "$SUBJECT" $NAGIOS_CONTACTPAGER
            else
		echo -e "$PAGEBODY" | $PAGE $NAGIOS_CONTACTPAGER
            fi
	fi
}

notify_by_mail() {
	if [ ! -z "$DEBUG" ]; then
		echo "Sending mail to $NAGIOS_CONTACTEMAIL ($NAGIOS_NOTIFICATIONTYPE/$NAGIOS_HOSTALIAS/$NAGIOS_SERVICEDESC/$NAGIOS_SERVICESTATE)"
	else
		echo -e "$MAILBODY" | $MAIL "$SUBJECT" $NAGIOS_CONTACTEMAIL
	fi
}

case "$NAGIOS_NOTIFICATIONTYPE" in
	RECOVERY)
	    # We always send email
		notify_by_mail
		# if a service do some special stuff since we handle warnings differently then other notifications
	    if [ "$ALERT_CLASS" = "service" ]; then
			# don't page if we are sending a warning recovery
			if [ "$NAGIOS_SERVICESTATE" != "WARNING" ]; then
				# here we check timestamps of certain states to determine if we want to send a page or not
				# if the last stage not a warning send a page
				if [ "$NAGIOS_LASTSERVICEWARNING" -le "$NAGIOS_LASTSERVICECRITICAL" ]; then
					notify_by_page
				fi
			fi
	    else
			notify_by_page
	    fi
	;;
	PROBLEM|FLAPPING*)
	    # We always send email
		notify_by_mail
		# don't page if it's a warning
	    if [ "$NAGIOS_SERVICESTATE" != "WARNING" ]; then
			notify_by_page
	    fi
	;;
	ACKNOWLEDG?MENT)
		MAILBODY="$MAILBODY\n$ACKNOWLEDGMENT"
		PAGEBODY="$PAGEBODY\n$ACKNOWLEDGMENT"
		notify_by_mail
		# if a service do some special stuff since we handle warnings differently then other notifications
	    if [ "$ALERT_CLASS" = "service" ]; then
			# don't page if we are sending a warning ack
			if [ "$NAGIOS_SERVICESTATE" != "WARNING" ]; then
				# here we check timestamps of certain states to determine if we want to send a page or not
				# if the last stage not a warning send a page
				if [ "$NAGIOS_LASTSERVICEWARNING" -le "$NAGIOS_LASTSERVICECRITICAL" ]; then
					notify_by_page
				fi
			fi
	    else
			notify_by_page
	    fi
	;;
	*)
		echo "Unknown notification type: $NAGIOS_NOTIFICATIONTYPE" | $MAIL $NAGIOS_NAGIOSADMIN
		exit 255
	;;
esac
) 2>&1 | $TEE $LOGFILE
