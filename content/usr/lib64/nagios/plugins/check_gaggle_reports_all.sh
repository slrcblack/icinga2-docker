#!/bin/bash

# exec >> /tmp/check_iptables.trace.$$ 2>&1
# set -x

STATUS=OK
OUTPUT="All Gaggle Reports look good."
QUERY_FAIL=0

WARN_QUERY=`mysql -u localquery -s --skip-column-names -e "select count(taskid) from data where fail_msgs/total_msgs > 0.5 and arch_fin > date_sub(now(), interval 80 hour) group by taskid" gaggle_report`
if [ "$?" -gt 0 ]; then
  QUERY_FAIL=1
  OUTPUT="WARN QUERY FAILED!"
fi

CRIT_QUERY=`mysql -u localquery -s --skip-column-names -e "select count(distinct taskid) from data where arch_fin > date_sub(now(), interval 80 hour) and arch_success = 0 order by arch_fin desc" gaggle_report`
if [ "$?" -gt 0 ]; then
  QUERY_FAIL=1
  OUTPUT="CRIT QUERY FAILED!"
fi

[[ -z "$WARN_QUERY" ]] && WARN_QUERY=0
[[ -z "$CRIT_QUERY" ]] && CRIT_QUERY=0

if [ "$QUERY_FAIL" -eq 0 ]; then
  if [ "$WARN_QUERY" -gt 0 ]; then
    STATUS=WARNING
    OUTPUT="$WARN_QUERY with > 50% failed msgs."
  fi
  if [ "$CRIT_QUERY" -gt 0 ]; then
    STATUS=CRITICAL
    OUTPUT="$OUTPUT  $CRIT_QUERY failed archive jobs!"
  fi
fi

/bin/echo "$STATUS - ENA hosted customers: $OUTPUT"

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
