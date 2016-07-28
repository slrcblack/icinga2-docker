#!/bin/bash

LB_VIP=$1
LB_IP1=$2
LB_IP2=$3

STATUS=UNKNOWN
HA_STATE_PRI=`snmpwalk -v 1 -m B100-MIB -M /usr/share/snmp/mibs/ -c public $LB_IP1 hAstate | cut -d " " -f 4`
HA_STATE_SEC=`snmpwalk -v 1 -m B100-MIB -M /usr/share/snmp/mibs/ -c public $LB_IP2 hAstate | cut -d " " -f 4`

if [ "$HA_STATE_PRI" == "master(1)" ] && [ "$HA_STATE_SEC" == "standby(2)" ] ; then
  STATUS=OK

elif [ "$HA_STATE_PRI" == "standby(2)" ] && [ "$HA_STATE_SEC" == "master(1)" ] ; then
  STATUS=WARNING

else
  STATUS=CRITICAL
fi

echo "$STATUS - Primay KEMP is $HA_STATE_PRI and Secondary KEMP is $HA_STATE_SEC"

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
