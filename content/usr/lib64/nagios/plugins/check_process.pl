#! /usr/bin/perl -w

#----------------------------------------------------------------------
#--
#-- Autor:
#-- ------
#--
#--    Martin Schmitz, net&works GmbH
#--
#--
#-- Programname:
#-- -------------
#--
#--    check_process.pl
#--
#--
#-- Description
#-- ------------
#--
#--    Plugin for Nagios to check for running processes
#--
#--
#--    testet Operating Systems:  Linux
#--
#----------------------------------------------------------------------

#-- History:
#-- --------
#--
#--    24.06.2002 - Initial Version
#--
#----------------------------------------------------------------------

use Getopt::Std;

$CRITICAL_STATE=2;
$WARNING_STATE=1;
$OK_STATE=0;

sub trim
{
    $_ = shift;
    chomp $_; # Remove Linefeeds
    s/#.*//; # Remove Comments
    s/^\s+//; # Remove Spaces from Beginning
    s/\s+$//; # Remove Space from End
    return $_;
}

# Find command in one of /sbin /bin /usr/sbin /usr/bin!
sub findCommand
{
    my $name = shift;
    my $command = "";
    if ( -e "/sbin/" . $name)
    {
        $command = "/sbin/" . $name;
    }
    elsif ( -e "/bin/" . $name)
    {
        $command = "/bin/" . $name;
    }
    elsif ( -e "/usr/sbin/" . $name)
    {
        $command = "/usr/sbin/" . $name;
    }
    elsif ( -e "/usr/bin/" . $name)
    {
        $command = "/usr/bin/" . $name;
    }
    return $command;
}

# Operating System dependand stuff
$OS = `uname -s`;
chomp($OS);
if (lc($OS) eq "hp-ux")
{
}
elsif (lc($OS) eq "linux")
{
}

$ps = findCommand("ps");
if ($ps eq "")
{
    print "Could not find PS Command";
    exit $CRITICAL_STATE;
}

$ps = $ps . " -ef";

getopts("c:r:");
if(!defined($opt_c))
{
    print "\nThis Plugin checks if the specified process is running.";
    print " Optional restarting of the process is possible by providing";
    print " a restart command.\n";
    print "OK State is returned if the process is running.\n";
    print "WARNING State is returned if the process was sucessfully restartet.\n";
    print "CRITICAL State is returned if the process is not running and no restart command is given, or if the restart command failed.\n";
    print "\nUsage: check_process -c <COMMAND> [-r <RESTART_COMMAND>]\n";
    print "COMMAND = regular expression for finding the command in output of ps.\n";
    print "RESTART_COMMAND = command that can be used to restart the process\n";
    exit $CRITICAL_STATE;
}

sub checkProcess
{
    my($regex,$restart) = @_;
    @result = `$ps`;
    my $state = $CRITICAL_STATE;
    foreach $line (@result)
    {
        if($line =~ /$regex/)
        {
            if(! ($line =~ /check_process/)) #Do not show this process
            {
                $state = $OK_STATE;
                $psline = $line;
                last;
            }
        }
    }
    if($state == $CRITICAL_STATE && defined($restart))
    {
        system("$opt_r >> /dev/null"); #send output to dev/null to get our own message visible
        $ret = checkProcess($opt_c);
        if($ret != 0)
        {
            $state = $CRITICAL_STATE;
        }
        else
        {
            $state = $WARNING_STATE;
        }
    }
    return $state;
}
$state = checkProcess($opt_c,$opt_r);
if($state == $WARNING_STATE)
{
    $output = "'$opt_c' has been restarted!\n";
}
elsif($state == $OK_STATE)
{
    $output = "Process '$opt_c' is running: $psline\n";
}
else
{
    $output = "Process '$opt_c' is not running!\n";
}
print $output;
exit $state;
