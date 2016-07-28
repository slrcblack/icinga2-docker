#!/bin/bash

URL="http://www.google.com"
WARNTT=2.0
CRITTT=3.0
usage=$(
cat <<EOF
$0 [OPTION]
-i INTERFACE 	 Selects the interface to run the check out through
-u URL_TO_CHECK  Selects the URL to perform the check against / Defaults to http://www.google.com
-w Specify Warning amount of time / Defaults to 2.0
-c Specify Critical amount of time / Defaults to 3.0
EOF
)

if [ $# -eq 0 ]; then
  echo "Please specify an interface"
  echo "$usage"
  exit
fi

while getopts "i:u:c:w:h" OPTION; do
  case "$OPTION" in
    i)
      INTERFACE="$OPTARG"
      ;;
    u)
      URL="$OPTARG"
      ;;
    c)
      CRITTT="$OPTARG"
      ;;
    w)
      WARNTT="$OPTARG"
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

TimeTotal=`curl --interface $INTERFACE --connect-timeout 30 -s -w"%{time_total}\n" -o /dev/null --url $URL`

STATUS=UNKNOWN

#if [ $TimeTotal -le $WARNTT ] && [ $TimeTotal -ne 0.000 ] ; then
#  STATUS=OK

#elif [ $TimeTotal -ge $WARNTT ] && [ $TimeTotal -lt $CRITTT ] && [ $TimeTotal -ne 0.000 ] ; then
#  STATUS=WARNING

#elif [ $TimeTotal -ge $CRITTT ] || [ $TimeTotal -e 0.000 ] ; then
#  STATUS=CRITICAL
#fi

if (( $(bc <<< "$WARNTT>$TimeTotal") > 0 )); then STATUS=OK; fi
if (( $(bc <<< "$TimeTotal>$WARNTT") > 0 )); then STATUS=WARNING; fi
if (( $(bc <<< "$TimeTotal>$CRITTT") > 0 )); then STATUS=CRITICAL; fi
if [ $TimeTotal = 0.000 ]; then STATUS=CRITICAL; fi

echo "$STATUS - Response time to $URL is "$TimeTotal"ms"

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

echo "$STATUS -$TimeTotal|ResponseTime=$TIME1;0;0;0"
