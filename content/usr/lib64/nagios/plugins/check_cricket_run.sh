#!/bin/bash

STATUS=OK
WARNING=$1
CRITICAL=$2
TYPE=$3

# TYPE will be either 'subtrees' or 'snapshot'

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify warning and critical arguments."
  exit 1
fi

DIR="/usr/local/cricket/run"

[[ -z "$TYPE" ]] && TYPE="subtrees"

if [[ ! -e "$DIR/${TYPE}.time" ]]; then
  /bin/echo "WARNING - $DIR/${TYPE}.time not found."
  exit 1
fi

INTERFACES=`/bin/cat $DIR/interfaces`
TARGETS=`/bin/cat $DIR/targets`
TIME=`/bin/awk -F, '{print $1}' $DIR/${TYPE}.time`
SECS=`/bin/awk -F, '{print $2}' $DIR/${TYPE}.time`

[ "$SECS" -ge "$WARNING" ] && STATUS="WARNING"
[ "$SECS" -ge "$CRITICAL" ] && STATUS="CRITICAL"

echo "$STATUS - processed $TARGETS targets with $INTERFACES interfaces in $TIME|time=${SECS}s;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac

