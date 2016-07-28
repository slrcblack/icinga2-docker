#!/bin/bash

STATUS=OK
WARNING_PER=$1
CRITICAL_PER=$2

if [[ -z "$CRITICAL_PER" ]]; then
  /bin/echo "Must specify warning and critical arguments. Arguments are percentage free of set maximum"
  exit 1
fi

MAX=`cat /proc/sys/net/netfilter/nf_conntrack_max`
COUNT=`cat /proc/sys/net/netfilter/nf_conntrack_count`
BUCKETS=`cat /proc/sys/net/netfilter/nf_conntrack_buckets`

CONN_PER_BUCKET=$(($MAX / $BUCKETS))
PERCENT_FREE=$((100 - (($COUNT * 100) / $MAX)))
WARNING=$(($MAX - (($MAX * $WARNING_PER) / 100)))
CRITICAL=$(($MAX - (($MAX * $CRITICAL_PER) / 100)))

[ "$COUNT" -ge "$WARNING" ] && STATUS="WARNING"
[ "$COUNT" -ge "$CRITICAL" ] && STATUS="CRITICAL"
[ "$COUNT" -eq 0 ] && STATUS="CRITICAL"

echo "$STATUS - $COUNT/$MAX conns tracked. ${PERCENT_FREE}% free. Buckets: $BUCKETS ConnPerBucket: $CONN_PER_BUCKET, W=$WARNING, C=$CRITICAL|conns=$COUNT;$WARNING;$CRITICAL;0"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac

