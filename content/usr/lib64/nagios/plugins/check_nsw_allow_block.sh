#!/bin/bash

ALLOWED="http://www.google.com"
BLOCKED="http://www.xnxx.com"
QUESTION="http://www.facebook.com"
usage=$(
cat <<EOF
$0 [OPTION]
-i INTERFACE 	 Selects the interface to run the check out through
-a ALLOWED_URL_TO_CHECK  Selects the URL to perform the allow check against / Defaults to http://www.google.com
-b BLOCKED_URL_TO_CHECK  Selects the URL to perform the blocked check against / Defaults to http://www.xnxx.com
-q QUESTION_URL_TO_CHECK  Selects the URL to perform a check against to determine if it is blocked or not/ Defaults to http://www.facebook.com
EOF
)

if [ $# -eq 0 ]; then
  echo "Please specify an interface"
  echo "$usage"
  exit
fi

while getopts "i:a:b:q:h" OPTION; do
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
    q)
      QUESTION="$OPTARG"
      ANSWER=`curl --interface $INTERFACE --connect-timeout 30 -s --url $QUESTION -L | grep "Blocked Website" | wc -l`
	if [ $ANSWER -gt 0 ] ; then
	echo "returned an AO page"
	else echo "did not return an AO page"
	fi
      exit
      ;;
    h)
      echo "$usage"
      exit
      ;;
    \?)
      echo "$usage"
      exit
      ;;
  esac
done

HTTP200=`curl --interface $INTERFACE --connect-timeout 30 -s -w"%{http_code}\n" -o /dev/null --url $ALLOWED -L`
HTTPBLOCK=`curl --interface $INTERFACE --connect-timeout 30 -s --url $BLOCKED -L | grep "Blocked Website" | wc -l`

STATUS=UNKNOWN

if [ $HTTP200 = 200 ] && [ $HTTPBLOCK -gt 0 ] ; then
  STATUS=OK

else STATUS=CRITICAL
fi

if [ $HTTPBLOCK -gt 0 ] ; then
  BLOCKMESSAGE="returned an Authorized Override page"
fi

if [ $HTTPBLOCK = 0 ] ; then
  BLOCKMESSAGE="not blocked"
fi


echo "$STATUS - $ALLOWED returned code of $HTTP200 and $BLOCKED $BLOCKMESSAGE."

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
