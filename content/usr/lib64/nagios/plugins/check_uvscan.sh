#!/bin/bash

STATUS=CRITICAL

if [[ -x "/usr/local/uvscan/uvscan" ]] ; then
  /usr/local/uvscan/uvscan --version > /tmp/uvscan.out
  RC=$?
  if [[ "$RC" -eq 0 ]]; then
    STATUS=OK
    OUTPUT=`/bin/grep "^Dat set version:" /tmp/uvscan.out`
    /bin/rm -f /tmp/uvscan.out
  else
    OUTPUT="error running 'uvscan --version'!"
  fi
else
  OUTPUT="/usr/local/uvscan/uvscan is not executable!"
fi

/bin/echo -e "$STATUS - $OUTPUT"

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
