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

REQUESTS=`sudo /usr/bin/mailq | /usr/bin/tail -1 | /bin/sed -s 's/\t//g'`
# Sendmail output "Total requests: 22"
# Postfix output  "-- 5220 Kbytes in 49 Requests."
if [ "$REQUESTS" = "${REQUESTS%%:*}" ]; then
  REQUEST_NUM=`/bin/echo $REQUESTS | /bin/awk '{print $5}'`    #  <-- Postfix
else
  REQUEST_NUM=${REQUESTS##*: }    #   <-- Sendmail output has colon
fi
[[ -z "$REQUEST_NUM" ]] && REQUEST_NUM=0

[ "$REQUEST_NUM" -ge "$WARNING" ] && STATUS="WARNING"
[ "$REQUEST_NUM" -ge "$CRITICAL" ] && STATUS="CRITICAL"

/bin/echo "$STATUS - $REQUEST_NUM requests in queue|requests=$REQUEST_NUM;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
