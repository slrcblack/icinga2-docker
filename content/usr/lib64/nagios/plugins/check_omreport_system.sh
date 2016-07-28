#!/bin/bash

OMREPORT_COUNT=`/bin/ps | grep omreport | wc -l`
if [ "$OMREPORT_COUNT" -gt 5 ]; then
 echo "CRITICAL - $OMREPORT_COUNT omreport procs running.  OM may be hung!"
 exit 2
fi

OMREPORT=/usr/bin/omreport
SUMMARY="/tmp/omreport_system_summary.txt"

. /etc/profile > /dev/null 2>&1

if [ ! -e "$OMREPORT" ]; then
  echo "CRITICAL - $OMREPORT command not found."
  exit 2;
fi

STATUS=OK

SYSTEM_SUMMARY=`/usr/bin/sudo /usr/bin/omreport system summary -outc $SUMMARY`
HOSTNAME=`grep "^Host Name" $SUMMARY | /bin/cut -f2 -d ":"`
MODEL=`grep "^Chassis Model" $SUMMARY | /bin/cut -f2 -d ":"`
SERVICE_TAG=`grep "^Chassis Service Tag" $SUMMARY | /bin/cut -f2 -d ":"`

OUTPUT="$HOSTNAME,$MODEL,$SERVICE_TAG"

CHASSIS_ERRORS=`/usr/bin/omreport chassis | grep ":" | grep -v "^SEVERITY" | grep -v "^Ok" | wc -l`
if [ "$CHASSIS_ERRORS" -gt 0 ]; then
  OUTPUT="$OUTPUT, $CHASSIS_ERRORS chassis errors"
  if [ "$STATUS" = "OK" ]; then
    STATUS="WARNING"
  fi
else
  OUTPUT="$OUTPUT, no chassis errors"
fi


/bin/echo "$STATUS -$OUTPUT"

case $STATUS in
  CRITICAL )
    exit 2;;
  WARNING )
    exit 1;;
  OK )
    exit;;
  * )
    exit;;
esac
