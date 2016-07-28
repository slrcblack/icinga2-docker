#!/bin/bash

STATUS=OK

FILE="/tmp/virsh-list.out"

if [[ ! -s "$FILE" ]]; then
  /bin/echo "CRITICAL - Unable to read $FILE.  Check cron job that creates it."
  exit 2
fi

VMLIST=`/bin/cat $FILE`

COUNT=0
for VM in $VMLIST; do
  ((COUNT++))
done

[[ "$COUNT" -eq 0 ]] && STATUS=WARNING

echo "$STATUS -$VMLIST|count=$COUNT;0;0;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
