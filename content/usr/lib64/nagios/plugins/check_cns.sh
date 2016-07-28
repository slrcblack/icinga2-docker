#!/bin/bash
# updated to extract cns URL from nsd.conf (Niles)
# exec >> /tmp/check_cns.trace.$$ 2>&1
# set -x


#/usr/local/netsweeper/bin/cnstest -s ena1705 -c cns.netsweeper.com -u http://www.playboy.com | grep RC_GOOD; echo $?

if [[ ! -e /usr/local/netsweeper/bin/cnstest ]]; then
   echo "CRITICAL - cnstest binary not found!"
   exit 2
fi



STATUS=CRITICAL
CNSHOST=$(grep -e ^cns_server /usr/local/netsweeper/etc/nsd.conf | awk '{split($2, a, " "); print a[1]}')
SERIAL=${2:-"ena1705"}
SITE=${3:-"http://www.playboy.com"}

OUTPUT="$CNSHOST: ERROR!"
NULL=`/usr/local/netsweeper/bin/cnstest -s $SERIAL -c $CNSHOST -u $SITE | /bin/grep RC_GOOD`
if [[ "$?" -eq 0 ]]; then
  STATUS=OK
  OUTPUT="$CNSHOST: RC_GOOD Found"
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
