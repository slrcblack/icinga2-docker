#!/bin/bash
#######################################################################
# Description: NTP Service Stratum Level Monitoring Script for Nagios #
# Written by Nika Chkhikvishvili                                      #
# URL: http://sysadmin.softgen.ge                                     #
# Release Date: 01-04-2011                                            #
# versions 0.1                                                        # 
#  Usage: ./check_stratum                                             #
# License: GNU/GPL2                                                   #
# The Script was tested in RHEL*  Fedora* Centos*  Environement.      #
# Scenario: The script checks environement and binary dependencies    #
# then checks running process, if all prerequisites are passed        #
# it detects stratum levels. The script returns CRIT UNK and WARN     #
# depending which criteria is matched.                                #
#######################################################################

check_prerequisites()
{
# Error Codes
err_1=" - binary is missing. Please install it, or make sure it is in \$PATH."
err_2="NTP Daemon is not running!"

######################
# script dependencies
for i in ntpdc awk grep ntpd sed
  do
     if ! which $i > /dev/null 2>&1; then
     echo $i ${err_1} 
        stateid=3     
           exit $stateid
   exit
fi
done
#####################
# Service Availability
proc=`ps -ef | grep -v grep | grep ntpd`
 if [ $? -eq 1 ]
  then
     echo $err_2
        stateid=2     
          exit $stateid
   exit
fi 
####################
# Checking Stratums
}

check_stratum()
{
stratum=`ntpdc -4 -c sysinfo | grep "stratum:" | awk '{print $2}'`
peer=`ntpdc -4 -c sysinfo | grep "system peer:" | awk '{print $3}'`
excellent=2
good=3
normal=4
warning=5
critical=6
unknown=7
dead=16
###Startum Levels
if [[ "$stratum" -lt "$good" ]];
 then
    echo  "STRATUM OK. Level: $stratum  (Excellent) System Peer: $peer |stratum=$stratum;"
       stateid=0
elif  [[ "$stratum" -lt "$normal" ]]; 
   then
      echo  "STRATUM OK. Level: $stratum (Good) System Peer: $peer |stratum=$stratum;"
         stateid=0
elif  [[ "$stratum" -lt "$warning" ]]; 
   then
      echo  "STRATUM OK. Level: $stratum  (Normal) System Peer: $peer |stratum=$stratum;"
         stateid=0
elif  [[ "$stratum" -lt "$critical" ]];
   then
      echo  "STRATUM WARNING. Level: $stratum (Warning) System Peer: $peer |stratum=$stratum;"
         stateid=1
elif  [[ "$stratum" -lt "$unknown" ]];
   then
      echo  "STRATUM CRITICAL. Level: $stratum (Critical) System Peer: $peer |stratum=$stratum;"
         stateid=2
elif  [[ "$stratum" -lt "$dead" ]];
   then
      echo  "STRATUM UNKNOWN. Level: $stratum (Unknown Startum Level reached) System Peer: $peer |stratum=$stratum;"
         stateid=3
elif  [[ "$stratum" -eq "$dead" ]];
   then
      echo  "STRATUM CRITICAL. Level: $stratum (NTP Service is Dead!) System Peer: $peer |stratum=$stratum;"
         stateid=2
                    
          fi
    exit $stateid
}

check_prerequisites
check_stratum
