#!/bin/bash

# This check script works in conjunction with archiveMailboxCount.sh
# to read files in /tmp/archiveMailboxCount/$MAILBOX.

STATUS=OK
MAILBOX=$1
WARNING=$2
CRITICAL=$3

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify mailbox, warning and critical arguments."
  exit 1
fi

if [[ ! -e "/tmp/archiveMailboxCount/$MAILBOX" ]]; then
  /bin/echo "CRITICAL - File /tmp/archiveMailboxCount/$MAILBOX not found. Make sure archiveMailboxCount.sh is being run from cron."
  exit 2;
fi

COUNT=`/usr/bin/head -1 /tmp/archiveMailboxCount/$MAILBOX`

[ "$COUNT" -ge "$WARNING" ] && STATUS="WARNING"
[ "$COUNT" -ge "$CRITICAL" ] && STATUS="CRITICAL"

echo "$STATUS - $COUNT messages in $MAILBOX archive mailbox. W=$WARNING, C=$CRITICAL|count=$COUNT;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac

