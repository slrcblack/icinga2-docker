#!/usr/bin/perl -w

 use Net::LDAP;
 use strict;
 use Getopt::Long;

# Nagios codes
 my %ERRORS=('OK'=>0, 'WARNING'=>1, 'CRITICAL'=>2, 'UNKNOWN'=>3, 'DEPENDENT'=>4);

 my $ldapserver;
 my $user;
 my $passwd;

 GetOptions(
         'host=s' => \$ldapserver,
         'user=s' => \$user,
         'password=s' => \$passwd,
         'help' => sub { &usage(); },
 );


&nagios_return("UNKNOWN", "[1] --host not specified") if (!$ldapserver);
&nagios_return("UNKNOWN", "[1] --user not specified") if (!$user);
#
 #BIND INFORMATION, and SEARCH BASE
 my $base = "cn=config";

 #Attributes
 my $server="nsDS5ReplicaHost";
 my $status="nsds5replicaLastUpdateStatus";
 my $laststart="nsds5replicaLastUpdateStart";
 my $lastend="nsds5replicaLastUpdateEnd";


 #connect to ldap server
 my $ldap=ConnectLdap();

 my $result=LDAPSearch($ldap,"objectClass=nsDS5ReplicationAgreement","",$base);

 my @entries = $result->entries;
 my $entr;

 my $maxstatcode = 0;
 
 foreach $entr ( @entries ) {
        my $servername=$entr->get_value($server);
        my $serverstatus=$entr->get_value($status);

        my $serverlaststart=$entr->get_value($laststart);
        my $serverlastend=$entr->get_value($lastend);
        my $statuscode = $entr->get_value($status);

        $serverlaststart =~ s/(....)(..)(..)(..)(..)(..)./$1-$2-$3\ $4:$5:$6/;
        $serverlastend =~ s/(....)(..)(..)(..)(..)(..)./$1-$2-$3\ $4:$5:$6/;
        $statuscode =~ s/(^[-0123456789]+) (.*$)/$1/;
        print "Replication to $servername last operation $serverlaststart ";
        print "Status: $serverstatus.\n";
        if ($statuscode)
        {
            &nagios_return("ERROR", "Replication error: " . $serverstatus);
        }

 }
 &nagios_return("OK", "All replicats are OK");

 exit;

 sub ConnectLdap {

   my $ldap = Net::LDAP->new ( $ldapserver ) or die "$@";

   my $mesg = $ldap->bind ( "$user", password => "$passwd" , version => 3 );
   # $mesg->code && warn "error: ", $mesg->error;
   if ($mesg->code)
   {
     &nagios_return("CRITICAL", "Failed to connect to LDAP: " . $mesg->error . " with user $user.");
   }
   return $ldap;
 }

 sub LDAPSearch
  {
    my ($ldap,$searchString,$attrs,$base) = @_;

    my $result = $ldap->search ( base    => "$base",
                                scope   => "sub",
                                filter  => "$searchString",
                                attrs   =>  $attrs
                              );
 }

sub nagios_return($$) {
        my ($ret, $message) = @_;
        my ($retval, $retstr);
        if (defined($ERRORS{$ret})) {
                $retval = $ERRORS{$ret};
                $retstr = $ret;
        } else {
                $retstr = 'UNKNOWN';
                $retval = $ERRORS{$retstr};
                $message = "WTF is return code '$ret'??? ($message)";
        }
        $message = "$retstr - $message\n";
        print $message;
        exit $retval;
}

sub usage() {
        print("Emmanuel BUU <emmanuel.buu\@ives.fr> (c) IVÃ¨S 2008
  http://www.ives.fr/

  --host=<host>   Hostname or IP address to connect to.

  --user=<user>
  --password=<password>

  --help          Guess what ;-)");
}
