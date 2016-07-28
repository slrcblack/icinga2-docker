#!/bin/bash

DESC=`facter lsbdistdescription`
UPTIME=`facter uptime`
KERNEL=`facter kernelrelease`
PROCS=`facter processorcount`
MEMTOTAL=`facter memorytotal`
MEMFREE=`facter memoryfree`
TIMEZONE=`facter timezone`
PRODUCT=`facter productname`

PROCSTR="procs"
[[ "$PROCS" -eq 1 ]] && PROCSTR="proc"

/bin/echo "OK - $DESC $KERNEL $PRODUCT, $PROCS $PROCSTR, $MEMTOTAL total, $MEMFREE free, $TIMEZONE TZ"
