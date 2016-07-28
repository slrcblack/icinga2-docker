#!/bin/bash

STATUS=OK

FILE="/tmp/virsh-list.out"

if [[ ! -e "$FILE" ]]; then
  /bin/echo "CRITICAL - Unable to read $FILE.  Check cron job."
  exit 2
fi

VMLIST=`/bin/cat $FILE`

COUNT=0
for VM in $VMLIST; do
  ((COUNT++))
done

if [[ "$COUNT" -eq 0 ]]; then
  STATUS=WARNING
  VMLIST=" no VMs running"
fi

/bin/grep "(undefined)" $FILE && STATUS=WARNING

echo "$STATUS - $COUNT VMs -$VMLIST|count=$COUNT;0;0;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
