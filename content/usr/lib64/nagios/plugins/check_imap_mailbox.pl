#!/usr/bin/perl -w

# ============================== SUMMARY =====================================
#
# Program : check_imap_mailbox.pl
# Version : 1.0
# Date    : Aug 27 2012
# Author  : Dave Jones - djones@ena.com
# Summary : This plugin logs into an IMAP mailbox
#           and reports the number of messages found.
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
# IDEA AND INITIAL IMPLEMENTATION BASED ON CHECK_IMAP_RECEIVE WAS CONTRIBUTED
# BY JOHAN ROMME from THE NETHERLANDS 14 Oct 2011
#
# ORIGINAL Copyright (C) 2005-2011 Jonathan Buhacoff <jonathan@buhacoff.net>

use strict;
use IO::Socket::SSL qw(inet4);
my $VERSION = '0.1';
my $COPYRIGHT = 'Copyright (C) 2005-2011 Jonathan Buhacoff <jonathan@buhacoff.net>';
my $LICENSE = 'http://www.gnu.org/licenses/gpl.txt';
my %status = ( 'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3 );


# look for required modules
exit $status{UNKNOWN} unless load_modules(qw/Getopt::Long Mail::IMAPClient/);

BEGIN {
	if( grep { /^--hires$/ } @ARGV ) {
		eval "use Time::HiRes qw(time);";
		warn "Time::HiRes not installed\n" if $@;
	}
}

# get options from command line
Getopt::Long::Configure("bundling");
my $verbose = 0;
my $help = "";
my $help_usage = "";
my $show_version = "";
my $imap_server = "";
my $default_imap_port = "143";
my $default_imap_ssl_port = "993";
my $imap_ssl_version = "SSLv3";
my $imap_port = "";
my $username = "";
my $password = "";
my $folder = "INBOX";
my $warn = 15;
my $critical = 30;
my $timeout = 60;
my $peek = "";
my $ssl = 1;
my $tls = 0;
my $ok;
$ok = Getopt::Long::GetOptions(
	"V|version"=>\$show_version,
	"v|verbose+"=>\$verbose,"h|help"=>\$help,"usage"=>\$help_usage,
	"w|warning=i"=>\$warn,"c|critical=i"=>\$critical,"t|timeout=i"=>\$timeout,
	# imap settings
	"H|hostname=s"=>\$imap_server,"p|port=i"=>\$imap_port,
	"U|username=s"=>\$username,"P|password=s"=>\$password, "f|folder=s"=>\$folder,
	"ssl!"=>\$ssl, "tls!"=>\$tls,
	# search settings
	"peek!"=>\$peek,
	);

if( $show_version ) {
	print "$VERSION\n";
	if( $verbose ) {
		print "Default warning threshold: $warn messages\n";
		print "Default critical threshold: $critical messages\n";
		print "Default timeout: $timeout seconds\n";
	}
	exit $status{UNKNOWN};
}

if( $help ) {
	exec "perldoc", $0 or print "Try `perldoc $0`\n";
	exit $status{UNKNOWN};
}

#my @required_module = ();
#push @required_module, 'IO::Socket::SSL' if $ssl || $tls;
#exit $status{UNKNOWN} unless load_modules(@required_module);

if( $help_usage
	||
	( $imap_server eq "" || $username eq "" || $password eq "" )
  ) {
	print "Usage: $0 -H host [-p port] -U username -P password [--ssl] [--tls] [--imap-retries <tries>]\n";
	exit $status{UNKNOWN};
}


# initialize
my $report = new PluginReport;

# connect to IMAP server
print "connecting to server $imap_server\n" if $verbose > 2;
my $imap;
eval {
	local $SIG{ALRM} = sub { die "exceeded timeout $timeout seconds\n" }; # NB: \n required, see `perldoc -f alarm`
	alarm $timeout;
	
	if( $ssl || $tls ) {
		$imap_port = $default_imap_ssl_port unless $imap_port;		
		my $socket = IO::Socket::SSL->new(PeerHost => $imap_server, PeerPort => $imap_port, SSL_verify_mode => SSL_VERIFY_NONE, SSL_version => $imap_ssl_version);
		die IO::Socket::SSL::errstr() unless $socket;
		$socket->autoflush(1);
		$imap = Mail::IMAPClient->new(Socket=>$socket, Debug => 0 );
		$imap->State(Mail::IMAPClient->Connected);
		$imap->_read_line() if "$Mail::IMAPClient::VERSION" le "2.2.9"; # necessary to remove the server's "ready" line from the input buffer for old versions of Mail::IMAPClient. Using string comparison for the version check because the numeric didn't work on Darwin and for Mail::IMAPClient the next version is 2.3.0 and then 3.00 so string comparison works
		$imap->User($username);
		$imap->Password($password);
		$imap->login() or die "$@";
	}
	else {
		$imap_port = $default_imap_port unless $imap_port;		
		$imap = Mail::IMAPClient->new(Debug => 0 );		
		$imap->Server("$imap_server:$imap_port");
		$imap->User($username);
		$imap->Password($password);
		$imap->connect() or die "$@";
	}

	$imap->Peek(1) if $peek;
	$imap->Ignoresizeerrors(1);

	alarm 0;
};
if( $@ ) {
	chomp $@;
	print "CRITICAL - Could not connect to $imap_server port $imap_port: $@\n";
	exit $status{CRITICAL};	
}
unless( $imap ) {
	print "CRITICAL - Could not connect to $imap_server port $imap_port: $@\n";
	exit $status{CRITICAL};
}

# get message count of the Inbox
my $message_count = $imap->message_count("$folder");

# disconnect from IMAP server
print "disconnecting from server\n" if $verbose > 2;
$imap->logout();

# print report and exit with known status

if($message_count >= $critical) {
	print "CRITICAL - $message_count message(s) in $username\'s $folder.|messages=$message_count;$warn;$critical;;;\n";
	exit $status{CRITICAL};
}
if($message_count >= $warn) {
	print "WARNING - $message_count message(s) in $username\'s $folder.|messages=$message_count;$warn;$critical;;;\n";
	exit $status{WARNING};
}
print "OK - $message_count message(s) in $username\'s $folder.|messages=$message_count;$warn;$critical;;;\n";
exit $status{OK};


# utility to load required modules. exits if unable to load one or more of the modules.
sub load_modules {
	my @missing_modules = ();
	foreach( @_ ) {
		eval "require $_";
		push @missing_modules, $_ if $@;	
	}
	if( @missing_modules ) {
		print "Missing perl modules: @missing_modules\n";
		return 0;
	}
	return 1;
}


# NAME
#	PluginReport
# SYNOPSIS
#	$report = new PluginReport;
#   $report->{label1} = "value1";
#   $report->{label2} = "value2";
#	print $report->text(qw/label1 label2/);
package PluginReport;

sub new {
	my ($proto,%p) = @_;
	my $class = ref($proto) || $proto;
	my $self  = bless {}, $class;
	$self->{$_} = $p{$_} foreach keys %p;
	return $self;
}

sub text {
	my ($self,@labels) = @_;
	my @report = map { "$self->{$_} $_" } grep { defined $self->{$_} } @labels;
	my $text = join(", ", @report);
	return $text;
}


package main;
1;

__END__


=pod

=head1 NAME

check_imap_mailbox.pl - connects to an IMAP account and checks the quota

=head1 SYNOPSIS

 check_imap_mailbox.pl -vV
 check_imap_mailbox.pl -?
 check_imap_mailbox.plp --help

=head1 OPTIONS

=over

=item --warning <message count>

Warn if message count is equal to or greater than <message count> but less than critical.
Also known as: -w <message count>

=item --critical <message count>

Return a critical status if messsage count is equal to or greater than <message count>.
See also: --capture-critical <messages>
Also known as: -c <message count>

=item --timeout <seconds>

Abort with critical status if it takes longer than <seconds> to connect to the IMAP server. Default is 60 seconds.
The difference between timeout and critical is that, with the default settings, if it takes 45 seconds to 
connect to the server then the connection will succeed but the plugin will return CRITICAL because it took longer
than 30 seconds.
Also known as: -t <seconds> 

=item --hostname <server>

Address or name of the IMAP server. Examples: mail.server.com, localhost, 192.168.1.100
Also known as: -H <server>

=item --port <number>

Service port on the IMAP server. Default is 143. If you use SSL, default is 993.
Also known as: -p <number>

=item --username <username>

=item --password <password>

Username and password to use when connecting to IMAP server. 
Also known as: -U <username> -P <password>

=item --folder <folder>

Use this option to specify the folder to search for messages. Default is INBOX. 
Also known as: -f <folder>

=item --ssl

=item --nossl

Enable SSL protocol. Requires IO::Socket::SSL. 

Using this option automatically changes the default port from 143 to 993. You can still
override this from the command line using the --port option.

Use the nossl option to turn off the ssl option.

=item --verbose

Display additional information. Useful for troubleshooting. Use together with --version to see the default
warning and critical timeout values.

If the selected mailbox was not found, you can use verbosity level 3 (-vvv) to display a list of all
available mailboxes on the server.

Also known as: -v

=item --version

Display plugin version and exit.
Also known as: -V

=item --help

Display this documentation and exit.
Also known as: -h

=item --usage

Display a short usage instruction and exit. 
