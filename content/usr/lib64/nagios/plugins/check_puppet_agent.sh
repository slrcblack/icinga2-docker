#!/bin/bash

STATUS=OK
LOCK27="/var/lib/puppet/state/puppetdlock"
LOCK34="/var/lib/puppet/state/agent_disabled.lock"
PID=`/bin/cat /var/run/puppet/agent.pid`

RUNNING=""
/bin/ps -ef | /bin/grep $PID | /bin/egrep -q -e "(puppetd|puppet agent)"
if [[ $? -ne 0 ]]; then
  STATUS=CRITICAL
  RUNNING="NOT "
fi

OUTPUT="Puppet Agent v`/usr/bin/facter puppetversion` ${RUNNING}running (pid $PID)"

REASON=""
LOCK=$LOCK27
if [[ -e "$LOCK34" ]]; then
  LOCK=$LOCK34
  REASON=`/bin/cat $LOCK`
fi

if [[ -e "$LOCK" ]]; then
  STALE=`/bin/find "$LOCK" -mtime +1 | /usr/bin/wc -l`
  if [[ "$STALE" -ne 0 ]]; then
    STATUS=CRITICAL
    OUTPUT="$OUTPUT, admin disabled or puppet agent dead (lock file exists and is older than 1 day) $REASON"
  else
    OUTPUT="$OUTPUT, normal puppet run or recent admin disable (lock file exists and is less than 1 day old)"
  fi
else
  OUTPUT="$OUTPUT, not admin disabled (lock file does not exist)"
fi

/bin/echo "$STATUS - $OUTPUT"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
