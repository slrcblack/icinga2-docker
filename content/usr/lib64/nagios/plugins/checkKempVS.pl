#!/usr/bin/perl

#disable Nagios Perl Interpreter
# nagios: -epn
#Examples
#https://<LoadMasterIPAddress>/access/showvs?vs=<index>&port=<Port>&prot=<tcp/udp>
#curl -k "https://bal:enamaill4@96.4.1.30/access/showvs?vs=172.27.0.180&port=80&prot=tcp"

#https://<LoadMasterIPAddress>/access/stats
#curl -k https://bal:enamaill4@96.4.1.30/access/stats

#Example of snmpwalk
#snmpwalk -v2c -m +IPVS-MIB -c public 96.4.1.30 .1.3.6.1.4.1


use strict;
use Getopt::Std;
use Switch;
use LWP::UserAgent;
use Data::Dumper;
use XML::Simple;
use Net::SNMP qw(ticks_to_time);

my $debug = 0;
#SNMP Configs
my $vsStatusOID = ".1.3.6.1.4.1.12196.13.1.1.14.";
my $rsStatusOID = ".1.3.6.1.4.1.12196.13.2.1.8.";
#my $haStatusOID = '.1.3.6.1.4.1.12196.13.0.9.0';
my $snmpStatus;

#Virtual Service SNMP Return code Definitions
$snmpStatus->{'vsState'}->{1}='inService';
$snmpStatus->{'vsState'}->{2}='outOfService';
$snmpStatus->{'vsState'}->{3}='failed';
$snmpStatus->{'vsState'}->{4}='disabled';
$snmpStatus->{'vsState'}->{5}='sorry';
$snmpStatus->{'vsState'}->{6}='redirect';
#RealServer SNMP Return code Definitions
$snmpStatus->{'realserver'}->{'1'}='reachable';
$snmpStatus->{'realserver'}->{'2'}='stale';
$snmpStatus->{'realserver'}->{'3'}='delay';
$snmpStatus->{'realserver'}->{'4'}='probe';
$snmpStatus->{'realserver'}->{'5'}='invalid';
$snmpStatus->{'realserver'}->{'6'}='unknown';
$snmpStatus->{'realserver'}->{'7'}='incomplete';
$snmpStatus->{'realserver'}->{'20'}='not in use';

#Defaults
my $LMIP="96.4.1.30";
my $user="bal";
my $pass="enamaill4";
my $snmpCom="public";
my $snmpPort="161";
my $timeOut="10";
my $index=7;
my $runList=0;

my %status = ( 'OK'       => 0,
               'WARNING'  => 1,
               'CRITICAL' => 2,
               'UNKNOWN'  => 3
           );
my $exit_status = $status{OK};
my $output;


my $usage =  <<ENDUSAGE;
 This program connects to the specified Kemp LoadMaster via REST API and SNMP
 and then display the relevant status information for the given Virtual Service.

Example:

  checkKempVS.pl -H 1.2.3.4 -u bal -p password -s public -t 10 -i 7


 Syntax: [-hdl] [-H <LM Host or IP>] [-u <user>] [-p <password>] [-s <snmp community>] [-t <timeout in secs>] [-i <VS Index>]
 \t-h :                  Print this help text
 \t-d :                  Print debug messages
 \t-l :                  Print all avail Virtual Services and their index
 \t-H <hostname or ip>:  Specify the Kemp LoadMaster to monitor.
 \t-u <user>:            Username needed to login to the Kemp LoadMaster.
 \t-p <password>:        Password needed to login to the Kemp LoadMaster.
 \t-s <smmp community>:  SNMP community string used to poll the Kemp LoadMaster.                         
 \t-t <timeout>:         Timeout in seconds.
 \t                      (Values larger than montoring timeout will cause problems)
 \t                       Default: $timeOut
 \t-i <index>:           Index of the Virtual Service to be monitored. 
 \t                       Default: $index
 \t-l <type>:            Lists all Virtual Services on the Kemp LoadMaster returning the description and index
ENDUSAGE

sub usage {
  print "$usage\n";
  exit
}

#Subs

# Open SNMP Session
sub openSNMPSession {
    my ($session, $error);
    ($session, $error) = Net::SNMP->session(
    -hostname  => $LMIP,
    -community => $snmpCom,
    -timeout   => ($timeOut/2),
    -port      => $snmpPort,
    -translate => [
                    -timeticks => 0x0   # Turn off so sysUpTime is numeric
                  ]

    ) or die("SNMP-Error: init \"".$session->error.'"');
    
    if (!defined($session)) {die("No Session: ".$session->error);}
   
    return $session;
}

# Return OID Value
sub getOID{
    my ($oid,$session) = @_;
    #print "OID: $oid \n";
    my $response;
    $response = $session->get_request($oid) or die("SNMP-Error: get_request ($oid) \"".$session->error.'"');
    my @SNMP_values = values %$response;
    #print "Value: $SNMP_values[0] \n";
    return $SNMP_values[0];
}

# This sub hits the API and returns the xml data from the API.  It then puts it into a Perl Array
sub getData{
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->agent("checkKempVS.pl");
    $ua->ssl_opts(
                  verify_hostname => 0,
                  SSL_verify_mode => 0
                  );
    
    my  $api_url = 'https://' . $user . ':' . $pass .'@' . $LMIP . '/access/stats';
    
    my $response = $ua->get($api_url);
    if ($response->is_success) {
        #Parse XML
        my $data = XMLin($response->content, KeyAttr => { Vs => 'Index', Rs => 'RSIndex' });
        return $data
    } else {
       $exit_status = $status{UNKNOWN};
       print "Error: ", $response->status_line if $debug;
       print "UNKNOWN - Trouble communicating with LoadMaster!\n";
       exit ($exit_status);
    }
    
}

sub getVSConfig{
    my ($ip, $port, $prot) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->agent("checkKempVS.pl");
    $ua->ssl_opts(
                  verify_hostname => 0,
                  SSL_verify_mode => 0
                  );
    
    my  $api_url = 'https://' . $user . ':' . $pass .'@' . $LMIP . '/access/showvs?vs=' . $ip . '&port=' . $port . '&prot=' . $prot;
    
    my $response = $ua->get($api_url);
    
    if ($response->is_success) {
        #Parse XML
        my $data = XMLin($response->content, KeyAttr => { Rs => 'RsIndex' });
        return $data
        #nothing
    } else {
       $exit_status = $status{UNKNOWN};
       print "Error: ", $response->status_line if $debug;
       print "UNKNOWN - Index Invalid!\n";
       exit ($exit_status);
    }
    
    die "Error: ", $response->status_line unless $response->is_success;
    
}


sub getVSData{
    my ($vsIndex, $array) = @_;
    my $ip = $array->{Success}->{Data}->{Vs}->{$vsIndex}->{VSAddress};
    my $port = $array->{Success}->{Data}->{Vs}->{$vsIndex}->{VSPort};
    my $prot = $array->{Success}->{Data}->{Vs}->{$vsIndex}->{VSProt};
    my $enabled = $array->{Success}->{Data}->{Vs}->{$vsIndex}->{Enable};
    my $array2 = getVSConfig($ip,$port,$prot);
    my $nickName = $array2->{Success}->{Data}->{NickName};
    print "VS Index:\t$vsIndex\n";
    print "NickName:\t$nickName\n";
    print "Enabled:\t$enabled\n";
    print "IPAddress:\t$ip\n";
    print "Port:\t\t$prot $port\n";
    print "\n\n";
}

sub getRSData{
    my ($rsIndex, $array) = @_;
    my $ip = $array->{$rsIndex}->{Addr};
    my $port = $array->{$rsIndex}->{Port};
    my $weight = $array->{$rsIndex}->{Weight};
    my $enabled = $array->{$rsIndex}->{Enable};
    print "\t\tRS Index:\t$rsIndex\n";
    print "\t\tEnabled:\t$enabled\n";
    print "\t\tIPAddress:\t$ip\n";
    print "\t\tPort:\t\t$port\n";
    print "\t\tWeight:\t\t$weight\n";
    #print "\n\n";
}

sub listVS{
    my ($array) = @_;
    my $vsList = $array->{Success}->{Data}->{Vs};
    
    foreach (keys %$vsList){
        getVSData($_, $array);
    }
}

sub listRS{
    my ($array) = @_;
    my $rsList = $array;
    
    foreach (keys %$rsList){
        getRSData($_, $array);
    }
}
#Main

# Parse the command line options
my %cmdline;
getopts("hdlH:u:p:s:t:i:", \%cmdline) or usage();
usage() if defined($cmdline{h});
$runList = 1 if defined($cmdline{l});
$debug = 1 if defined($cmdline{d});
$LMIP = $cmdline{H} if defined($cmdline{H});
$user = $cmdline{u} if defined($cmdline{u});
$pass = $cmdline{p} if defined($cmdline{p});
$snmpCom = $cmdline{s} if defined($cmdline{s});
$timeOut = $cmdline{t} if defined($cmdline{t});
$index = $cmdline{i} if defined($cmdline{i});

my $apiData = getData();

my $enabled = $apiData->{Success}->{Data}->{Vs}->{$index}->{Enable};
my $ip = $apiData->{Success}->{Data}->{Vs}->{$index}->{VSAddress};
my $port = $apiData->{Success}->{Data}->{Vs}->{$index}->{VSPort};
my $prot = $apiData->{Success}->{Data}->{Vs}->{$index}->{VSProt};
my $aconns = $apiData->{Success}->{Data}->{Vs}->{$index}->{ActiveConns};
my $errorCode = $apiData->{Success}->{Data}->{Vs}->{$index}->{ErrorCode};

my $apiVSData = getVSConfig($ip,$port,$prot);
my $nickName = $apiVSData->{Success}->{Data}->{NickName};
my $numReals = $apiVSData->{Success}->{Data}->{NumberOfRSs};
my $rsList = $apiVSData->{Success}->{Data}->{Rs};


my $snmpSession = openSNMPSession();
my $vsStateCode = getOID($vsStatusOID . $index, $snmpSession);
my $vsState = $snmpStatus->{'vsState'}->{$vsStateCode};
my $rsState;

if ($runList) {
    listVS($apiData);
    exit 0;
}

# Make descsion about the status of the VS
switch ($vsStateCode){
	case 1		{
            $exit_status = $status{OK};
            $output = "OK - ($nickName) status is $vsState with $aconns active connections";
        }
	case 2		{
            $exit_status = $status{CRITICAL};
            $output = "CRITICAL - ($nickName) status is $vsState with $aconns active connections";
        }
	case 3		{
            $exit_status = $status{CRITICAL};
            $output = "CRITICAL - ($nickName) status is $vsState with $aconns active connections";
        }
	case 4		{
            $exit_status = $status{WANRING};
            $output = "WARNING - ($nickName) status is $vsState with $aconns active connections";
        }
	case 5		{
            $exit_status = $status{CRITICAL};
            $output = "CRITICAL - ($nickName) status is $vsState with $aconns active connections";
        }
	case 6		{
            $exit_status = $status{CRITICAL};
            $output = "CRITICAL - ($nickName) status is $vsState with $aconns active connections";
        }
	else		{
            $exit_status = $status{UNKNOWN};
            $output = "UNKNOWN - ($nickName) status is $vsState with $aconns active connections";
        }
    }

# Get performance Data

$output .= "|aconns=$aconns;0;0";


#Dump Data
print Dumper($apiData) if $debug;
print Dumper($apiVSData) if $debug;
print Dumper($rsList) if $debug;

if ($debug) {
    print "VS $index \n";
    print "Enabled: " . $enabled . "\n";
    print "VS Status: " . $vsState . "\n";
    print "IPAddress: " . $ip . "\n";
    print "Port: " . $prot . " " . $port . "\n";
    print "Active Connections: " . $aconns . "\n";
    print "Nickname: " . $nickName . "\n";
    print "Number of Reals: " . $numReals . "\n";
    foreach (keys %$rsList){
        getRSData($_, $rsList);
        $rsState = $snmpStatus->{'realserver'}->{getOID($rsStatusOID . $_, $snmpSession)};
        print "\t\tRS Status: \t$rsState\n\n";
    } 
#    print "\n\n";

}

#print final output and exit

print "$output\n";
exit ($exit_status);
