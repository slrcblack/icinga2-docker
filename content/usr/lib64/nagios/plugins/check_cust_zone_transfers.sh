#!/bin/bash

STATFILE="/tmp/checkDNScustomerSlaving.out"

if [[ `/bin/find $STATFILE -mmin +60` = "$STATFILE" ]]; then
  /bin/echo "UNKNOWN - $STATFILE is stale.  Check cron for checkDNScustomerSlaving.sh script."
  exit 3
fi

STATUS=`/bin/awk '{print $1}' $STATFILE`

/bin/cat $STATFILE

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
