#!/bin/bash

LOG="/var/log/mailq_php.log"

if [[ -s "$LOG" ]]; then
  /bin/sleep 3
  if [[ -s "$LOG" ]]; then
    # The log file exists and is not empty so there are errors.
    CONTENTS=`/bin/cat $LOG | /usr/bin/tr -d '\n'`
    /bin/echo "WARNING - $LOG contains [${CONTENTS}]"
    exit 1
  fi
else
  if [[ -e "$LOG" ]]; then
    # The log file exists and is empty.
    /bin/echo "OK - $LOG is empty so there are no errors."
  else
    /bin/echo "WARNING - $LOG does not exist."
    exit 1
  fi
fi
