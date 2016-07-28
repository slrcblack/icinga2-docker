#!/bin/bash

#exec >> /tmp/debug.trace.last 2>&1
#set -x

# Check the outbound mail queue for domains we relay for.

THRESHOLD=$1
WARNING=$2
CRITICAL=$3

if [[ -z "$CRITICAL" ]]; then
  /bin/echo "Must specify threshold, warning and critical arguments."
  exit 1
fi

TOTAL_REQUESTS=`sudo /usr/sbin/sendmail -bp`
if [[ $? -ne 0 ]]; then
  echo "Error running 'sudo /usr/lib/sendmail'."
  exit 1
fi
TOTAL_REQUESTS=`sudo /usr/sbin/sendmail -bp | /usr/bin/tail -1 | /bin/sed -s 's/\t//g'`
# Sendmail output "Total requests: 22"
# Postfix output  "-- 5220 Kbytes in 49 Requests."
if [[ "$TOTAL_REQUESTS" = "${TOTAL_REQUESTS%%:*}" ]]; then
  TOTAL_REQUEST_NUM=`/bin/echo $TOTAL_REQUESTS | /bin/awk '{print $5}'`    #  <-- Postfix
  MTA=POSTFIX
else
  TOTAL_REQUEST_NUM=${TOTAL_REQUESTS##*: }    #   <-- Sendmail output has colon
  MTA=SENDMAIL
fi
[[ -z "$TOTAL_REQUEST_NUM" ]] && TOTAL_REQUEST_NUM=0

case $MTA in
  SENDMAIL) DOMAINS=`/bin/egrep -ie "^To:.*RELAY$" /etc/mail/access | /bin/cut -f 2 -d : | /bin/awk '{print $1}'` ;;
   POSTFIX) TEMP=`/usr/sbin/postconf relay_domains | /bin/cut -f 2 -d = | /bin/sed -e 's/,//g'`
            DOMAINS=""
            for DOMAIN in $TEMP; do
              [[ ! "${DOMAIN:0:1}" = "\$" ]] && DOMAINS="$DOMAINS $DOMAIN"
            done ;;
esac

STATUS=OK
OUTPUT=""
for DOMAIN in $DOMAINS; do
  # Sendmail output "Total requests: 22"
  # Postfix output  "-- 5220 Kbytes in 49 Requests."
  case $MTA in
    SENDMAIL) REQUESTS=`sudo /usr/lib/sendmail -bp -OQueueDirectory=/var/spool/mqueue -qR$DOMAIN | /usr/bin/tail -1 | /bin/sed -s 's/\t//g'`
              REQUEST_NUM=`/bin/echo "$REQUESTS" | /bin/cut -f 2 -d :`    #   <-- Sendmail output
              ;;
    POSTFIX) REQUEST_NUM=`/usr/bin/mailq | /bin/egrep -B 5 -e "^\s+.*@$DOMAIN" | /bin/egrep -e "^[0-9A-F]{11}" | grep -v "!" | wc -l` ;;
  esac
  [[ -z "$REQUEST_NUM" ]] && REQUEST_NUM=0
  if [[ "$REQUEST_NUM" -ge "$THRESHOLD" ]]; then
    [[ "$REQUEST_NUM" -ge "$WARNING" ]] && [[ "$STATUS" = "OK" ]] && STATUS="WARNING"
    [[ "$REQUEST_NUM" -ge "$CRITICAL" ]] && STATUS="CRITICAL"
    if [[ -z "$OUTPUT" ]]; then
      OUTPUT="$DOMAIN:$REQUEST_NUM"
    else
      OUTPUT="$OUTPUT, $DOMAIN:$REQUEST_NUM"
    fi
  fi
done

[[ -z "$OUTPUT" ]] && OUTPUT="below threshold of $THRESHOLD."

echo "$STATUS - $OUTPUT|requests=$TOTAL_REQUEST_NUM"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
