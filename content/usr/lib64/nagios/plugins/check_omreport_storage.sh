#!/bin/bash

OMREPORT_COUNT=`/bin/ps | grep omreport | grep -v grep | grep -v check_omreport | wc -l`
if [ "$OMREPORT_COUNT" -gt 3 ]; then
 OMREPORT_PROCS=`/bin/ps | grep omreport | grep -v grep | grep -v check_omreport`
 echo "CRITICAL - $OMREPORT_COUNT omreport procs running.  OM may be hung! $OMREPORT_PROCS"
 exit 2
fi

OMREPORT=/usr/bin/omreport
if [ $# -eq 0 ]; then
  CONTROLLER=0
else
  CONTROLLER=$1
fi
SUMMARY="/tmp/omreport_storage_controller_${CONTROLLER}.txt"

. /etc/profile > /dev/null 2>&1

if [ ! -e "$OMREPORT" ]; then
  echo "CRITICAL - $OMREPORT command not found."
  exit 2;
fi

STATUS=OK

SYSTEM_SUMMARY=`/usr/bin/sudo /usr/bin/omreport storage controller controller=$CONTROLLER -outc $SUMMARY`
if [ $? -eq 0 ]; then
  CONTROLLER_ID=`grep -A 10 "^Controllers" $SUMMARY | grep "^ID" | /bin/cut -f2 -d ":"`
  CONTROLLER_STATUS=`grep -A 10 "^Controllers" $SUMMARY | grep "^Status" | /bin/cut -f2 -d ":"`
  CONTROLLER_SLOT=`grep -A 10 "^Controllers" $SUMMARY | grep "^Slot ID" | /bin/cut -f2 -d ":"`
  CONTROLLER_NAME=`grep -A 10 "^Controllers" $SUMMARY | grep "^Name" | /bin/cut -f2 -d ":"`
  CONTROLLER_STATE=`grep -A 10 "^Controllers" $SUMMARY | grep "^State" | /bin/cut -f2 -d ":"`
  OUTPUT="Controller${CONTROLLER_ID}${CONTROLLER_STATUS},${CONTROLLER_NAME}${CONTROLLER_SLOT}${CONTROLLER_STATE}"
else
  echo "WARNING - Error getting controller $CONTROLLER information."
  exit 1;
fi

if [ ! "${CONTROLLER_STATUS}" = " Ok" ]; then
  if [ "$STATUS" = "OK" ]; then
    STATUS="WARNING"
  fi
fi
if [ ! "${CONTROLLER_STATE}" = " Ready" ]; then
  if [ "$STATUS" = "OK" ]; then
    STATUS="WARNING"
  fi
fi

STORAGE_ERRORS=`egrep "(^State|^Status)" $SUMMARY | egrep -v "(Ok|Ready|Online|Learning|Non-Critical|Charging)" | wc -l`
STORAGE_REBUILDING=`egrep "(^State|^Status)" $SUMMARY | grep "Rebuilding" | wc -l`
if [ "$STORAGE_ERRORS" -gt 0 ]; then
  OUTPUT="$OUTPUT, $STORAGE_ERRORS storage errors"
  if [ "$STATUS" = "OK" ]; then
    STATUS="CRITICAL"
    if [ "$STORAGE_REBUILDING" -gt 0 ]; then
      OUTPUT="$OUTPUT, $STORAGE_REBUILDING rebuilding"
      STATUS="WARNING"
    fi
  fi
else
  OUTPUT="$OUTPUT, no storage errors"
fi

/bin/echo "$STATUS - $OUTPUT"

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
