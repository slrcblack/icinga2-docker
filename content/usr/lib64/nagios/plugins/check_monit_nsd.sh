#!/bin/bash

STATUS=OK

sudo monit status > /tmp/mon.tmp
STATUS=`sed -n '4{p;q}' /tmp/mon.tmp | awk '{ print $2}'` #>/dev/null


if [ $STATUS = "running" ] ; then
        echo "OK - MONIT is monitoring NSD."
    else
        echo "CRITICAL - MONIT is not monitoring NSD."
	      STATUS=CRITICAL
    fi

case $STATUS in
  CRITICAL ) exit 2;;
   WARNING ) exit 1;;
        OK ) exit 0;;
esac
