#!/usr/bin/perl -T
#############################################################################
#                                                                           #
# This script was initially developed by Anstat Pty Ltd and Lonely Planet   #
# for internal use and has kindly been made available to the Open Source    #
# community for redistribution and further development under the terms of   #
# the GNU General Public License v3: http://www.gnu.org/licenses/gpl.html   #
#                                                                           #
#############################################################################
#                                                                           #
# This script is supplied 'as-is', in the hope that it will be useful, but  #
# neither Anstat Pty Ltd, Lonely Planet nor the authors make any warranties #
# or guaranteesas to its correct operation, including its intended function.#
#                                                                           #
# Or in other words:                                                        #
#       Test it yourself, and make sure it works for YOU.                   #
#                                                                           #
#############################################################################
# Author: George Hansper                     e-mail:  george@hansper.id.au  #
#############################################################################

use strict;
use Getopt::Std;

my $command;
my $file;
my $handle;
my $section;
my $value;
my $tag;
my $flag;
my $dmiinfo;
my $hash_ref;

my @message;
my $message = "";
my $sep=":";

# Throw-away variables
my ($kernel_installed);
my ($vendor,$product,$serial);
my ($n_cpu,$cpu_family,$cpu_speed,$cpu_fsb,$cpu_l2cache);
my ($pkg,@pkgs,$ip,$port,$process,%portlist);
my ($snmp_community,$ilo_ip);

my $rcsid = '$Id: check_hwinfo.pl,v 1.3 2011/04/18 23:01:42 george Exp george $';
my $rcslog = '
  $Log: check_hwinfo.pl,v $
  Revision 1.3  2011/04/18 23:01:42  george
  Added support for SUSE-release and other /etc/*-release files for OS field.

  Revision 1.2  2011/04/18 11:16:00  george
  Added: kernel version, key software packages, DRAC/ILO address

';

####################################################
# Command-line Option Processing
my %optarg;
my $getopt_result;

# Taint checks may fail due to the following...
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

$getopt_result = getopts('Vhf:t:', \%optarg) ;

if ( $getopt_result <= 0 || $optarg{'h'} == 1 ) {
	print STDERR "Extract and print hardware information for this system\n\n";
	print STDERR "Usage: $0 \[-h|-V] | \[-t sep]\n" ;
	print STDERR "\t-h\t... print this help message and exit\n" ;
	print STDERR "\t-V\t... print version and log, and exit\n" ;
	print STDERR "\t-t sep\t...use \"sep\" as column seperator\n" ;
	print STDERR "\t-t csv\t...create quoted comma-separated value output\n" ;
	print STDERR "\nExample:\n";
	print STDERR "\t$0 -t ','\n";
	exit 1;
}

if ( $optarg{'t'} ne undef ) {
	$sep = $optarg{'t'};
	if ( $sep eq "csv" ) {
		$sep = '","';
	}
}

$command = "dmidecode|cat|";

$ENV{PATH}="/sbin:/usr/sbin:/bin:/usr/bin";
if ( ! open(DMIDECODE,$command) ) {
	print "Could not execute $command\n";
	exit 2;
}

while ( <DMIDECODE> ) {
	if ( /^Handle.*(0x[0-9A-F]*)/i ) {
		$section = undef;
		$handle = $1;
	}
	if ( $section eq undef ) {
		if ( /DMI type/i ) {
			$section = <DMIDECODE>;
			chomp $section;
			$section =~ s/^\s*//;
			$section =~ s/\s*\sBlock$//i;
			$section =~ s/\s*\sName$//i;
			$section =~ s/\s*\sInformation$//i;
		}
		next;
	}
	# Create Hash of Hashes, where each value is available as
	#   $dmiinfo->$section->$tag
	#
	if ( /:/ ) {
		/(\S[^:]*):\s*(.*\S)/mi;
		$tag=$1;
		$value=$2;
		$tag =~ s/\s*\sName$//i;
		if( $value ne undef ) {
			$dmiinfo->{$section}{$handle}{$tag}=$value;
		}
	} elsif ( /\s(is|are)\s/mi ) {
		/(\S.*)\s(is|are)\s(.*)/i;
		$flag = $1;
		$value =$3;
		$dmiinfo->{$section}{$handle}{$tag.$flag}=$value;
	} elsif ( /\(/ ) {
		/(\S.*)\s\((.*)\)/i;
		$flag = $1;
		$value =$2;
		$dmiinfo->{$section}{$handle}{$tag.$flag}=$value;
	} elsif ( $dmiinfo->{$section}{$handle}{$tag} eq undef ) {
		/(\S.*)/;
		$flag = $1;
		$dmiinfo->{$section}{$handle}{$tag.$flag}="";
	} else {
		#print STDERR "Ignored line: $_";
	}
	#print "$section -- $tag == $value\n";
	#print "$section .. $tag .. $dmiinfo{$section}{$tag}\n";
	#print "$section ++ $tag ++ $flag ++ $dmiinfo{$section}{$tag.$flag}\n";
	$value = undef;
	$flag = undef;
}

close(DMIDECODE);

#########################################################################
# OS Release
#########################################################################
$message[4] = "No /etc/redhat-release".$sep;
foreach $file ( qw{ /etc/redhat-release /etc/SuSE-release }, glob("/etc/*-release") ) {
	if ( ! -f $file ) {
		next;
	} elsif ( ! open(OS_RELEASE,"< $file") ) {
		print STDERR "Could not open $file\n";
		$message[4] = "Could not open $file".$sep;
	} else {
		$message = <OS_RELEASE>;
		chomp $message;
		if ( $message eq "" ) {
			$message = "Linux";
		}
		close(OS_RELEASE);

		$message[4] = $message.$sep;
		last;
	}
}

#------------------------------------------------------------------------
# Architecture
#------------------------------------------------------------------------
$message = `arch`;
chomp $message;
$message[4] .= $message.$sep;
#------------------------------------------------------------------------
# Running Kernel
#------------------------------------------------------------------------
$message = `uname -r`;
chomp $message;
$file = "rpm -q --last kernel kernel-smp|";
if ( ! open(KERNEL_INSTALLED,$file) ) {
	print STDERR "Could not run $file\n";
	$kernel_installed = "";
} else {
	$kernel_installed = <KERNEL_INSTALLED>;
	chomp $kernel_installed;
	close(KERNEL_INSTALLED);
	if ( $kernel_installed =~ s/^kernel-(smp-)?// ) {
		$kernel_installed =~ s/ .*//;
	} else {
		# Getting 'package  kernel not installed' or other failure
		$kernel_installed = "";
	}
}
if ( $message ne $kernel_installed && $message ne $kernel_installed."smp" && $kernel_installed ne "" ) {
	$message = "$kernel_installed ($message)";
}
$message[4] .= $message.$sep;

#########################################################################

if ( $optarg{'t'} ne undef ) {
	$message = (join $sep, @message );
	if ( $optarg{'t'} eq "csv" ) {
		$message = '"' . $message . '"' ;
	}
} else {
	$message = "[" . (join "][", @message ). "]";
}
$message =~ s/[<>]/ /g;
print $message . "\n";
exit 0;

