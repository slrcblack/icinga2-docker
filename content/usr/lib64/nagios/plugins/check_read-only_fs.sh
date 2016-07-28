#!/bin/bash

# This script checks for a Read-only file system either from a
# log file or by touching a new file.

FILE=$1

if [[ ! -z "$FILE" ]] && [[ -e "$FILE" ]]; then
  TEMP=`/usr/bin/tail -100000 "$FILE" | /bin/grep "Read-only"`
  if [[ $? -eq 0 ]]; then
    OUTPUT=`/bin/echo "$TEMP" | /usr/bin/tail -1`
    /bin/echo "CRITICAL - $OUTPUT"
    exit 2
  else
    /bin/echo "OK - 'Read-only' not found in $FILE"
    exit 0
  fi
else
  OUTPUT=`LANG=C /bin/touch "$FILE" 2>&1 | /bin/grep "Read-only"`
  if [[ $? -eq 0 ]]; then
    /bin/echo "CRITICAL - $OUTPUT"
    exit 2
  else
    /bin/echo "OK - able to touch $FILE"
    /bin/rm -f "$FILE"
    exit 0
  fi
fi
