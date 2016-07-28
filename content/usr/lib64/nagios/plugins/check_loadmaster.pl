#!/usr/bin/perl
################################################################################
#
# Author: 	Thomas Dohl
# Date: 	see changelog
my $VERSION=	"2012-12-12_0";
# My Homepage: 	http://www.thomas-dohl.de/
#
# Licence : 	GPL3 - http://www.gnu.org/licenses/gpl-3.0.txt
#
# Description:
# Get status from KEMP LoadMaster.
# (http://www.kemptechnologies.com/)
# Tested on a LoadMaster 2200 v5.1-74
# No MIB has to be installed.
#
# Important:
# This plugin doesn't work with firmware 5.1-Patch71 or earlier because of a SNMP Bug in it!
#
################################################################################
#
# 2012-12-12_0	* fix: did not prevent output in none ha state
#
# 2012-11-22_0	* new: more performance values with option --longperf
#                 Attention, for pnp4nagios you need to setup the storagetype to multiple (RRD_STORAGE_TYPE = MULTIPLE)
#		  http://docs.pnp4nagios.org/de/pnp-0.6/tpl_custom?s[]=multiple#rrd_storage_type
#		* change: because of feedback, I changed the Colors of unused warnings colors to unknown
#		  now every warningcolor is the reason for returnstatus warning
# 		* improve: add <nobr> to html output
# 		* improve: status of real server (now it should work on all loadmaster systems)
#		  it is a linux based OID, it proviedes the arp table
#
# 2012-05-25_0	* bugfix: now the script can handle loadmaster's whithout services -> now it works :)
#
# 2012-05-24_0	* new: no Error/Warning if a Slave is monitored
#		* bugfix: now the script can handle loadmaster's whithout services
#
# 2012-04-03_0	* bugfix for Loadmaster Version 5.1-74 
#		  ( OID vSidx does not exist in 5.1. )
#
# 2012-03-26_0	* new: an other oid for RealServerStatus
#
# 2012-03-07_0	* change: disabled reale servers are not warning any more
#
# 2012-03-06_0	* bugfix: vService numbers are not consecutive
#
# 2012-02-21_0	* change: disabled services are not warning any more
#
# 2012-02-09_0	* new: Support new Firmware 6.0
#
# 2011-12-08_0	* new: redirect -> status ok
#		* bugfix: small changes of the html-view
#
# 2011-12-07_0	* change: suppress a warning if no RS is defined for a VS
#
# 2011-12-01_0	* change: if the first snmp_get isn't successfull, then the 
#		  plugin return with critical
#		* change: small changes
#
# 2011-11-25_0	* change: Port 2 on KEMP Loadmaster means any port (*)
#		* new: an other OID for RealServerStatus
#		* new: add port output for virtual service
#
# 2011-11-21_0	* bugfix: getRSonVSStatus
#		  many thanks to Bernd Kosmahl
#	 	* code cleaning
#
# 2011-10-18_0 	* first release  
#
#
################################################################################
# TODO
#
#
################################################################################
#
# Help: ./check_loadmaster.pl -h
#

use strict;
use warnings;
use Net::SNMP qw(ticks_to_time);
use Time::HiRes qw(gettimeofday);       # time measurement
use Getopt::Long;
use Data::Dumper;
Getopt::Long::Configure('bundling');
$| = 1;                                 # don't buffer stdout

my %time;
$time{'START'}=gettimeofday();          # time measurement start

my $OID;
$OID->{'5.1'}->{'Name'}			='1.3.6.1.2.1.1.5.0';			# string
#$OID->{'5.1'}->{'patchVersion'}	='not available in this version';	# string (not the loadmaster firmware-version)
$OID->{'5.1'}->{'Uptime'}		='1.3.6.1.2.1.1.3.0';			# timeticks
$OID->{'5.1'}->{'totRSDesc'}		='1.3.6.1.4.1.12196.12.8.1.2';		# table -> OctetString
$OID->{'5.1'}->{'numServices'}		='1.3.6.1.4.1.12196.13.0.2.0';		# integer
#$OID->{'5.1'}->{'vSidx'}		='not available in this version';	# table -> integer
$OID->{'5.1'}->{'vSname'}		='1.3.6.1.4.1.12196.13.1.1.14';		# table -> OctetString
$OID->{'5.1'}->{'vSstate'}		='1.3.6.1.4.1.12196.13.1.1.15';		# table -> integer
$OID->{'5.1'}->{'Load'}			='1.3.6.1.4.1.2021.10.1.2';		# table -> OctetString
$OID->{'5.1'}->{'LoadValue'}		='1.3.6.1.4.1.2021.10.1.3';		# table -> OctetString
$OID->{'5.1'}->{'rSvidx'}		='1.3.6.1.4.1.12196.12.2.1.1';		# table -> integer
$OID->{'5.1'}->{'rSstate'}		='1.3.6.1.4.1.12196.13.2.1.6';		# table -> integer
$OID->{'5.1'}->{'rSDesc'}		='1.3.6.1.4.1.12196.12.2.1.11';		# table -> OctetString
$OID->{'5.1'}->{'rSip'}			='1.3.6.1.4.1.12196.13.2.1.2';		# table -> IpAddress
$OID->{'5.1'}->{'vSDesc'}		='1.3.6.1.4.1.12196.12.1.1.11';		# table -> OctetString
$OID->{'5.1'}->{'hAstate'}		='1.3.6.1.4.1.12196.13.0.9.0';		# integer 
$OID->{'5.1'}->{'RealServerStatus'}	='1.3.6.1.2.1.4.35.1.7';		# table -> integer
$OID->{'5.1'}->{'CpuRawSystem'}		='1.3.6.1.4.1.2021.11.52.0';		# counter32

$OID->{'6.0'}->{'Name'}			=$OID->{'5.1'}->{'Name'};
$OID->{'6.0'}->{'patchVersion'}		='1.3.6.1.4.1.12196.13.0.10.0';
$OID->{'6.0'}->{'Uptime'}		=$OID->{'5.1'}->{'Uptime'};
$OID->{'6.0'}->{'totRSDesc'}		=$OID->{'5.1'}->{'totRSDesc'};
$OID->{'6.0'}->{'numServices'}		=$OID->{'5.1'}->{'numServices'};
$OID->{'6.0'}->{'vSidx'}		='1.3.6.1.4.1.12196.13.1.1.1';
$OID->{'6.0'}->{'vSname'}		='1.3.6.1.4.1.12196.13.1.1.13';
$OID->{'6.0'}->{'vSstate'}		='1.3.6.1.4.1.12196.13.1.1.14';
$OID->{'6.0'}->{'Load'}			=$OID->{'5.1'}->{'Load'};
$OID->{'6.0'}->{'LoadValue'}		=$OID->{'5.1'}->{'LoadValue'};
$OID->{'6.0'}->{'rSvidx'}		='1.3.6.1.4.1.12196.12.2.1.2';
$OID->{'6.0'}->{'rSstate'}		='1.3.6.1.4.1.12196.13.2.1.8';
$OID->{'6.0'}->{'rSDesc'}		='1.3.6.1.4.1.12196.12.2.1.11';
$OID->{'6.0'}->{'rSip'}			=$OID->{'5.1'}->{'rSip'};
$OID->{'6.0'}->{'vSDesc'}		=$OID->{'5.1'}->{'vSDesc'};
$OID->{'6.0'}->{'hAstate'}		=$OID->{'5.1'}->{'hAstate'};
$OID->{'6.0'}->{'RealServerStatus'}	=$OID->{'5.1'}->{'RealServerStatus'};
$OID->{'6.0'}->{'vSConns'}              ='1.3.6.1.4.1.12196.12.1.1.12';		# table -> counter32
$OID->{'6.0'}->{'vSInPks'}              ='1.3.6.1.4.1.12196.12.1.1.13';		# table -> counter32
$OID->{'6.0'}->{'vSOutPks'}             ='1.3.6.1.4.1.12196.12.1.1.14';		# table -> counter32
$OID->{'6.0'}->{'CpuRawSystem'}		=$OID->{'5.1'}->{'CpuRawSystem'};	# counter32




my $snmpStatus;
# realserverstatus not in Kemp MIB
# ipNetToPhysicalState 
# http://tools.cisco.com/Support/SNMP/do/BrowseOID.do?local=en&translate=Translate&objectInput=1.3.6.1.2.1.4.35.1.7

$snmpStatus->{'realserver'}->{'1'}='reachable';
$snmpStatus->{'realserver'}->{'2'}='stale';
$snmpStatus->{'realserver'}->{'3'}='delay';
$snmpStatus->{'realserver'}->{'4'}='probe';
$snmpStatus->{'realserver'}->{'5'}='invalid';
$snmpStatus->{'realserver'}->{'6'}='unknown';
$snmpStatus->{'realserver'}->{'7'}='incomplete';
$snmpStatus->{'realserver'}->{'20'}='not in use';
# vSstate in MIB available
$snmpStatus->{'vSstate'}->{'1'}='inService';
$snmpStatus->{'vSstate'}->{'2'}='outOfService';
$snmpStatus->{'vSstate'}->{'3'}='failed';
$snmpStatus->{'vSstate'}->{'4'}='disabled';
$snmpStatus->{'vSstate'}->{'5'}='sorry';
$snmpStatus->{'vSstate'}->{'6'}='redirect';
# hAstate
$snmpStatus->{'hAstate'}->{'0'}='none';
$snmpStatus->{'hAstate'}->{'1'}='Master';
$snmpStatus->{'hAstate'}->{'2'}='Standby';
$snmpStatus->{'hAstate'}->{'3'}='Passive';



my $data;	# **** hash of all information **** (most important hash)

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);	# nagios/icinga because I don't like util.pm ...
my %ERROR_NUMBERS;
foreach (keys %ERRORS){$ERROR_NUMBERS{$ERRORS{$_}}=$_;}				# Now the string is available over the number

####################################################################################################

$data->{'output'}='';
$data->{'perfdata'}=' ';
$data->{'returncode'}=0;

$SIG{'ALRM'} = sub {exitU("Plugin Timeout");};

my $ARGV_tmp='';
foreach(@ARGV){$ARGV_tmp.="$_ ";} # just for debugging
my $lmv;
# read user options
my ($opt_h,$opt_C,$opt_p,$opt_H,$opt_t,$DEBUG,$opt_i,$opt_I,$opt_w,$opt_c,$opt_html,$opt_longperf);
GetOptions(
        "h|help"   	=> \$opt_h,
        "C=s" => \$opt_C,   "community=s" 	=> \$opt_C,
        "p=i" => \$opt_p,   "port=i"      	=> \$opt_p,
        "t=i" => \$opt_t,   "timeout=i"   	=> \$opt_t,
        "H=s" => \$opt_H,   "hostname=s"  	=> \$opt_H,
        "d+"  => \$DEBUG,   "debug+"      	=> \$DEBUG,
        "I=s" => \$opt_I,   "ignoreHosts=s"	=> \$opt_I,
        "i=s" => \$opt_i,   "ignoreServices=s"	=> \$opt_i,
        "w=s" => \$opt_w,   "warning=s"		=> \$opt_w,
        "c=s" => \$opt_c,   "critical=s"	=> \$opt_c,
    			    "longperf"		=> \$opt_longperf,
    			    "withhtml"		=> \$opt_html,
) or print_help();
print_help() if ($opt_h);

# check parameter
if(!defined $opt_H){
    print "Hostaddress required!\n\n";
    print_help();
}    
# some defaults
unless(defined $opt_C){$opt_C='public'};
unless(defined $opt_p){$opt_p=161};
unless(defined $opt_t){$opt_t=15};
#  $opt_t <= 1 not allowed
if($opt_t <= 1){$opt_t=2;}
unless(defined $DEBUG){$DEBUG=0};
if(defined $opt_w){@{$data->{'load'}->{'warning'}} =split(/,/,$opt_w);}
if(defined $opt_c){@{$data->{'load'}->{'critical'}}=split(/,/,$opt_c);}
if(defined $opt_html){setHTML()};

unless($DEBUG){alarm($opt_t+1);}	# give snmp a chance to timeout :-)

debug("Debuglevel -> $DEBUG\n");
debug("Version: $VERSION\n");
debug("Command: $0 ".$ARGV_tmp."\n");
debug("start snmp connection\n");
my ($session, $error);
($session, $error) = Net::SNMP->session(
    -hostname  => $opt_H,
    -community => $opt_C,
    -timeout   => ($opt_t/2),		# whatever the reason is ...
    -port      => $opt_p,
    -translate => [
		    -timeticks => 0x0   # Turn off so sysUpTime is numeric
                  ]

) or exitU("SNMP-Error: init \"".$session->error.'"');

if (!defined($session)) {exitU("No Session: ".$session->error);}
debug("snmp connection successful\n");
# MAIN ####################################################################################################


# guess Loadmaster version
$data->{'patchVersion'} = get_data_try($OID->{'6.0'}->{'patchVersion'});
if      ($data->{'patchVersion'} eq "-1"){
    debug("* Loadmaster patch version 5.1-x or older *\n");
    $lmv='5.1';
}
elsif   ($data->{'patchVersion'} =~ /^6\.0.*/){
    debug("* Loadmaster patch version 6.0-x ($data->{'patchVersion'}) *\n");
    $lmv='6.0';
}
else    {
    print "*** Unknown Loadmaster Version ***\n";
    $lmv='6.0';
}

{
# Returncode of the functions 0 -> ok, 1... -> not ok (at the moment) :-)
my $r=0;
# 1
$r=getDeviceInformation();
# 2
unless($r){$r=getRealServerStatus();}
# 3
unless($r){$r=getVirtualServiceStatus();}
# 4
#unless($r){$r=getRSonVSStatus();}
# 5
if($r==0 and defined $opt_longperf){$r=getLongPerfData();}
}

# prepend output prefix (OK, WARNING, ...) 
$data->{'output'}=$ERROR_NUMBERS{setGetReturncode()}.": ".$data->{'output'};

# calculate run-time
$time{'STOP'}=gettimeofday();           # time measurement stop
$time{'RESULT'}=sprintf("%.0f", (($time{'STOP'}-$time{'START'})*1000));
$time{'RESULT_SEC'}=sprintf("%.0f",(($time{'RESULT'}/1000)%60));
$time{'RESULT_MIN'}=sprintf("%.0f",(($time{'RESULT'}/1000/60)%60));
$time{'RESULT_H'}=sprintf("%.0f",($time{'RESULT'}/1000/60/60));
$data->{'perfdata'}.="'ScriptRunTime'=$time{'RESULT'}ms;;;; ";
debug("total runtime: $time{'RESULT'} ms ($time{'RESULT_H'} h, $time{'RESULT_MIN'} min, $time{'RESULT_SEC'} sec)\n");

# the most important hash is $data
# there are all information saved
#****************************
debug("*"x80 ."\n",2,0);
debug("Datadump: ".Data::Dumper->Dump([$data], ["data"]),2);
debug("*"x80 ."\n",2,0);
#****************************

# last output
print "$data->{'output'}|$data->{'perfdata'}\n";
exit setGetReturncode();

#####################################################################################################

#
# get name of the device and some other information
sub getDeviceInformation{

    #
    # get system name
    debug("***sub getDeviceInformation()***\n");
    $data->{'SystemName'} = get_data($OID->{$lmv}->{'Name'});
    debug("System Name: $data->{'SystemName'}\n",2);
    $data->{'output'}.="LoadBalancer: $data->{'SystemName'} ";

    $data->{'hAstate'} = get_data($OID->{$lmv}->{'hAstate'});
    debug("hAsate: $data->{'hAstate'}\n",2);
    if(defined $opt_html){$data->{'output'}.='<b>';}
    $data->{'output'}.="*".$snmpStatus->{'hAstate'}->{$data->{'hAstate'}}."* ";
    if(defined $opt_html){$data->{'output'}.='</b>';}

    #
    # get system version -> no usefull information
#    $data->{'SystemVersion'} = get_data($OID->{$lmv}->{'Version'});
#    debug("Version: $data->{'SystemVersion'}\n",2);
#    $data->{'output'}.="Version=$data->{'SystemVersion'} ";
    
    #
    # get system uptime
    $data->{'Uptime'} = get_data($OID->{$lmv}->{'Uptime'});
    debug("Uptime: ".ticks_to_time($data->{'Uptime'})."\n",2);
    $data->{'output'}.="Uptime: ".ticks_to_time($data->{'Uptime'})." ";
    
    #
    # get system load and calculate warning and critical level
    $data->{'output'}.="Load: ";
    my $response = get_data_table($OID->{$lmv}->{'Load'});
    foreach my $i (sort keys %$response){
	my $number=substr($i,rindex($i,".")+1);
	$number--;
	push(@{$data->{'load'}->{'name'}},$response->{$i});
	push(@{$data->{'load'}->{'value'}},get_data($OID->{$lmv}->{'LoadValue'}.".".($number+1)));

	$data->{'output'}.=$data->{'load'}->{'value'}[$number].",";
	$data->{'perfdata'}.="'".$data->{'load'}->{'name'}[$number]."'=".$data->{'load'}->{'value'}[$number];
	foreach my $level ('warning','critical'){
	    $data->{'perfdata'}.=";";
	    if(defined $data->{'load'}->{$level}[$number]){
		debug("Checking $level($number): ".$data->{'load'}->{$level}[$number]." System-Value: ".$data->{'load'}->{'value'}[$number]."\n",2);
		$data->{'perfdata'}.=$data->{'load'}->{$level}[$number];
		if( $data->{'load'}->{'value'  }[$number] >=  $data->{'load'}->{$level}[$number] ){
		    debug("*** Set Load to $level ***\n");
		    setGetReturncode($ERRORS{uc($level)});
		}
	    }
	}
	$data->{'perfdata'}.=";; ";
    }
    chop($data->{'output'});	# remove the last "," from the "output" just for a better look :-)

    # get perfdata for CpuRawSystem (datatype counter)
    if(defined $opt_longperf){
	debug("Getting Perfdata: CpuRawSystem\n",2);
	$response = get_data($OID->{$lmv}->{'CpuRawSystem'});
	$data->{'CpuRawSystem'}=$response;
	$data->{'perfdata'}.="'CpuRawSystem'=$response"."c ";
    }


    
    # loadmaster is Master (1) or 
    #            in   none (0) ha state
    if($data->{'hAstate'} == 1 || $data->{'hAstate'} == 0){return 0;}
    return 1;
}

#
# get all real server and there state
sub getRealServerStatus{
    debug("***sub getRealServerStatus()***\n");
    my $response = get_data_table_try($OID->{$lmv}->{'totRSDesc'});
    if ($response == -1){debug("No Real Server found! Nothing defined in loadmaster?");return 1;}
    my $response_rs_status=get_data_table_try($OID->{$lmv}->{'RealServerStatus'});
    my $number=keys %{$response};
    $data->{'output'}.="\nReal Server ($number): ";
    foreach my $i (sort keys %{$response}){
	my $rs_ip=$response->{$i};
	debug("Server: $rs_ip -> ",2);
	if(ignoreItem($rs_ip,$opt_I)){next;}
	$data->{'RealServer'}->{$rs_ip}='20';
	
	debug("Server: $rs_ip -> ",2);
	foreach my $rs_oid (keys %{$response_rs_status}){
	    if($rs_oid =~ /$rs_ip$/){$data->{'RealServer'}->{$rs_ip}=$response_rs_status->{$rs_oid};}
	}
	debug("$data->{'RealServer'}->{$rs_ip} ($snmpStatus->{'realserver'}->{$data->{'RealServer'}->{$rs_ip}})\n",2,0);

	# only value 1 is ok and 20 means the ip is not in use or there was no traffic over a certain time
	if($data->{'RealServer'}->{$rs_ip} !=  1 and
	   $data->{'RealServer'}->{$rs_ip} != 20 ){setGetReturncode($ERRORS{'WARNING'});}
	if(defined $opt_html){$data->{'output'}.="<nobr>";}
	$data->{'output'}.="$rs_ip=$snmpStatus->{'realserver'}->{$data->{'RealServer'}->{$rs_ip}} ";
	if(defined $opt_html){$data->{'output'}.="</nobr> ";}
    }
    return 0;
}

#
# get all virtual services and there state
sub getVirtualServiceStatus{
    debug("***sub getVirtualServiceStatus()***\n");
    my $number=get_data($OID->{$lmv}->{'numServices'});
    $data->{'output'}.="\nVirtual Services ($number): ";
    my $vSidx;
    # version older than 6.0
    unless(defined $OID->{$lmv}->{'vSidx'}){foreach my $i (1..$number){$vSidx->{$i}=$i;}}
    # version from 6.0
    else{$vSidx = get_data_table($OID->{$lmv}->{'vSidx'});}
    my $i;
    foreach my $key (keys %{$vSidx}){
	$i=$vSidx->{$key};
	debug("get name of vSservice ($i)\n",2);
	$data->{'vSservice'}->{$i}->{'name'}=get_data($OID->{$lmv}->{'vSname'}.".".($i));
	if($data->{'vSservice'}->{$i}->{'name'} eq ''){$data->{'vSservice'}->{$i}->{'name'}="NO NAME $i";}	# replace empty name of vService with his SNMP ID

	get_data($OID->{$lmv}->{'vSDesc'}.".".($i)) =~ /^(\w+) (.+):(\d+) (\w+)$/;
	$data->{'vSservice'}->{$i}->{'protokoll'}=$1;
	$data->{'vSservice'}->{$i}->{'ip'}=$2;
	$data->{'vSservice'}->{$i}->{'port'}=$3;
	$data->{'vSservice'}->{$i}->{'schedulingMethod'}=$4;
	if($data->{'vSservice'}->{$i}->{'port'} == 2){$data->{'vSservice'}->{$i}->{'port'}='*';}		# a characteristic of Kemp Loadmaster: Port 2 means all Ports (*)
	debug("name of vSservice ($i): $data->{'vSservice'}->{$i}->{'name'} -> ",2);
	if(ignoreItem($data->{'vSservice'}->{$i}->{'name'},$opt_i)){delete $data->{'vSservice'}->{$i};next;}
	debug("get state of vSservice ($i)\n",2);
	$data->{'vSservice'}->{$i}->{'vSstate'}=get_data($OID->{$lmv}->{'vSstate'}.".".($i));
	# only value 1 or 4 or 6 is ok
	unless( $data->{'vSservice'}->{$i}->{'vSstate'} == 1 or
		$data->{'vSservice'}->{$i}->{'vSstate'} == 4 or
		$data->{'vSservice'}->{$i}->{'vSstate'} == 6 ){setGetReturncode($ERRORS{'WARNING'});}
	if(defined $opt_html){$data->{'output'}.="<nobr>";}
	$data->{'output'}.="\"$data->{'vSservice'}->{$i}->{'name'}\"=$snmpStatus->{'vSstate'}->{$data->{'vSservice'}->{$i}->{'vSstate'}} ";
	if(defined $opt_html){$data->{'output'}.="</nobr> ";}
    }
    return 0;
}


#
# get Real Server used by Virtual Services
# and get there state
sub getRSonVSStatus{
    debug("***sub getRSonVSStatus()***\n");
    my $response = get_data_table($OID->{$lmv}->{'rSvidx'});
    foreach my $idx (sort keys %{$response}){
	my $number=substr($idx,rindex($idx,".")+1);
	my $rSDesc=get_data($OID->{$lmv}->{'rSDesc'}.".".$number);
	my $ip=get_data($OID->{$lmv}->{'rSip'}.".".$number);
	debug("RS on VS Status: \"$rSDesc\" -> ",2);
	# ignore ip or vservice by opt_I or opt_i
	if(!defined $data->{'vSservice'}->{$response->{$idx}}){
	    debug("ignored!!!\n",2,0);
	    next;
	}
	
	$data->{'vSservice'}->{$response->{$idx}}->{'realServerCounter'}++;
    
	if (!defined $data->{'RealServer'}->{$ip}){
	    debug("ignored!!!\n",2,0);
	    next;
	}


	debug("used.\n",2,0);
	if($data->{'vSservice'}->{$response->{$idx}}->{'port'} eq '*'){$rSDesc=~s/:2 /:* /o;}		# a characteristic of Kemp Loadmaster: Port 2 means all Ports (*) -> if vSservice Port is 2
	$data->{'vSservice'}->{$response->{$idx}}->{'realServer'}->{$number}->{'desc'}=$rSDesc;
	$data->{'vSservice'}->{$response->{$idx}}->{'realServer'}->{$number}->{'ip'}=$ip;
	$data->{'vSservice'}->{$response->{$idx}}->{'realServer'}->{$number}->{'state'}=get_data($OID->{$lmv}->{'rSstate'}.".".$number);
	# only value 1 or 4 is ok
	unless( $data->{'vSservice'}->{$response->{$idx}}->{'realServer'}->{$number}->{'state'} == 1 or
		$data->{'vSservice'}->{$response->{$idx}}->{'realServer'}->{$number}->{'state'} == 4){setGetReturncode($ERRORS{'WARNING'});}
    }

    # new output
    # just for output, for a better look
    foreach my $vSservice (sort{$a<=>$b} keys %{$data->{'vSservice'}}){
	unless(defined $data->{'vSservice'}->{$vSservice}){next;}
	unless(defined $data->{'vSservice'}->{$vSservice}->{'realServerCounter'}) {$data->{'vSservice'}->{$vSservice}->{'realServerCounter'}=0;}
#	my $number=keys %{$data->{'vSservice'}->{$vSservice}->{'realServer'}};				# show the number of displayed RS
	my $number=$data->{'vSservice'}->{$vSservice}->{'realServerCounter'};				# show the real number of RS
	$data->{'output'}.="\nRS on VS State ".$data->{'vSservice'}->{$vSservice}->{'name'}.':'.$data->{'vSservice'}->{$vSservice}->{'port'}." ($number): ";
	foreach my $rs (sort keys %{$data->{'vSservice'}->{$vSservice}->{'realServer'}}){
	    if(defined $opt_html){$data->{'output'}.="<nobr>";}
	    $data->{'output'}.="\"".$data->{'vSservice'}->{$vSservice}->{'realServer'}->{$rs}->{'desc'}."\"=";
	    $data->{'output'}.=$snmpStatus->{'vSstate'}->{$data->{'vSservice'}->{$vSservice}->{'realServer'}->{$rs}->{'state'}}." ";
	    if(defined $opt_html){$data->{'output'}.="</nobr> ";}
	}
    }
}

#
# get perfdata for virtual server
# vSConns vSInPks vSOutPks
sub getLongPerfData{
    debug("***sub getLongPerfData()***\n");
    my $response;

#    # get perfdata for list of single value oid's (datatype counter)
#    foreach my $perfdatastring ('CpuRawSystem'){
#	debug("Getting Perfdata: $perfdatastring\n",2);
#	$response = get_data($OID->{$lmv}->{$perfdatastring});
#	$data->{$perfdatastring}=$response;
#	$data->{'perfdata'}.="'$perfdatastring'=$response"."c ";
#    }

    # get perfdata for vservices (datatype counter)
    foreach my $perfdatastring ('vSConns','vSInPks','vSOutPks'){
	debug("Getting Perfdata: $perfdatastring\n",2);
	$response = get_data_table($OID->{$lmv}->{$perfdatastring});
	foreach my $oid(keys %{$response}){
    	    my $vSservice=substr($oid,rindex($oid,".")+1);
    	    unless(defined $data->{'vSservice'}->{$vSservice}){next;}
	    $data->{'vSservice'}->{$vSservice}->{$perfdatastring}=$response->{$oid};
	    
	    my $name=$vSservice;					# if name is empty, use the snmp-id to identify the perfdata
	    if($data->{'vSservice'}->{$vSservice}->{'name'} ne ''){$name=$data->{'vSservice'}->{$vSservice}->{'name'};}
	    $data->{'perfdata'}.="'".$perfdatastring.'_'.$name."'=$response->{$oid}c ";
	}
    }
    return 0;
}

#
# get returncode if no new returncode is set
# set returncode (highest wins)
sub setGetReturncode{
    my $ret=shift;
    unless(defined $ret){$ret=0;}
    unless(defined $ERROR_NUMBERS{$ret}){
	debug("SetGetReturncode: \"$ret\" UNKNOWN returncode!!!\n");
	$ret=$ERRORS{'UNKNOWN'};
    }
    debug("SetGetReturncode: in=$ret saved=$data->{'returncode'} ",3);
    if($ret>$data->{'returncode'}){$data->{'returncode'}=$ret;}
    debug("new=$data->{'returncode'}\n",3,0);
    return $data->{'returncode'};
}

#
# get an entire subtable of a oid
# returns a hash
sub get_data_table {
    my $oid=shift;
    my $response;
    debug("get data table for OID: $oid\n",3);
    $response = $session -> get_table(-baseoid=>$oid) or exitU("SNMP-Error: get_table ($oid) \"".$session->error.'"');
    debug("Datadump: ".Data::Dumper->Dump([$response], ["response"]),3);
    return $response;    
}

#
# get only the value of a oid
# returns a value
sub get_data {
    my $oid=shift;
    my $response;
    debug("get data for OID: $oid\n",3);
    $response = $session->get_request($oid) or exitU("SNMP-Error: get_request ($oid) \"".$session->error.'"');
    my @SNMP_values = values %$response;
    debug("Data for oid $oid: $SNMP_values[0]\n",3);
    return $SNMP_values[0];    
}

#
# get only the value of a oid
# returns a value or -1 if not successful
sub get_data_try {
    my $oid=shift;
    my $response;
    debug("try get data for OID: $oid\n",3);
    $response = $session->get_request($oid);
    unless (defined $response){
	debug("try failed: \"".$session->error."\" OID: $oid\n");
	if($session->error =~ /^No response from remote host/){exitU($session->error);} # not the best way but I don't know a better one :)
	return(-1);
    }
    my @SNMP_values = values %$response;
    debug("Data for oid $oid: $SNMP_values[0]\n",3);
    return $SNMP_values[0];    
}


#
# get an entire subtable of a oid
# returns a hash or -1 if not successful
sub get_data_table_try {
    my $oid=shift;
    my $response;
    debug("try get data table for OID: $oid\n",3);
    $response = $session -> get_table(-baseoid=>$oid);
    unless (defined $response){
	debug("try failed: \"".$session->error."\" OID: $oid\n");
	if($session->error =~ /^No response from remote host/){exitU($session->error);}
	return(-1);
    }
    debug("Datadump: ".Data::Dumper->Dump([$response], ["response"]),3);
    return $response;    
}



#
# compare a single value with a comma separeted list of values
sub ignoreItem{
    my $item=shift;
    my $listOfItems=shift;
    unless(defined $listOfItems){$listOfItems="";}
    foreach my $i (split(/,/,$listOfItems)){if("$i" eq "$item"){debug("ignored!!!\n",2,0);return 1;}}
    debug("used.\n",2,0);return 0;
}

#
# a small debug output function
sub debug{
    my $msg=shift;
    my $level=shift;
    my $head=shift;
    $msg =~ s/(.*)\n(.+)/$1\nDebug...\t$2/g;	# easier look and file with multiline debug output
    unless(defined $level){$level=1;}
    unless(defined $head ){$head =1;}
    if ($DEBUG >= $level){
	if($head){print "Debug $level: ";}
	print "$msg";
    }
}

#
# put some nice html tags into the output
sub setHTML{

    ### state ###
    # head
    my $h="<DIV CLASS='service";
    # tail
    my $t=" </DIV>";
    # other
    my $x="'> ";
    
    # color assignment
    $snmpStatus->{'realserver'}->{'20'} ="UNKNOWN$x".$snmpStatus->{'realserver'}->{'20'};
    $snmpStatus->{'realserver'}->{'1'}  ="OK$x"     .$snmpStatus->{'realserver'}->{'1'};
    $snmpStatus->{'realserver'}->{'2'}  ="UNKNOWN$x".$snmpStatus->{'realserver'}->{'2'};
    $snmpStatus->{'realserver'}->{'3'}  ="UNKNOWN$x".$snmpStatus->{'realserver'}->{'3'};
    $snmpStatus->{'realserver'}->{'4'}  ="UNKNOWN$x".$snmpStatus->{'realserver'}->{'4'};
    $snmpStatus->{'realserver'}->{'5'}  ="UNKNOWN$x".$snmpStatus->{'realserver'}->{'5'};
    $snmpStatus->{'realserver'}->{'6'}  ="WARNING$x".$snmpStatus->{'realserver'}->{'6'};
    $snmpStatus->{'vSstate'}->{'1'}     ="OK$x"     .$snmpStatus->{'vSstate'}->{'1'};
    $snmpStatus->{'vSstate'}->{'2'}     ="WARNING$x".$snmpStatus->{'vSstate'}->{'2'};
    $snmpStatus->{'vSstate'}->{'3'}     ="WARNING$x".$snmpStatus->{'vSstate'}->{'3'};
    $snmpStatus->{'vSstate'}->{'4'}     ="UNKNOWN$x".$snmpStatus->{'vSstate'}->{'4'};
    $snmpStatus->{'vSstate'}->{'5'}     ="WARNING$x".$snmpStatus->{'vSstate'}->{'5'};
    $snmpStatus->{'vSstate'}->{'6'}     ="OK$x"     .$snmpStatus->{'vSstate'}->{'6'};
    
    # set header and end for the strings
    foreach my $i1 ('realserver','vSstate'){
	foreach my $i2 (keys  %{$snmpStatus->{$i1}}){
	    $snmpStatus->{$i1}->{$i2}=$h.$snmpStatus->{$i1}->{$i2};
	    $snmpStatus->{$i1}->{$i2}.=$t;
	}
    }
}


#
# output a string an exit with unkown instead of "die"
sub exitU{
    my $msg=shift;

    # the most important hash is $data
    # there are all information saved
    #****************************
    debug("*"x80 ."\n",2,0);
    debug("Datadump: ".Data::Dumper->Dump([$data], ["data"]),2);
    debug("*"x80 ."\n",2,0);
    #****************************

    print "UNKNOWN: $msg\n";
    exit $ERRORS{"UNKNOWN"};
}



#
# print out the help
sub print_help{
    print <<EOF;
Version: $VERSION
usage: $0 -H hostaddress [-C snmp-community]
    -H --hostname=Hostname  Hostaddress
    -C --community=public   SNMP community (default is public)
    -p --port=161           SNMP port (default is 161)
    -I --ignoreHosts=IP-Address,IP-Address
                            ignore real server
    -i --ignoreServices=VirtualServiceName,VirtualServiceName
                            ignore virtual services
    -w --warning=1min,5min,15min
			    Load warning
    -c --critical=1min,5min,15min
			    Load critical
    -h --help               show this help
    -d --debug              debugging (-ddd for max debugging)
    --withhtml		    insert html tags to format output
    --longperf		    dynamic perfdata of virtualServer Packets and Connections
    example:
    $0 -H 192.168.0.1 -C public
EOF
    exit $ERRORS{"UNKNOWN"};
}

