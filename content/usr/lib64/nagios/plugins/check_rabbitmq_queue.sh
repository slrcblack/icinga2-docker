#!/bin/bash

# Returns the position of a substring from a string
function GetStrPosition
{
        echo $(awk -v a="$1" -v b="$2" 'BEGIN{print index(a,b)}')
} 

SERVER=$1
PORT=$2
USERNAME=$3
PASSWORD=$4
POLICYJOBSFAILEDQUEUE=$5

ENDPOINT="http://${SERVER}:${PORT}"

# Call RabbitMQ Management HTTP API
GET_MESSAGE=$(curl -sLm 10 --user ${USERNAME}:${PASSWORD} ${ENDPOINT}/api/queues/%2F/${POLICYJOBSFAILEDQUEUE})

if [[ "$GET_MESSAGE" == "" ]]; then
         echo "Check failed [no response from server] !"
         # exit with UNKNOWN
         exit 3
fi

VALUE_TO_FIND="\"messages\":"
STR_POS_START=$(GetStrPosition "$GET_MESSAGE" "$VALUE_TO_FIND")

if [[ $STR_POS_START < 1 ]]; then
        # exit with CRITICAL
        echo "ERROR: Messages Not Found in curl request"
        exit 2
fi

# Substring
GET_MESSAGE=${GET_MESSAGE:$STR_POS_START + ${#VALUE_TO_FIND}-1}
VALUE_TO_FIND=","

# Get position of the ending character
STR_POS_END=$(GetStrPosition "$GET_MESSAGE" "$VALUE_TO_FIND")

if [[ $STR_POS_END < 1 ]]; then
         echo "Check failed [invalid response message format] !"
        # exit with CRITICAL
         exit 2
fi

REQUESTED_VALUE=${GET_MESSAGE:0:$STR_POS_END-1}

if [[ $REQUESTED_VALUE == 0 ]]; then
   echo "No messages on $POLICYJOBSFAILEDQUEUE queue.|jobs=0;;;0"
   exit 0
elif [[ $REQUESTED_VALUE == 1 ]]; then
   echo "There is $REQUESTED_VALUE failed policy jobs message in $POLICYJOBSFAILEDQUEUE queue!|jobs=$REQUESTED_VALUE;;;0" 
# exit with WARNING
   exit 1
else
   echo "There are $REQUESTED_VALUE failed policy jobs messages in $POLICYJOBSFAILEDQUEUE queue!|jobs=$REQUESTED_VALUE;;;0" 
# exit with WARNING
   exit 1
fi
