#!/bin/bash

# This script checks for an active mount point from /proc/mounts.

MOUNT=$1

OUTPUT=`/bin/grep " $MOUNT " /proc/mounts`
if [[ $? -ne 0 ]]; then
  /bin/echo "CRITICAL - $MOUNT is NOT mounted!"
  exit 2
else
  /bin/echo "OK - $OUTPUT"
  exit 0
fi
