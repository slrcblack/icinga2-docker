#!/bin/bash

# $1 = directory to check
# $2 = minutes until stale
# $3 = number of stale files to hit WARNING
# $4 = number of stale files to hit CRITICAL

if [ $# -lt 4 ]; then
  echo "Usage: $0 [dir] [minutes until stale] [WARNING number of files] [CRITICAL number of files]"
  echo " Ex. : $0 /tmp 15 2 5   <--  This will check /tmp for files older than 15 minutes."
  exit 1
fi

DIR=$1
MIN_STALE=$2
NUM_WARN=$3
NUM_CRIT=$4

COUNT=`ls -l $DIR/ | grep -v "^total" | grep -v "^d" | wc -l | awk '{print $1}'`
COUNT_STALE=`find $DIR/ -mmin +${MIN_STALE} -type f -maxdepth 1 | grep -v "/\."| wc -l | awk '{print $1}'`

STATUS=OK
OUTPUT="$DIR=$COUNT files ($COUNT_STALE stale)"
if [ $COUNT_STALE -ge $NUM_WARN ]; then
  STATUS=WARNING
fi
if [ $COUNT_STALE -ge $NUM_CRIT ]; then
  STATUS=CRITICAL
fi

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
