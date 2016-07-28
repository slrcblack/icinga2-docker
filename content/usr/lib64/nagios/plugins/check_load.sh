#!/bin/bash

# exec >> /tmp/check_load.trace.$$ 2>&1
# set -x

STATUS=CRITICAL

if [ -e "/usr/lib64/nagios/plugins/check_load" ] ; then
  LOAD=`/usr/lib64/nagios/plugins/check_load -w $1 -c $2`
else
  LOAD=`/usr/lib/nagios/plugins/check_load -w $1 -c $2`
fi
RC=$?
OUTPUT=$LOAD
case $RC in
  1 )
    TOP=`top -b -n 1 | head -12 | tail -6 | awk 'ORS="<br>" {print $1,"\t",$5,"\t",$6,"\t",$12}'`
    OUTPUT="${LOAD%%\|*}<br>${TOP}|${LOAD##*\|}"
    STATUS=WARNING;;
  0 )
    STATUS=OK;;
  * )
    TOP=`top -b -n 1 | head -12 | tail -6 | awk 'ORS="<br>" {print $1,"\t",$5,"\t",$6,"\t",$12}'`
    OUTPUT="${LOAD%%\|*}<br>${TOP}|${LOAD##*\|}"
    STATUS=CRITICAL;;
esac

/bin/echo -e "$OUTPUT"

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
