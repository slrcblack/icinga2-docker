#!/bin/bash

STATUS=OK
WARNING=$1
CRITICAL=$2

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify warning and critical arguments."
  exit 1
fi

COUNT=`/bin/ps -eLf | /bin/grep "jsvc\.exec" | /bin/grep -v grep | /usr/bin/wc -l`

[ "$COUNT" -ge "$WARNING" ] && STATUS="WARNING"
[ "$COUNT" -ge "$CRITICAL" ] && STATUS="CRITICAL"
[ "$COUNT" -eq 0 ] && STATUS="CRITICAL"

echo "$STATUS - $COUNT jsvc.exec threads. W=$WARNING, C=$CRITICAL|count=$COUNT;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac

