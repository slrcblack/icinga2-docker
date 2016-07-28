#!/bin/bash

STATUS=OK
WARNING=$1
CRITICAL=$2

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify warning and critical arguments."
  exit 1
fi

TEST=`sudo /usr/bin/mailq`
if [[ $? -ne 0 ]]; then
  echo "Error running 'sudo /usr/bin/mailq'."
  exit 1
fi

REQUEST_NUM=`sudo /usr/bin/mailq | /bin/grep " TLS " | /usr/bin/wc -l | /bin/awk '{print $1}'`

[ "$REQUEST_NUM" -ge "$WARNING" ] && STATUS="WARNING"
[ "$REQUEST_NUM" -ge "$CRITICAL" ] && STATUS="CRITICAL"

echo "$STATUS - $REQUEST_NUM TLS message(s) queued|TLSmessages=$REQUEST_NUM;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac

