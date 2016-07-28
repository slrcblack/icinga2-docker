#!/bin/bash
#
# Niles Ingalls ENA 2015
# find duplicate policy requests and report
#

CURTIME=$(date -d -$1minutes +'%d/%b/%Y:%H:%M' | sed 's#/#.#g');
DUPES=`sudo /bin/sed "1,/$CURTIME/d" /var/log/httpd/access_log | grep api | grep GET | rev | cut -c 25- | rev | sort | uniq -c | grep "^\      2"`;
COUNTDUPES=`sudo /bin/sed "1,/$CURTIME/d" /var/log/httpd/access_log | grep api | grep GET | rev | cut -c 25- | rev | sort | uniq -c | grep "^\      2" | wc -l`;

if [ "$COUNTDUPES" -gt 0 ]; then
   echo "There are $COUNTDUPES duplicate policy requests|dupes=$COUNTDUPES;;;0" 
#echo $COUNTDUPES
#echo $DUPES
# exit with CRITICAL
   exit 2  

else
   echo "No duplicate policy requests.|dupes=0;;;0"
#echo $COUNTDUPES
#echo $DUPES
   exit 0  
fi
