#!/bin/bash
#
# Author: 	David Mabry
# Modified:     Eric Myers
# Date:		07/16/2010
# Purpose:	Used to check for a current log file on JDA App server. If file doesn't exist, process needs restart
# Use:		TBD
# Main purpose of this script wrapper is to reverse the CRITICAL and OK results.

PROG=`basename $0 .sh`
NOW=`/bin/date +%Y%m%d_%H%M%S`
TMPDIR="/tmp"

#exec >> $LOGDIR/trace/$PROG.$NOW.trace 2>&1
#set -x

#################################################

wlog() {
  /bin/echo "`/bin/date +"%m/%d/%Y %H:%M:%S"`: $1 " >> $LOG
}

#######################################################################
# Read in command line variables
REMOTE_SERVER=$1
CMD="/usr/lib/nagios/plugins/check_nrpe -H $REMOTE_SERVER -p 8856 -t 45 -c alias_file_jda"
#echo $CMD
RESULT=`$CMD`
RC=$?
#OUTPUT=$RESULT
if [[ $RC = "0" ]]; then
  STATUS=CRITICAL
  OUTPUT="CheckFile CRITICAL | no files found"
else
  if [[ $RC = "2" ]]; then
    STATUS=OK
    OUTPUT="CheckFile OK | current file found"
  fi
fi
/bin/echo "$OUTPUT"

case $STATUS in
  UNKNOWN )
    exit 3;;
  CRITICAL )
    exit 2;;
  WARNING )
    exit 1;;
  OK )
    exit;;
  * )
    exit;;
esac
