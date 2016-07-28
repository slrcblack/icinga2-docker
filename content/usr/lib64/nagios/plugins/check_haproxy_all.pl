#!/usr/bin/perl -w
#
#This polls multiple haproxy servers via their admin stats urls and sums up statistics.
#Scenario for usage is when you have multiple HaProxy boxes behind a load balancer and want to view the
# "sum total" of some key statistics like Bytes In/Out, Sessions etc across all HAProxy servers.
#Usage: Assuming you want to sum up stats across ha proxies lb1,2 and 3 which are have stats available via http://lbname:8080/statspath.
# /etc/nagios3/scripts/check_haproxy_all.pl -u lb1.domain.com,lb2.domain.com,lb3.domain.com -U admin  -a '/statspath' -P 'PASSWORD'
# See http://www.onepwr.org/haproxy-consolidated-stats for detailed info.

use strict; # always! :)
use warnings;


use Locale::gettext;
use File::Basename;			# get basename()

use POSIX qw(setlocale);
use Time::HiRes qw(time);			# get microtime
use POSIX qw(mktime);

use Nagios::Plugin ;

use LWP::UserAgent;			# http client
use HTTP::Request;			# used by LWP::UserAgent
use HTTP::Status;			# to get http err msg


use Data::Dumper;


my $PROGNAME = basename($0);
'$Revision: 1.0 $' =~ /^.*(\d+\.\d+) \$$/;  # Use The Revision from RCS/CVS/SVN
my $VERSION = $1;

my $DEBUG = 0;
my $TIMEOUT = 5;

# i18n :
setlocale(LC_MESSAGES, '');
textdomain('nagios-plugins-perl');


my $np = Nagios::Plugin->new(
	version => $VERSION,
	blurb => _gt('Plugin to consolidate HAProxy stats'),
	usage => "Usage: %s [ -v|--verbose ]  [ -d ] -u lb1,lb2,lb3 -U admin  -a '/statspath' -P PASSWORD ",
	timeout => $TIMEOUT+1
);
$np->add_arg (
	spec => 'debug|d',
	help => _gt('Debug level'),
	default => 0,
);
$np->add_arg (
  spec => 'username|U=s',
  help => _gt('Username for HTTP Auth'),
  required => 0, 
);
$np->add_arg (
  spec => 'password|P=s',
  help => _gt('Password for HTTP Auth'),
  required => 0, 
);
$np->add_arg (
	spec => 'w=f',
	help => _gt('Warning request time threshold (in seconds)'),
	default => 2,
	label => 'FLOAT'
);
$np->add_arg (
	spec => 'c=f',
	help => _gt('Critical request time threshold (in seconds)'),
	default => 10,
	label => 'FLOAT'
);
$np->add_arg (
	spec => 'url|u=s',
	help => _gt('Comma separated IP/hostname list of HAProxy csv statistics page  - all of them expected to have same stats login.'),
	required => 1,
);

$np->add_arg(
	spec => 'port|p=s',
	help => _gt('TCP Port number of stats uri.'),
	default => 8080,
	required => 0,
);

$np->add_arg(
        spec => 'adminpath|a=s',
        help => _gt('URI to admin stats e.g. /stats'),
	default => '/stats',
        required => 0,
);
$np->getopts;

$DEBUG = $np->opts->get('debug');
my $verbose = $np->opts->get('verbose');
my $username = $np->opts->get('username');
my $password = $np->opts->get('password');
my $uri=$np->opts->get('adminpath');
#my $port=$np->opts->get->('port') ;
# Thresholds :
# time
my $warn_t = $np->opts->get('w');
my $crit_t = $np->opts->get('c');

my $allurls = $np->opts->get('url');
my @urllist=split /,/,$allurls;

# Create a LWP user agent object:
my @lbsdown=();
my @statsarray;

my %watch=('load_balanced_http'=>'FRONTEND','load_balanced_ssl'=>'FRONTEND','app_cwp'=>'lapp01-dav','app_cwp','lapp02-dav','app_yii'=>'lapp01-dav','app_yii'=>'lapp02-dav','app_dotnetservices'=>'wapp01-dav','app_dotnetservices'=>'wapp02-dav','app_policy'=>'wapp03-dav','app_policy'=>'wapp04-dav','app_iptool'=>'wapp03-dav','app_iptool'=>'wapp04-dav');
my %colsneeded=(scur=>undef,smax=>undef,stot=>undef,bin=>'B',bout=>'B');
my %results=();
my %summary=();
foreach my $url (@urllist)
{
my $ua = new LWP::UserAgent(
	'env_proxy' => 0,
	'timeout' => $TIMEOUT,
	);
$ua->agent($PROGNAME);

# Workaround for LWP bug :
$ua->parse_head(0);
my $lbname=$url;
$url="http://$url:80".$uri.';csv';

# Build and submit an http request :
my $request = HTTP::Request->new('GET', $url);
# Authenticate if username and password are supplied
if ( defined($username) && defined($password) ) {
  $request->authorization_basic($username, $password);
}
my $timer = time();
my $http_response = $ua->request( $request );
$timer = time()-$timer;



if ( $http_response->is_error()  || ! $http_response->is_success()) {
	push(@lbsdown,[ split /\./,$lbname ]->[0]);
	next;
} 


if ( $http_response->is_success() ) {

	# Get xml content ... 
	my $stats = $http_response->content;
	#if ($DEBUG) {
	#	print "------------------===http output===------------------\n$stats\n-----------------------------------------------------\n";
	#	print "t=".$timer."s\n";
	#};

	my @fields = ();
	my @rows = split(/\n/,$stats);
	if ( $rows[0] =~ /#\ \w+/ ) {
		$rows[0] =~ s/#\ //;
		@fields = split(/\,/,$rows[0]);
	} else {
		$np->nagios_exit(UNKNOWN, _gt("Can't find csv header !") );
	}
	
	my %stats = ();
	for ( my $y = 1; $y < $#rows; $y++ ) {
		my @values = split(/\,/,$rows[$y]);
		next unless exists $watch{$values[0]} && $values[1] eq $watch{$values[0]};
		#if ( !defined($stats{$values[0]}) ) {
		#	$stats{$values[0]} = {};
		#}
		my $k=$values[0].':'.$values[1];
		$results{$k}=() unless exists $results{$k};
		for ( my $x = 2,; $x <= $#values; $x++ ) {
			# $stats{pxname}{svname}{valuename}
			next unless exists $colsneeded { $fields[$x] };
			$stats{$k}{$fields[$x]} = $values[$x];
			$results{$k}{$fields[$x]}=exists $results{$k}{$fields[$x]}? $results{$k}{$fields[$x]}+$values[$x]: $values[$x];
		}
	}
	#push(@statsarray,\%stats);
	print "This host: $lbname\n".Dumper(\%stats) if $DEBUG;		
	foreach my $svc (keys %stats)
	{
	$results{'Summary'}=() unless exists $results{'Summary'};	
	foreach my $item (keys %{$stats{$svc}})
		{
		$results{'Summary'}{$item}=exists $results{'Summary'}{$item}? $results{'Summary'}{$item}+$stats{$svc}{$item}:$stats{$svc}{$item};
		}		

	}
}

}

print "ALL results\n".Dumper(\%results) if $DEBUG;
#Run through results hash and populate nagios perfdata
my %colsdesc=(scur=>'sess_cur','smax'=>'sess_max','stot'=>'sess_tot','bin'=>'BytesIn','bout'=>'BytesOut');

foreach my $service (sort keys %results)
{
my $short=[ split ':',$service]->[0];
foreach my $item (sort keys %{$results{$service}})
	{
	#print "$short:$colsdesc{$item} => $results{$service}{$item}\n";
	$np->add_perfdata(
		'label'=>"$short:$colsdesc{$item}",
		'value' => $results{$service}{$item},
		'uom'=> (exists $colsneeded{$item}? $colsneeded{$item}:undef)		
		);
	}
}
my ($down,$all)=(scalar @lbsdown, scalar @urllist);
my ($status,$message)=();
if ($down>0)
	{
	$status= ($down==$all)? CRITICAL:WARNING;
	my $str=join(',',@lbsdown);
	$message="Problem - ($down/$all) HaProxies unreachable ($str)";
	}
else	{
	($status,$message)=(OK,"All HAProxies OK ($all/$all)");
	}
$np->nagios_exit($status, $message );

# Gettext wrapper
sub _gt {
	return gettext($_[0]);
}
