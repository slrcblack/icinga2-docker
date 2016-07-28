#!/bin/bash

ALLOWED="http://www.google.com"
BLOCKED="http://www.online-casino.com"
usage=$(
cat <<EOF
$0 [OPTION]
-i INTERFACE 	 Selects the interface to run the check out through
-a ALLOWED_URL_TO_CHECK  Selects the URL to perform the allow check against / Defaults to http://www.google.com
-b BLOCKED_URL_TO_CHECK  Selects the URL to perform the blocked check against / Defaults to http://www.online-casino.com
EOF
)

while getopts "i:a:b:h" OPTION; do
  case "$OPTION" in
    i)
      INTERFACE="$OPTARG"
      ;;
    a)
      ALLOWED="$OPTARG"
      ;;
    b)
      BLOCKED="$OPTARG"
      ;;
    h)
      echo "$usage"
      exit
      ;;
    *)
      echo "unrecognized option"
      echo "$usage"
      exit
      ;;
  esac
done

HTTP200=`curl --interface $INTERFACE --connect-timeout 30 -s -w"%{http_code}\n" -o /dev/null --url $ALLOWED`
HTTPBLOCK=`curl --interface $INTERFACE --connect-timeout 30 -s -w"%{http_code}\n" -o /dev/null --url $BLOCKED`

STATUS=UNKNOWN

if [ $HTTP200 = 200 ] && [ HTTPBLOCK = 302 ] ; then
  STATUS=OK

else STATUS=CRITICAL
fi

echo "$STATUS - $ALLOWED returned code of $HTTP200 and $BLOCKED returned code of $HTTPBLOCK"

case $STATUS in
  CRITICAL )
    exit 2;;
  WARNING )
    exit 1;;
  OK )
    exit 0;;
  * )
    exit 0;;
esac
