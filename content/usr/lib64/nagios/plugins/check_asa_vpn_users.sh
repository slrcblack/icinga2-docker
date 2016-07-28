#!/bin/bash

STATUS=OK

FILE="$1"

if [[ ! -e "$FILE" ]] || [[ ! -s "$FILE" ]]; then
  /bin/echo "CRITICAL - Unable to read $FILE.  Check cron job."
  exit 2
fi

USERS=`/bin/cat $FILE`

echo "$STATUS - USERS =${USERS%,}"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
