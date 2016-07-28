#!/bin/bash
/usr/bin/sudo /usr/lib64/nagios/plugins/check_execgrep.pl --contains NO --warning 120 --critical Reboot --command /opt/dell/srvadmin/bin/omreport --parameter 'system recovery'
