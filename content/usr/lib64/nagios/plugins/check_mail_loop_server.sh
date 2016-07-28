#!/bin/bash

#########################################################################################
# Setup environment variables
#########################################################################################
PROG=`/bin/basename $0 .sh`
DIR=/var/log/nagios/mailloops
HOST=`/bin/uname -n`
NOW=`/bin/date +%Y%m%d_%H%M%S`
NOW_EPOCH=`/bin/date +%s`

SUBJECT="Check Mail Loop Server"
FROM="nagios@bfusa.com"
STATUS=OK

wlog() {
  /bin/echo "`/bin/date +"%m/%d/%Y %H:%M:%S"`: $1 " >> $LOG
}

#########################################################################################
# Main
#########################################################################################

if [ $# -lt 5 ]; then
  echo "Usage: ${PROG}.sh [id] [ destination email address] [warn secs] [crit secs] [SMTP server]"
  echo "       NOTE: [id] is the local mailbox in /var/spool/mail/[id]"
  exit
fi

EMAIL_ID="$1"
DST_EMAIL="$2"
WARN_SECS="$3"
CRIT_SECS="$4"
SMTPSRV="$5"

LOG=$DIR/$PROG.$EMAIL_ID.log

#########################################################################################
# Setup tracing
#########################################################################################
exec > $DIR/$PROG.$EMAIL_ID.trace 2>&1
set -x

/bin/cp /dev/null $LOG

wlog "$PROG started"
wlog ""
wlog ""
wlog "Sending email to $DST_EMAIL via $SMTPSRV ..."
/usr/lib/nagios/plugins/sendEmail -f "${EMAIL_ID}.${FROM}" -t $DST_EMAIL -u "$SUBJECT on $HOST at $NOW" -s $SMTPSRV -m "$NOW_EPOCH=$NOW" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  wlog "  Error sending email.  Exiting."
  STATUS=CRITICAL
  echo "$STATUS - error sending email to $DST_EMAIL"
  exit 2
fi
wlog "Done."
wlog ""

WAIT=$CRIT_SECS
LATER_EPOCH=""
wlog "Waiting up to $WAIT seconds for return email..."
while [ -z "$LATER_EPOCH" ] && [ $WAIT -gt 0 ]; do
  sleep 1

  /bin/grep -q $NOW_EPOCH /var/spool/mail/$EMAIL_ID
  if [ $? -eq 0 ]; then
    LATER_EPOCH=`/bin/date +%s`
    wlog "  Email match found for $NOW_EPOCH."
    cp /dev/null /var/spool/mail/$EMAIL_ID
  fi

  WAIT=$((WAIT - 1))
  if [ $((WAIT % 20)) -eq 0 ]; then
    wlog "  $WAIT seconds left..."
  fi
done

if [ -z "$LATER_EPOCH" ]; then
  LATER_EPOCH=`/bin/date +%s`
fi

DIFF_SECS=$((LATER_EPOCH - NOW_EPOCH))

if [ $DIFF_SECS -ge $WARN_SECS ]; then
  STATUS=WARNING
fi
if [ $DIFF_SECS -ge $CRIT_SECS ]; then
  STATUS=CRITICAL
fi

echo "$STATUS - email roundtrip ${DIFF_SECS}s for $EMAIL_ID at `/bin/date`|time=${DIFF_SECS}"

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
