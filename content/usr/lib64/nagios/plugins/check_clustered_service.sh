#!/bin/bash

PROG=`/bin/basename $0 .sh`
SERV_INST=`echo $1 | sed 's/?/$/g'`
SERV_PHY1=$2
SERV_PHY2=$3
SERV_RUN="NONE"
NRPECMD=/usr/lib/nagios/plugins/check_nrpe
STATUS=OK
STAT_CODE=0

$NRPECMD -H $SERV_PHY1 -u -p 8856 -t 30 -c checkservicestate -a ShowAll $SERV_INST > /dev/null 2>&1

if [ $? -eq 0 ]; then
  SERV_RUN="$SERV_PHY1 running,"
else
  SERV_RUN="$SERV_PHY1 not running,"
  STAT_CODE=$((STAT_CODE + 1))
fi
$NRPECMD -H $SERV_PHY2 -u -p 8856 -t 30 -c checkservicestate -a ShowAll $SERV_INST > /dev/null 2>&1

if [ $? -eq 0 ]; then
  SERV_RUN="$SERV_RUN $SERV_PHY2 running"
else
  SERV_RUN="$SERV_RUN $SERV_PHY2 is not running"
  STAT_CODE=$((STAT_CODE + 1))
fi

case $STAT_CODE in
  2 )
    STATUS=CRITICAL;;
  1 )
    STATUS=WARNING;;
  * )
    STATUS=OK;;
esac

echo "$STATUS - ${SERV_INST}:${SERV_RUN}"

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

