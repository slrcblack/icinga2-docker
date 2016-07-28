#!/usr/bin/perl
#/usr/lib64/icinga2/sbin/icinga2 daemon -c /etc/icinga2/icinga2.conf -C
#
#

my $CMDLINE='/usr/lib64/icinga2/sbin/icinga2 daemon -c /etc/icinga2/icinga2.conf -C';
my @TheCmdOut={};

sub getval
{
   my $in=$_[0];
   my @fields=split(' ',$in);
   return $fields[2];
}

sub ReadCmdOut
{
   @TheCmdOut=`sudo /usr/lib64/icinga2/sbin/icinga2 daemon -c /etc/icinga2/icinga2.conf -C`; 
   if ( $? ne 0 ) { ExitOut('2','Icinga2 Critical - Configuration Will not reload ',''); }
   foreach my $line (@TheCmdOut)
   {
      chomp ($line);
      if ( $line =~ m/information\/ConfigItem:.*Zones./ ) { $zone=&getval($line);}
      if ( $line =~ m/information\/ConfigItem:.*Endpoints./ ) { $endpoints=&getval($line);}
      if ( $line =~ m/information\/ConfigItem:.*Hosts./ ) { $hosts=&getval($line);}
      if ( $line =~ m/information\/ConfigItem:.*Service./ ) { $service=&getval($line);;}
   }
   printf "Icinga2 OK|Zones=$zone Endpoints=$endpoints Hosts=$hosts Services=$service\n";
}


sub ExitOut 
{
  my $ExitCode = $_[0];
  my $Message  = $_[1];
  my $PerfData = $_[2];

  printf "$Message|$PerfData\n";
  exit($ExitCode);

}

#Main#

&ReadCmdOut;

#&ExitOut(1,"WARN","test=1,2,3");
