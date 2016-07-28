#!/bin/bash
# Niles Ingalls ningalls@ena.com
# look for filtering activity in the logs.  If we have no activity, alert someone. 

# most recent log
LOG="$(ls -t /usr/local/netsweeper/logs/nslogger_requests*.log | head -1)"

# grab alias ip address
ETHADDR="$(/sbin/ifconfig eth2:0 | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}')"

# exclude traffic sourced from our alias ip, and return the most recently seen date/time
NSLOGDATE="$(/usr/local/netsweeper/bin/nslog -t -n 100 $LOG | grep -v '$ETHADDR' | grep -Eo '^[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*:[0-9]*' | tail -n 1)" # grab most recent date, excluding from icinga checks

# convern most recently seen date/time into unix timestamp
SEEN="$(date +"%s" --date="$NSLOGDATE")"

# time in minutes to evaluate last seen/observed request
WARNIN=$1
CRITICALIN=$2

# unix timestamp of our date interval to be evaluated against the last seen/observed request
WARN="$(date +"%s" --date="$WARNIN minutes ago")"
CRITICAL="$(date +"%s" --date="$CRITICALIN minutes ago")"

if [ $CRITICAL -ge $SEEN ];
then
        echo "CRITICAL: last seen $NSLOGDATE"
        exit 2;
elif [ $WARN -ge $SEEN ];
then
        echo "WARNING: last seen $NSLOGDATE"
        exit 1;
else
        echo "OK: last seen $NSLOGDATE"
        exit 0;
fi
