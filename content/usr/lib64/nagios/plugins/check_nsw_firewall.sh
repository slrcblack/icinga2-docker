#!/bin/bash
STATUS=UNKNOWN
IPTABLES=`sudo /sbin/iptables -L FORWARD -n | grep "dpt:80 PHYSDEV match --physdev-in eth1 " | wc -l`

if [ $IPTABLES = 1 ] ; then
  STATUS=OK

else STATUS=CRITICAL
fi

echo "$STATUS - IPTABLES returned $IPTABLES matches for dpt:80 PHYSDEV match --physdev-in eth1"

case $STATUS in
  CRITICAL )
    exit 2;;
  WARNING )
    exit 1;;
  OK )
    exit 0;;
  * )
    exit 0;;
esac
