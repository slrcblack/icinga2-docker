#!/bin/bash

COMMAND=`top b n 1 | head -12 | tail -5 | awk '{ORS=", "; print $2, $9, $10, $12}'`

STATUS=OK

OUTPUT="$STATUS - $COMMAND"

/bin/echo "$OUTPUT"

exit
