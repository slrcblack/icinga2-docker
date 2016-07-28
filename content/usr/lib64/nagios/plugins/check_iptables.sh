#!/bin/bash

# exec >> /tmp/check_iptables.trace.$$ 2>&1
# set -x

STATUS=CRITICAL
ACTIVE="No"
LOG="No"

sudo /sbin/iptables -L INPUT > /tmp/iptables.out

/bin/egrep -q -e "^(REJECT|DROP)" /tmp/iptables.out
if [ "$?" -eq 0 ]; then
  ACTIVE="Yes"
  STATUS=OK
  /bin/grep -q "LOG level debug prefix" /tmp/iptables.out
  if [ "$?" -ne 0 ]; then
    STATUS=WARNING
  else
    LOG="Yes"
  fi
fi
/bin/rm -f /tmp.iptables.out

OUTPUT="Active=$ACTIVE, Log=$LOG"

/bin/echo "$STATUS - $OUTPUT"

case $STATUS in
  CRITICAL )
    exit 2;;
  WARNING )
    exit 1;;
  OK )
    exit;;
  * )
    exit;;
esac
