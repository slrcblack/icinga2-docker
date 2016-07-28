#!/bin/bash

if [[ $# -lt 4 ]]; then
  echo "Usage: `/bin/basename $0` -c COMMUNITY -H HOSTNAME"
  exit
fi

while getopts "c:H:" optionName; do
  case $optionName in
  	c ) COMMUNITY="$OPTARG";;
  	H ) HOST="$OPTARG";;
  esac
done

OUTPUT=`/usr/bin/snmpget -v 2c -r 3 -t 5 -c "$COMMUNITY" "$HOST" .1.3.6.1.4.1.476.1.42.3.4.1.2.3.1.3.1`
if [[ "$?" -eq 0 ]]; then
  CURRENTTEMP=${OUTPUT##* }
else
  /bin/echo "CRITICAL - unable to communicate with the host."
  exit 2
fi

OUTPUT=`/usr/bin/snmpget -v 2c -r 2 -t 3 -c "$COMMUNITY" "$HOST" .1.3.6.1.4.1.476.1.42.3.4.1.2.3.1.4.1`
[[ "$?" -eq 0 ]] && HIGHTEMP=${OUTPUT##* }

OUTPUT=`/usr/bin/snmpget -v 2c -r 3 -c "$COMMUNITY" "$HOST" .1.3.6.1.4.1.476.1.42.3.4.1.2.3.1.5.1`
[[ "$?" -eq 0 ]] && LOWTEMP=${OUTPUT##* }

OUTPUT=`/usr/bin/snmpget -v 2c -r 3 -c "$COMMUNITY" "$HOST" .1.3.6.1.4.1.476.1.42.3.4.2.2.3.1.3.1`
[[ "$?" -eq 0 ]] && RELHUMIDITY=${OUTPUT##* }

OUTPUT=`/usr/bin/snmpget -v 2c -r 3 -c "$COMMUNITY" "$HOST" .1.3.6.1.4.1.476.1.42.3.4.2.2.3.1.4.1`
[[ "$?" -eq 0 ]] && HIGHHUMIDITY=${OUTPUT##* }

OUTPUT=`/usr/bin/snmpget -v 2c -r 3 -c "$COMMUNITY" "$HOST" .1.3.6.1.4.1.476.1.42.3.4.2.2.3.1.5.1`
[[ "$?" -eq 0 ]] && LOWHUMIDITY=${OUTPUT##* }

OUTPUT=`/usr/bin/snmpget -v 2c -r 3 -c "$COMMUNITY" "$HOST" LIEBERT-GP-ENVIRONMENTAL-MIB::lgpEnvStateGeneralAlarmOutput.0`
if [[ "$?" -eq 0 ]]; then
  TEMP=${OUTPUT##* }
  GENALARM=${TEMP%(*}
fi

[[ -z "$HIGHTEMP" ]] && HIGHTEMP=0
[[ -z "$LOWTEMP" ]] && LOWTEMP=0
[[ -z "$RELHUMIDITY" ]] && RELHUMIDITY=0
[[ -z "$HIGHHUMIDITY" ]] && HIGHHUMIDITY=0
[[ -z "$LOWHUMIDITY" ]] && LOWHUMIDITY=0
[[ -z "$GENALARM" ]] && GENALARM="unknown"

WARNHT=$((HIGHTEMP-5))
WARNHH=$((HIGHHUMIDITY-5))

STATUS=UNKNOWN
if [[ "$CURRENTTEMP" -lt "$WARNHT" ]] && [[ "$CURRENTTEMP" -gt "$LOWTEMP" ]] && [[ "$RELHUMIDITY" -lt "$WARNHH" ]] && [[ "$RELHUMIDITY" -gt "$LOWHUMIDITY" ]] && [[ "$GENALARM" = "off" ]]; then
  STATUS=OK
fi
if [[ "$CURRENTTEMP" -ge "$WARNHT" ]] || [[ "$CURRENTTEMP" -le "$LOWTEMP" ]] || [[ "$RELHUMIDITY" -ge "$WARNHH" ]] && [[ "$GENALARM" = "off" ]]; then
  STATUS=WARNING
fi
if [[ "$CURRENTTEMP" -gt "$HIGHTEMP" ]] || [[ "$CURRENTTEMP" -lt "$LOWTEMP" ]] || [[ "$RELHUMIDITY" -gt "$HIGHHUMIDITY" ]] || [[ "$RELHUMIDITY" -lt "$LOWHUMIDITY" ]] || [[ "$GENALARM" != "off" ]]; then
  STATUS=CRITICAL
fi

/bin/echo "$STATUS - temp ${CURRENTTEMP}F, humidity ${RELHUMIDITY}%, alarm $GENALARM.|temp=$CURRENTTEMP humidity=$RELHUMIDITY hightempcrit=$HIGHTEMP hightempwarn=$WARNHT lowtempcrit=$LOWTEMP lowtempwarn=$LOWTEMP highhumidcrit=$HIGHHUMIDITY highhumidwarn=$WARNHH lowhumidcrit=$LOWHUMIDITY lowhumidwarn=$LOWHUMIDITY"

case $STATUS in
  CRITICAL )
    exit 2;;
  WARNING )
    exit 1;;
  OK )
    exit 0;;
  UNKNOWN )
    exit -1;;
  * )
    exit 0;;
esac
