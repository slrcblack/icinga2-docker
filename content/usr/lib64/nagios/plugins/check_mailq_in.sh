#!/bin/bash

STATUS=OK
WARNING=$1
CRITICAL=$2

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify warning and critical arguments."
  exit 1
fi

TEST=`sudo /usr/lib/sendmail -bp -OQueueDirectory=/var/spool/mqueue.in`
if [[ $? -ne 0 ]]; then
  echo "Error running 'sudo /usr/lib/sendmail'."
  exit 1
fi

REQUESTS=`sudo /usr/lib/sendmail -bp -OQueueDirectory=/var/spool/mqueue.in | /usr/bin/tail -1 | /bin/sed -s 's/\t//g'`
# Sendmail output "Total requests: 22"
# Postfix output  "-- 5220 Kbytes in 49 Requests."
if [ "$REQUESTS" = "${REQUESTS%%:*}" ]; then
  REQUEST_NUM=`sudo /usr/sbin/postqueue -p | /bin/egrep -e "^[0-9A-F]{12}\!" | /usr/bin/wc -l | /bin/awk '{print $1}'`    #  <-- Postfix
  REQUESTS="Inbound queue: $REQUEST_NUM messages"
else
  REQUEST_NUM=${REQUESTS##*: }    #   <-- Sendmail output has colon
fi
[[ -z "$REQUEST_NUM" ]] && REQUEST_NUM=0

[ "$REQUEST_NUM" -ge "$WARNING" ] && STATUS="WARNING"
[ "$REQUEST_NUM" -ge "$CRITICAL" ] && STATUS="CRITICAL"

echo "$STATUS - $REQUESTS|requests=$REQUEST_NUM;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
