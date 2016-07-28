#!/bin/bash

# set -x

# Requirements:
#    Member's must have "heartbeat.clu" in their name.
#    Status must have "Online" in the first position before the comma when a member is online.

# Designed to work with clustat output below:

# Member Name                                                 ID   Status
# ------ ----                                                 ---- ------
# jddq1.heartbeat.clu                                             1 Online, rgmanager
# jddq2.heartbeat.clu                                             2 Online, Local, rgmanager
#
# Service Name                                       Owner (Last)                                       State
# ------- ----                                       ----- ------                                       -----
# service:TMDEV_oracle                               jddq1.heartbeat.clu                                started
# service:TMQA_oracle                                jddq1.heartbeat.clu                                started
# service:TMTST_oracle                               jddq1.heartbeat.clu                                started


CLUSTER_APP="$1"

if [ -z "$CLUSTER_APP" ]; then
  echo "WARNING - no cluster app specified on the command line."
  exit 1
fi

if [ ! -e "/usr/sbin/clustat" ]; then
  echo "WARNING - /usr/sbin/clstat not found."
  exit 1
fi

TEMP=`sudo /usr/sbin/clustat -s $CLUSTER_APP | grep "^ service:$CLUSTER_APP" | grep "started" | awk '{print $2}'`
ACTIVE="${TEMP%%.*}"
MEMBERS=`sudo /usr/sbin/clustat | grep "heartbeat.clu" | grep -v "^ service:" | awk '{print $1":"$3}'`

OUTPUT="Active=$ACTIVE"
NODECOUNT=0
for NODE in $MEMBERS; do
  HOST=${NODE%%.*}
  TEMP=${NODE##*:}
  STATUS=${TEMP%%,*}
  OUTPUT="$OUTPUT, $HOST=$STATUS"
  [[ "$STATUS" = "Online" ]] && ((NODECOUNT++))
done

STATUS=CRITICAL
if [ "$NODECOUNT" -eq 1 ]; then
  STATUS=WARNING
fi
if [ "$NODECOUNT" -gt 1 ]; then
  STATUS=OK
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

