#!/bin/bash

# This script checks for ext4 'discard' mount option on VMs that are usually on the Compellent.

STATUS=OK

if [[ ! -e "/usr/bin/facter" ]]; then
  PRODUCT="unknown"
  VIRTUAL="unknown"
  TEXT=""
else
  PRODUCT="`/usr/bin/facter productname`"
  VIRTUAL="`/usr/bin/facter is_virtual`"
fi

OUTPUT=`/bin/mount | /bin/grep "type ext4" | /bin/egrep -v -e "(/dev/sd|/dev/hd| /backups )" | /bin/awk '{print $3, $6}' | /bin/awk '{printf "%s ", $0}'`

TEMP="${OUTPUT//[^\(]}"
OPTIONSCOUNT="${#TEMP}"
DISCARDCOUNT=`/bin/echo $OUTPUT | /bin/sed 's/discard/discard\n/g' | /bin/grep -cw discard`

if [[ "$DISCARDCOUNT" -ne "$OPTIONSCOUNT" ]]; then
  STATUS=WARNING
  if [[ "$VIRTUAL" = "true" ]] || [[ "$PRODUCT" = "KVM" ]]; then
    TEXT="-- Is this filesystem on the Compellent?"
  fi
fi


echo "$STATUS - ${OUTPUT}${TEXT}"

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
