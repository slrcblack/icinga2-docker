#!/bin/bash

STATUS=OK
USER=$1

if [[ -z "$USER" ]]; then
  /bin/echo "Must specify a user to check."
  exit 1
fi

OUTPUT=`getent passwd $USER`
[[ $? -ne 0 ]] && STATUS=CRITICAL

echo "$STATUS - $OUTPUT"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
