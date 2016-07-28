#!/bin/bash

PROGNAME=`/bin/basename $0 .sh`

#exec >> /tmp/debug.trace.last 2>&1
#set -x

HOST=$1
if [[ -z "$HOST" ]]; then
  /bin/echo "Please specify a Bluecoat hostname to check."
  exit 1
fi

URL="https://${HOST}:8082/policy_import_listing.html"
OUT="/tmp/${PROGNAME}.${HOST}.out"

/usr/bin/wget --http-user=admin --http-password='t)inHasdam' --no-check-certificate --tries=1 --output-document=$OUT $URL 2> /dev/null

TEMP=`/bin/grep "There were " $OUT`
if [[ $? -eq 0 ]]; then
  /bin/rm -f $OUT
else
  /bin/echo "CRITICAL - error getting output from $URL."
  exit 2
fi
OUTPUT=${TEMP##*>}    # Remove the HTML tags from the left side if it exists
#$OUTPUT="There were 0 errors and 2 warnings"
ERRORS=`/bin/echo $OUTPUT | /bin/awk '{print $3}'`
WARNINGS=`/bin/echo $OUTPUT | /bin/awk '{print $6}'`

STATUS=OK
[[ "$WARNINGS" -ne 0 ]] && STATUS=WARNING
[[ "$ERRORS" -ne 0 ]] && STATUS=CRITICAL

echo "$STATUS - $OUTPUT|errors=$ERRORS,warnings=$WARNINGS"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
