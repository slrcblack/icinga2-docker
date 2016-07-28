#!/usr/bin/perl
#
#
# nrpe-script for monitoring pound backends
#
# -- depends on pounds poundctl --
#
# initial version: 22 may 2008 by martin probst <maddin(at)megamaddin(dot)de>
# current status: $Revision: 6 $
#
# Copyright Notice: GPL
#


use strict;
use warnings;

## nagios exit codes
use constant STATE_OK => 0;
use constant STATE_WARNING => 1;
use constant STATE_CRITICAL => 2;
use constant STATE_UNKNOWN => 3;
use constant STATE_DEPENDENT => 4;

## if we're dying unexpectely, we'll send status unknown
$SIG{KILL} = $SIG{TERM} = sub{ exit( STATE_UNKNOWN ); };

## unix-socket(s) for pound
my @poundSock = ( "/var/lib/pound/pound.cfg" );

## path to executable
my $poundctl = "/usr/bin/sudo /usr/sbin/poundctl";
my $cur;
my $mess;
my $good = 0;
my $bad = 0;
my $allbe = 0;

## percentage rate, how many backends can die until we warn
my $warn = $ARGV[0];
my $crit = $ARGV[1];

my $state = STATE_UNKNOWN;

foreach my $unixSock( @poundSock )
{
    if( -S $unixSock )
    {
        foreach( `$poundctl -c $unixSock` )
        {
            next if (m/.*http.*listener.*/ig);
            if (m/.*\d\.\sService\s"(.*)"\sactive.*/i)
            {
                $cur = $1;
            }
            elsif (m/.*BACKEND.*/i)
            {
                my ($be,$ipAdd,$port) = m/.*(\d)\..*\D(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d{1,5})\D.*/;
                $allbe++;
                unless( $_ =~ m/.*alive.*/i )
                {
                    $mess .= "Backend ($ipAdd$port) on service $cur is down<br>";
                    $bad++;
                }
                else
                {
                    $good++;
                }
            }
        }
    }
}

if( $good == 0 && $bad == 0 )
{
	print "State Unknown";
	exit( $state );
}
elsif( (100*$bad/$allbe) >= $crit )
{
    print $mess;
    exit( STATE_CRITICAL );
}
elsif( (100*$bad/$allbe) >= $warn )
{
    print $mess;
    exit( STATE_WARNING );
}
else
{
    print "All backends OK.";
    exit( STATE_OK );
}
