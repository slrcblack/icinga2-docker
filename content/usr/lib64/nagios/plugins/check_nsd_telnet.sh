#!/bin/bash
usage=$(
cat <<EOF
$0 [OPTION]
-H HOSTNAME 	 The fully qualified hostname or IP address to run the check against.
EOF
)

while getopts "H:h" OPTION; do
  case "$OPTION" in
    H)
      HOSTNAME="$OPTARG"
      ;;
    h)
      echo "$usage"
      exit
      ;;
    *)
      echo "unrecognized option"
      echo "$usage"
      exit
      ;;
  esac
done

VAR=$(expect << EOF
set timeout 10
spawn telnet $HOSTNAME 3429
match_max 100000
expect "Connected to $HOSTNAME.\r\r
Escape character is '^\]'.\r\r
"
send -- "test\r"
expect -exact "test\r
http://www.net-sweeper.com/\r
"
send -- ""
expect -exact "^\]\r
telnet> "
send -- "quit\r"
EOF
echo $?)

NSWCOUNT=`echo "$VAR" | grep net-sweeper | wc -l`

if [ $NSWCOUNT = 1 ] ; then
  STATUS=OK

else STATUS=CRITICAL
fi

echo "$STATUS - NSD Check returned $NSWCOUNT number of net-sweeper."

case $STATUS in
  CRITICAL )
    exit 2;;
  OK )
    exit 0;;
  * )
    exit 0;;
esac
