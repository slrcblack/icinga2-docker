#!/bin/bash

# Count the number of ESTABLISHED network connections.
# A high number has indicated a problem with the WAS HTTP Plugin.

WARN=$1
CRIT=$2

if [ -z "$WARN" ]; then
  WARN=200
fi

if [ -z "$CRIT" ]; then
  CRIT=300
fi

CONNECTIONS=`netstat -an | grep ESTABLISHED | wc -l | awk '{print $1}'`

STATUS=OK
OUTPUT="$CONNECTIONS established connections (warn=$WARN,crit=$CRIT)|connections=${CONNECTIONS}cns;$WARN;$CRIT;0"
if [ $CONNECTIONS -ge $WARN ]; then
  STATUS=WARNING
fi
if [ $CONNECTIONS -ge $CRIT ]; then
  STATUS=CRITICAL
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

