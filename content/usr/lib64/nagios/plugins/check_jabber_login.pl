#!/usr/bin/perl -w

use strict;
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);
use Getopt::Long;
use Net::Jabber;

my ($opt_version,
    $opt_help,
    $opt_port,
    $opt_host,
    $opt_verbose,
    $opt_uname,
    $opt_pass,
    $opt_ssl,
    $state
   );
  
($opt_version,$opt_help,$opt_port,$opt_host,$opt_verbose,$opt_uname,$opt_pass,$opt_ssl) = '';
  
$state = 'UNKNOWN';
$PROGNAME = "check_jabber2";
sub print_help ();
sub print_usage ();

$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
$ENV{'PATH'}='';
$ENV{'LC_ALL'}='C';



Getopt::Long::Configure('bundling');
GetOptions(
        "V"   => \$opt_version,     "version"           => \$opt_version,
        "h"   => \$opt_help,        "help"              => \$opt_help,
        "s"   => \$opt_ssl,         "ssl"               => \$opt_ssl,
        "p=i" => \$opt_port,        "port=i"            => \$opt_port,
        "H=s" => \$opt_host,        "hostname=s"        => \$opt_host,
        "v+"  => \$opt_verbose,     "verbose+"          => \$opt_verbose,
        "u=s"   => \$opt_uname,     "username=s"        => \$opt_uname,
        "P=s"   => \$opt_pass,      "password=s"        => \$opt_pass
);

# -h means display verbose help screen
if ($opt_help) { print_usage(); exit $ERRORS{'OK'}; }

# -V means display version number
if ($opt_version) {
        print_revision($PROGNAME,'$Revision: 1.1 $ ');
        exit $ERRORS{'OK'};
}

if (!$opt_host || !$opt_port || !$opt_uname || !$opt_pass) { print_usage(); exit $ERRORS{'UNKNOWN'}; }

if (! utils::is_hostname($opt_host)){
        print "$opt_host is not a valid host name\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
}
$SIG{'ALRM'} = sub {
        print ("ERROR: No response from server (alarm)\n");
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

checklogin();
  
# Hash containing all RPC program names and numbers
# Add to the hash if support for new RPC program is required

sub checklogin {
    my $jabbercm = "$opt_host";
    my $jabbercmport = "$opt_port";
    my $username = "$opt_uname";
    my $password = "$opt_pass";
    my $is_ssl = 0;
    my $debug = 0;
    $is_ssl = '1' if defined $opt_ssl;
    $debug = '2' if defined $opt_verbose;

    my $ocon = new Net::Jabber::Client(debuglevel=>$debug,file=>'stdout');
    if (!$ocon->Connect('hostname'=>$jabbercm,'port'=>$jabbercmport)) {
        print "CRITICAL: Connection error $jabbercm $jabbercmport $username $password $is_ssl\n";
        exit $ERRORS{'CRITICAL'};
    }
    
    my @resp = $ocon->AuthSend(username=>$username,password=>$password,resource=>'Home',tls=>$is_ssl);
    if ($resp[0] ne "ok") {
       print "CRITICAL: Login error\n";
       exit $ERRORS{'CRITICAL'};
    }
    print "OK: Login for $opt_uname successful\n";
    exit $ERRORS{'OK'};
}
sub print_usage () {
        print "Usage: \n";
        print " $PROGNAME -H host -p port -u username -P password [-s] [--ssl]\n";
        print " $PROGNAME [-h | --help]\n";
        print " $PROGNAME [-V | --version]\n";
}
