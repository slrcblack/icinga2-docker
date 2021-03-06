#!/bin/sh
PROGRAM=${0##*/}
PROGPATH=${0%/*}
. $PROGPATH/utils.sh
####################################################
#			default days						####
if [ -z $4 ];
then
	warning=30
else warning=$4
fi

if [ -z $6 ];
then
	critical=7
else critical=$6
fi

#
####################################################
#			arguments from utils.sh				####
domain=$2

####################################################
#			Checking if you have whois			####
WHOIS=/usr/bin/whois
if [ ! -e $WHOIS ];
then
	echo "Please yum install whois"
	exit
fi

####################################################
#		Checking if script can be executed		####
if [ -z $? ] || [ -z $1 ] || [ -z $domain ];
then
	echo "Usage: $PROGRAM -d <domain> [-c <critical>] [-w <warning>]"
	exit
fi

####################################################
#	checking .name	and defining whois server	####
DLTYPE=`echo $domain | cut -d '.' -f2`
if [ ${DLTYPE} == 'com' ] || [ ${DLTYPE} == 'edu' ] || [ ${DLTYPE} == 'net' ];
then
	TYPE=internic
	WHOIS_SERVER="whois.internic.org"
elif [ ${DLTYPE} == 'org' ];
then
	TYPE=pir
	WHOIS_SERVER="whois.pir.org"
elif [ ${DLTYPE} == 'in' ];
then
	TYPE=in
	WHOIS_SERVER="whois.registry.in"
elif [ ${DLTYPE} == 'co' ];
then
	TYPE=nic
	WHOIS_SERVER="whois.nic.uk"
elif [ ${DLTYPE} == 'biz' ];
then
	TYPE=neulevel
	WHOIS_SERVER="whois.neulevel.biz"
elif [ ${DLTYPE} == 'info' ];
then
	TYPE=afilias
	WHOIS_SERVER="whois.afilias.info"
elif [ ${DLTYPE} == 'ru' ];
then
	TYPE=russia
	WHOIS_SERVER="whois.nic.ru"
elif [ ${DLTYPE} == 'dk' ];
then
	TYPE=dk-hostmaster
	WHOIS_SERVER="whois.dk-hostmaster.dk"
else
	echo "We do not support this domain (not integrated). Sorry."
	exit $STATE_UNKNOWN
fi

####################################################
#			do whois							####

FILE=/tmp/domain_$2.txt
out=`$WHOIS -h $WHOIS_SERVER $domain > $FILE`

####################################################
#			expiration formats					####

# for domains .com, .edu, .net #
if [ $TYPE == 'internic' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f2`
# for .org domains
elif [ $TYPE == 'pir' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f1`
# for .in domains
elif [ $TYPE == 'in' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f1`
# for co.uk domains
elif [ $TYPE == 'nic' ];
then
expiration=`cat ${FILE} | awk '/Renewal date:/' | cut -d ':' -f2`
# for .biz domains
elif [ $TYPE == 'neulevel' ];
then
month=`cat ${FILE} | awk '/Domain Expiration Date:/' | cut -d ' ' -f26`
day=`cat ${FILE} | awk '/Domain Expiration Date:/' | cut -d ' ' -f27`
year=`cat ${FILE} | awk '/Domain Expiration Date:/' | cut -d ' ' -f30`
expiration=$day-$month-$year
# for .info domains
elif [ $TYPE == 'afilias' ];
then
expiration=`cat ${FILE} | awk '/Expiration Date:/' | cut -d ':' -f2 | cut -d ' ' -f1`
#for .ru domains
elif [ $TYPE == 'russia' ];
then
day=`cat ${FILE} | awk '/paid-till:/' | cut -d ':' -f2 | cut -d '.' -f3`
month=`cat ${FILE} | awk '/paid-till:/' | cut -d ':' -f2 | cut -d '.' -f2`
getmonth() 
{
       case $month in
             01) echo jan ;;
             02) echo feb ;;
             03) echo mar ;;
             04) echo apr ;;
             05) echo may ;;
             06) echo jun ;;
             07) echo jul ;;
             08) echo aug ;;
             09) echo sep ;;
             10) echo oct ;;
             11) echo nov ;;
             12) echo dec ;;
               *) echo  0 ;;
       esac
}
year=`cat ${FILE} | awk '/paid-till:/' | cut -d ':' -f2 | cut -d ' ' -f5 | cut -d '.' -f1`
expiration=$day-$(getmonth ${2})-$year
elif [ $TYPE == 'dk-hostmaster' ];
then
day=`cat ${FILE} | awk '/Expires:/' | cut -d '-' -f3`
month=`cat ${FILE} | awk '/Expires:/' | cut -d '-' -f2`
getmonth() 
{
       case $month in
             01) echo jan ;;
             02) echo feb ;;
             03) echo mar ;;
             04) echo apr ;;
             05) echo may ;;
             06) echo jun ;;
             07) echo jul ;;
             08) echo aug ;;
             09) echo sep ;;
             10) echo oct ;;
             11) echo nov ;;
             12) echo dec ;;
               *) echo  0 ;;
       esac
}
year=`cat ${FILE} | awk '/Expires:/' | cut -d ' ' -f15 | cut -d '-' -f1`
expiration=$day-$(getmonth ${2})-$year
fi

/bin/rm -f $FILE

####################################################
#			if can't get expiration time		####
if [ -z $expiration ];
then
	echo "UNKNOWN - can not retrieve expiration time"
	exit $STATE_UNKNOWN
fi

####################################################
#			expiration counting					####
expiration_date=$(date +%s --date="$expiration")
NOW=$(date +%s)
DAYSLEFT=$((($expiration_date-$NOW)/86400))

####################################################
#				alerts							####
if [ $DAYSLEFT -lt 0 ];
then
	echo "CRITICAL - Domain is expired"
	exit $STATE_CRITICAL
elif [ $DAYSLEFT -lt $critical ];
then
	echo "CRITICAL - Domain will expire on $expiration in $DAYSLEFT days."
	exit $STATE_CRITICAL
elif [ $DAYSLEFT -lt $warning ];
then
	echo "WARNING - Domain will expire on $expiration in $DAYSLEFT days."
	exit $STATE_WARNING
fi

echo "OK - Domain will expire on $expiration in $DAYSLEFT days."
exit $STATE_OK
