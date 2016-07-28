#!/bin/bash

# This script requires read access to the /var/log/maillog as the user running it.  i.e. nrpe    Hint: logrotate

SNAT=`sudo /sbin/iptables -t nat -L POSTROUTING | /bin/grep ^SNAT | /bin/awk '{print $6}' | /bin/sed -e 's/to://'`
LASTBYTE=${SNAT##*.}


OUT=`/usr/bin/tail -100000 /var/log/maillog | /bin/egrep -e "to=<.*@yahoo\.com>" | /usr/bin/tail -100`

/bin/echo "$OUT" | /bin/grep -q "status=sent"
if [[ $? -eq 0 ]]; then
  /bin/echo "OK - Yahoo is accepting email from ${SNAT}.|IP=$LASTBYTE"
  exit 0
fi

/bin/echo "$OUT" | /bin/grep -q "temporarily deferred"
if [[ $? -eq 0 ]]; then
  /bin/echo "WARNING - Yahoo is temporarily deferring email from ${SNAT}.|IP=$LASTBYTE"
  exit 1
fi

/bin/echo "$OUT" | /bin/grep -q "permanently deferred"
if [[ $? -eq 0 ]]; then
  /bin/echo "CRITICAL - Yahoo is permanently deferring email from ${SNAT}.|IP=$LASTBYTE"
  exit 2
fi
