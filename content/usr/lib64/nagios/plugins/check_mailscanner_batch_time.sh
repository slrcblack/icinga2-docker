#!/bin/bash

STATUS=OK
WARNING=$1
CRITICAL=$2

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify warning and critical arguments."
  exit 1
fi

AVGSECS=`/usr/bin/tail -5000 /var/log/maillog | /bin/awk '/: Batch .* processed in / { OFMT = "%.0f"; total += $11; count++ } END { print total/count }'`

[ "$AVGSECS" -ge "$WARNING" ] && STATUS="WARNING"
[ "$AVGSECS" -ge "$CRITICAL" ] && STATUS="CRITICAL"

/bin/echo "$STATUS - $AVGSECS seconds average for MailScanner batch processing|avgsecs=$AVGSECS;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
