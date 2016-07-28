#!/bin/bash

STATUS=OK
WARNING=$1
CRITICAL=$2

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify warning and critical arguments."
  exit 1
fi

FILE="/var/www/html/load"

if [[ ! -s "$FILE" ]]; then
  /bin/echo "Unable to read load value from $FILE."
  exit 2
fi

LOAD=`/bin/cat $FILE`

[ "$LOAD" -ge "$WARNING" ] && STATUS="WARNING"
[ "$LOAD" -ge "$CRITICAL" ] && STATUS="CRITICAL"

echo "$STATUS - Kemp adaptive load balancing value is $LOAD.|load=$LOAD;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac

