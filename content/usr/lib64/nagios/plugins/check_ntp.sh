#!/bin/bash

DIR=`/usr/bin/dirname $0`

NTP_SERVER=`/bin/grep ^server /etc/ntp.conf | /bin/awk '{print $2}' | /bin/grep -v ^127\.`

OUTPUT=`$DIR/check_ntp -H $NTP_SERVER $1 $2 $3 $4`
RC=$?

/bin/echo -e "$OUTPUT"

exit $RC
