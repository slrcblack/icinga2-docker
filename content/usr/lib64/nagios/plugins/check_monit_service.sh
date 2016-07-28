#!/bin/bash

usage=$(
cat <<EOF
$0 [OPTION]
-H HOSTNAME 	 Name or IP of the host to run the check against
-S SERVICE 	 Name of the Monit service to run the check against
-U USERNAME 	 Username for the Monit web interface
-P PASSWORD 	 Password for the Monit web interface
EOF
)

if [ $# -eq 0 ]; then
  echo "Please specify an interface"
  echo "$usage"
  exit
fi

while getopts "H:S:U:P:h" OPTION; do
  case "$OPTION" in
    H)
      HOSTNAME="$OPTARG"
      ;;
    S)
      SERVICE="$OPTARG"
      ;;
    U)
      USERNAME="$OPTARG"
      ;;
    P)
      PASSWORD="$OPTARG"
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

UNMONITORED=`curl --connect-timeout 30 -s --url http://$USERNAME:$PASSWORD@$HOSTNAME:2812/$SERVICE -L | grep unmonitored | wc -l`
MONITORED=`curl --connect-timeout 30 -s --url http://$USERNAME:$PASSWORD@$HOSTNAME:2812/$SERVICE -L | grep monitored | wc -l`

if [ $UNMONITORED = 0 ] && [ $MONITORED -gt 0 ] ; then
  STATUS=OK
  MONIT="monitoring"

else STATUS=CRITICAL
     MONIT="not monitoring"
fi

echo "$STATUS - Found that monit is $MONIT $SERVICE on $HOSTNAME."

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
