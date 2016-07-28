#!/usr/bin/perl
# Weldon Godfrey 2009.03.05
# Nagios plugin For APC 7750 Automated Transfer Switches
# given snmp community and hostname(or ip address), it will check that device to see if
#  1.  the preferred power source, as defined in the device itself, is in use
#  2.  if both power sources are in use, therefor fully redunant


use lib "/usr/lib64/nagios/plugins";
use utils qw(%ERRORS $TIMEOUT &print_revision &support);
use vars qw($PROGNAME $PORT $CRIT $WARN $opt_H $opt_P $opt_V $opt_c $opt_h
            $opt_p $opt_t $opt_u $opt_v $opt_w);



sub getsnmpresult {
        local($instring)=@_;
        my @result = split(': ', $instring);
        return ($result[1]);
};

#MAIN

$ARGC = 1+$#ARGV;

die "$0: usage: $0 HOSTNAME COMMUNITY" unless $ARGV[0]&&$ARGC==2;

$prefstat=getsnmpresult(`/usr/bin/snmpget -v 1 -c $ARGV[1] $ARGV[0] .1.3.6.1.4.1.318.1.1.8.4.2.0`);
$curstat=getsnmpresult(`/usr/bin/snmpget -v 1 -c $ARGV[1] $ARGV[0] .1.3.6.1.4.1.318.1.1.8.5.1.2.0`);
$redunstat=getsnmpresult(`/usr/bin/snmpget -v 1 -c $ARGV[1] $ARGV[0] .1.3.6.1.4.1.318.1.1.8.5.3.1.0`);

if ($prefstat != $curstat) {
        print "WARNING:  Alternate Power Source in Use\n";
        exit $ERRORS{'WARNING'};
}
if ($redunstat != 2 ) {
        print "CRITICAL:  A Power Source is Down, not fully redunant.\n";
        exit $ERRORS{'CRITICAL'};
}

print "OK: Preffered source in use and fully redunant.\n";
exit $ERRORS{'OK'};
