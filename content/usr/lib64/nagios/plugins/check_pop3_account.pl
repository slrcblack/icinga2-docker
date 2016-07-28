#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program : check_pop3_account.pl
# Version : 1.0
# Date    : Jan 8 2009
# Author  : Jason Ellison - infotek@gmail.com
# Summary : This plugin logs into a POP3 or POP3 over SSL (POP3s) account and
#           reports the number of messages found.  It can optionally generate
#           alerts based on the number of messages found.  Performance data 
#           is available.
#
# License : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE =================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This program is written and maintained by: 
#   Jason Ellison <infotek(at)gmail.com>
#
# It is a slight rewrite of a POP3 plugin written by Moshe Sharon.
#
# OVERVIEW
#
# This plugin logs into a POP3 or POP3 over SSL (POP3s) account and reports
# the number of messages found.  
# This plugin provides performance data in the form of the number of messages. 

# You may omit the warning and critical options if you are not concerned about
# the number of messages in the account. The protocol option may also be 
# ommited. If protocol is not defined it will default to POP3. 

# Usage: check_pop3_account.pl [-v] -H <host> -u <username> -p <password> \
#                              [-w <warning>] [-c <critical>] [-P <pop3|pop3s>]
# -h, --help
#        print this help message
# -v, --version
#        print version
# -V, --verbose
#        print extra debugging information
# -H, --host=HOST
#        hostname or IP address of host to check
# -u, --username=USERNAME
# -p, --password=PASSWORD
# -w, --warnng=INT
#        number of messages which if exceeded will cause a warning if ommited
#        just checks the account
# -c, --critical=INT
#        number of messages which if exceeded will cause a critical if ommited
#        just checks the account
# -P, --protocol=pop3|pop3s
#        protocol to use when checking messages (if omitted defaults to pop3)

# ============================= SETUP NOTES ====================================
#
# Copy this file to your Nagios installation folder in "libexec/". 
# Rename to "check_pop3_account.pl"

# Manually test it with a command like the following:
# ./check_pop3_account.pl -H pop.example.org -u username -p password

# NAGIOS SETUP

# define command{
#   command_name check_pop3_account
#   command_line $USER1$/check_pop3_account.pl -H $HOSTADDRESS$ -u $ARG1$ -p $ARG2$ -w $ARG3$  -c $ARG4$ -P $ARG5$
# }
#
# define service{
#   use generic-service
#   host_name MAILSERVER
#   service_description Check POP3 Account
#   check_command check_pop3_account!jellison!A$3cr3T!10!50!pop3
#   normal_check_interval 3
#   retry_check_interval 1
# }

use Mail::POP3Client;
use Getopt::Long;

my $TIMEOUT = 20;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $version='1.0';
my $opt_version = undef;
my $host = undef; #hostname or ip address of pop3 server
my $protocol = 'pop3'; #protocol pop3 or pop3 over ssl (pop3s)
my $username= undef; #pop3 user account
my $password = undef; #pop3 password
my $critical = undef; #if message count is equal or greater generate critical
my $warning = undef; #if message count is equal or greater generate warning

sub print_version { print "$0: version $version\n" };

sub verb { my $t=shift; print "VERBOSE: ",$t,"\n" if defined($verbose) ; }

sub print_usage {
        print "Usage: $0 [-v] -H <host> -u <username> -p <password> [-w <warning>] [-c <critical>] [-P <pop3|pop3s>]\n";
}
sub help {
	print "\nCheck POP3 Account ", $version, "\n";
	print " Jason Ellison - infotek(at)gmail.com\n\n";
	print_usage();
	print <<EOD;
-h, --help
	print this help message
-v, --version
	print version
-V, --verbose
	print extra debugging information
-H, --host=HOST
	hostname or IP address of host to check
-u, --username=USERNAME
-p, --password=PASSWORD
-w, --warnng=INT
	number of messages which if exceeded will cause a warning if ommited
	just checks the account
-c, --critical=INT
	number of messages which if exceeded will cause a critical if ommited
	just checks the account
-P, --protocol=pop3|pop3s
	protocol to use when checking messages (if omitted defaults to pop3)
EOD
}

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
	'V'	=> \$verbose,	'verbose'	=> \$verbose,
	'v'	=> \$opt_version,	'version'	=> \$opt_version,
	'h'	=> \$help,	'help'		=> \$help,
	'H:s'	=> \$host,	'host:s'	=> \$host,
	'P:s'	=> \$protocol,	'protocol:s'	=> \$protocol,
	'u:s'	=> \$username,	'username:s'	=> \$username,
	'p:s'	=> \$password,	'password:s'	=> \$password,
	'c:i'	=> \$critical,	'critical:i'	=> \$critical,
	'w:i'	=> \$warning,	'warning:i'	=> \$warning
    );

  if (defined($help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
  if (defined($opt_version) ) { print_version(); exit $ERRORS{"UNKNOWN"}; }
  if (! defined($host) ) # check host and filter
    { print "ERROR: No host defined!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
  if (! defined($username) ) # check username 
    { print "ERROR: No username defined!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
  if ( (!($protocol eq 'pop3')) && (!($protocol eq 'pop3s')) )
    { print "ERROR: Protocol must be pop3 or pop3s!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }

  verb "host = $host";
  verb "protocol = $protocol";
  verb "username = $username";
  verb "password = $password";
  verb "warning = $warning";
  verb "critical = $critical";
}

check_options();

if ($protocol eq "pop3s" ) {
  $proto = "POP3s";
  $pop = new Mail::POP3Client( USER => "$username",
  PASSWORD => "$password",
  HOST => "$host",
  TIMEOUT => 10,
  USESSL => true );
  $count = $pop->Count();
}else{
  $proto = "POP3";
  $pop = new Mail::POP3Client( USER => "$username",
  PASSWORD => "$password",
  TIMEOUT => 10,
  HOST => "$host");
  $count = $pop->Count();
}

verb "message count = $count";

if ($count eq -1) {
  $statusinfo = "Failed to log in as $username";
  $statuscode="CRITICAL";
}elsif (defined($critical) && $count >= $critical) {
  $statusinfo = "$count emails for $username";
  $statuscode="CRITICAL";
}elsif (defined($warning) && $count >= $warning) {
  $statusinfo = "$count emails for $username";
  $statuscode="WARNING";
}else{
  $statusinfo = "$count emails for $username";
  $statuscode="OK";
}

$pop->Close();

printf("POP3_ACCOUNT ");

printf("$statuscode - $statusinfo");

printf(" |messages=$count;$warning;$critical;;");

print "\n";

exit $ERRORS{$statuscode};
