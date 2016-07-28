#!/usr/bin/env python2.7

# Written by Dave Jones 8/15/2013

# This script connects to a custom URL that provides HiveManager status in JSON format
# then converts the output to a Nagios plugin check format with performance data.

#{
#    "2701": {
#        "ap.we-lib.2701.dyersburghs.tn": {
#            "Status": "Ok",
#            "Description": null,
#            "Component": null
#        },
#        "ap.rm214.2701.dyersburghs.tn": {
#            "Status": "Critical",
#            "Description": null,
#            "Component": null
#        }
#    }
#}

import os
import sys
import logging
from time import time, strftime, localtime
from datetime import timedelta
import requests
import re
import argparse
import operator
import collections

basename = os.path.basename(__file__)
scriptname = os.path.splitext(basename)[0]
# seconds since the epoch
now = int(time())
checkoffset = now - 5

URL = 'https://ba.ena.com'
URI = '/hmm/status?crit'
icingacmd = '/var/spool/icinga/cmd/icinga.cmd'
lastfile = '/tmp/' + scriptname + '.last'
logfile = '/var/log/icinga/' + scriptname + '.log'

logger = logging.getLogger()
handler = logging.FileHandler(logfile, mode='a')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s', '%Y-%m-%d %H:%M:%S')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)

parser = argparse.ArgumentParser(description='Process Icinga passive checks from ' + URL + URI + ' into ' + icingacmd)
parser.add_argument('-f', '--file', help='write ENA AIR OPS hosts config file')
parser.add_argument('-d', '--debug', action='store_true', default=False, help='enable debug output', )
args = parser.parse_args()

excludeFile = os.path.dirname(__file__) + '/' + scriptname + '.exclude'

status = 0
output = ''
CIDcrit = 0
totalAPok = 0
totalAPcrit = 0
totalAPwarn = 0
totalAPs = 0

# Icinga config options
hostalivecommand = 'always-true'
hosttemplate = 'ena-air-host'
hostcontactgroups = 'nobody'
servicetemplate = 'ena-air-service'
servicecommand = 'always-true'
servicedescription = 'ENA AIR '
servicecontactgroups = 'nobody'

if os.path.isfile(lastfile):
    with open(lastfile, 'r') as f:
         updatewindow = int(f.readline())
else:
    updatewindow = now - 172800 # go back 2 days

if args.debug:
    print 'Now = ' + str(now) + ', update window = ' + str(updatewindow) + ', difference = ' + str(now - updatewindow)

logger.info('START: now = ' + str(now) + ', update window = ' + str(updatewindow) + ', difference = ' + str(timedelta(seconds=(now - updatewindow))))

try:
    r = requests.get(URL + URI)
    if r.status_code != 200:
        logger.warn('END: UNKNOWN: Error getting response from HiveManager alarms URL.  ' + URL + URI + ' ' + str(resp.status) + ' ' + str(resp.reason))
        print 'UNKNOWN: Error getting response from HiveManager alarms URL.  ' + URL + URI + ' ' + str(resp.status) + ' ' + str(resp.reason)
        sys.exit(3) 
except:
    logger.warn('END: UNKNOWN: Error connecting to HiveManager alarms URL.  ' + URL + URI)
    print 'UNKNOWN: Error connecting to HiveManager alarms URL.  ' + URL + URI 
    sys.exit(3)

try:
    data = r.json()
except Exception as e:
    logger.warn('END: UNKNOWN: Error loading JSON output from HiveManager alarms URL.  ' + URL + URI + ' Error: ' + e)
    print 'UNKNOWN: Error loading JSON output from HiveManager alarms URL.  ' + URL + URI + ' Error: ' + e
    sys.exit(3)

try:
    if args.file:
        f = open(args.file, 'w')
except:
    logger.warn('Error opening ' + args.file + ' for writing.')
    print 'Error opening ' + args.file + ' for writing.'
    sys.exit(1)

try:
    if not args.file:
        cmd = open(icingacmd, 'a', 0)
except:
    logger.warn('CRITICAL - Error opening ' + icingacmd + ' for writing.')
    print 'CRITICAL - Error opening ' + icingacmd + ' for writing.'
    sys.exit(2)

try:
    with open(excludeFile, 'r') as excludeFile:
        CIDexclude = []
        for line in excludeFile:
            CIDexclude.append(line.rstrip())
except:
    logger.warn('CRITICAL - Error opening ' + excludeFile + ' for reading.')
    print 'CRITICAL - Error opening ' + excludeFile + ' for reading.'
    sys.exit(3)

updated = 0
notupdated = 0

for CID in collections.OrderedDict(sorted(data.items())):
    if CID in CIDexclude:
        continue
    if CID == 'errors':
        continue
    APnum = 0
    APok = 0
    APcrit = 0
    APwarn = 0
    for AP in data[CID]:
        APnum += 1
        if APnum == 1: # The first AP in the CID will be used to create the virtual host definition
            parts = AP.split('.')
            CIDname = re.sub(r'(hs|ms|es|-..|-.hs)\.', '.', '.'.join(parts[-3:]))
            if args.file:
                block = ('define host {\n\thost_name\t\t' + CIDname.lower() + \
                         '\n\talias\t\t\t' + CIDname + '\n\tdisplay_name\t\t' + \
                         CIDname + '\n\taddress\t\t\t127.0.0.1\n\tcheck_command\t\t' + \
                         hostalivecommand + '\n\tuse\t\t\t' + hosttemplate + \
                         '\n\tcontact_groups\t\t' + hostcontactgroups + '\n\tregister\t\t1\n}\n\n')
                f.write(block)
        if args.file:
            icon_image = 'wireless.png'
            if AP.startswith('sw.'):
                icon_image = 'switch.png'
            block = ('define service {\n\tuse\t\t\t' + servicetemplate + \
                     '\n\thost_name\t\t' + CIDname.lower() + \
                     '\n\tservice_description\t' + servicedescription + AP + \
                     '\n\tdisplay_name\t\t' + servicedescription + AP + \
                     '\n\ticon_image\t\t' + icon_image + \
                     '\n\tcheck_interval\t\t0\n\tcontact_groups\t\t' + servicecontactgroups + \
                     '\n\tcheck_command\t\t' + servicecommand + '\n}\n\n')
            f.write(block)

        APupdated = int(data[CID][AP]['Updated'])
        APstatus = data[CID][AP]['Status']
        APconnected = data[CID][AP]['Connected']
        APconnchangetime = data[CID][AP]['ConnChangedTime']
        parts = data[CID][AP]['HiveManager'].split('.')
        APhivemanager = parts[0] + '.' + parts[1]
        try:
            APcomp = data[CID][AP]['Component'].replace('\n',' ')
        except:
            APcomp = ''
        try:
            APdesc = data[CID][AP]['Description'].replace('\n',' ')
            if len(APdesc) > 35:
                APdesc = APdesc[:35] + ' ... '
        except:
            APdesc = APhivemanager + ': ' + APstatus
        if APdesc == '':
            APdesc = APhivemanager + ': ' + APstatus
        if APcomp <> '':
            APdesc = APdesc + ', ' + APcomp
        
        if APupdated > updatewindow:
            writecmd = True
            updated += 1
            if args.debug:
                print CIDname + ' updated at ' + str(APupdated) + ' > ' + str(updatewindow)
        else:
            writecmd = False
            notupdated += 1
            
        if APstatus == 'Ok':
            if APconnected:
                APdesc = APhivemanager + ': AP is Ok and connected.'
                state = 'OK'
                result = 0
                APok += 1
                totalAPok += 1
            else:
                if APconnchangetime == 0:
                    APdesc = APhivemanager + ': AP is prestaged and not connected.'
                    state = 'WARNING'
                    result = 1
                    APwarn += 1
                    totalAPwarn += 1
                else:
                    APdesc = APhivemanager + ': AP is not connected.'
                    state = 'CRITICAL'
                    result = 2
                    APcrit += 1
                    totalAPcrit += 1
        elif APstatus == 'Critical':
            if APcomp == 'CAPWAP':
                if APconnected:
                    # Filter out CAPWAP errors where the AP is showing connected to the HiveManager
                    APdesc = APhivemanager + ': AP is connected, ignoring CAPWAP error.'
                    state = 'OK'
                    result = 0
                    APok += 1
                    totalAPok += 1
                else:
                    APdesc = APhivemanager + ': CAPWAP error and AP is not connected.'
                    state = 'CRITICAL'
                    result = 2
                    APcrit += 1
                    totalAPcrit += 1
            else:
                state = 'CRITICAL'
                result = 2
                APcrit += 1
                totalAPcrit += 1
        else:
            state = 'WARNING'
            result = 1
            APwarn += 1
            totalAPwarn += 1
            
        passivecheck = ('[' + str(int(time())) + '] PROCESS_SERVICE_CHECK_RESULT;' + \
                        CIDname.lower() + ';' + servicedescription + AP + ';' + \
                        str(result) + ';' + state + ' - ' + APdesc)
        if writecmd and not args.file:
            if args.debug:
                print passivecheck
            try:
                logger.info(passivecheck + ' -> Updated=' + str(APupdated) + ' (' + \
                            strftime('%Y-%m-%d %H:%M:%S', localtime(APupdated)) + \
                            '), Status=' + APstatus + ', Connected=' + str(APconnected))
                cmd.write(passivecheck + '\n')
            except IOError:
                logger.warn('Error writing to ' + icingacmd)
                print 'Error writing to ' + icingacmd
        totalAPs += 1
        
    if APcrit > 0:
        CIDcrit += 1
        # Set the host to CRITICAL
        passivecheck = ('[' + str(int(time())) + '] PROCESS_HOST_CHECK_RESULT;' + \
                        CIDname.lower() + ';1;CRITICAL - One or more APs are offline')
        if writecmd and not args.file:
            if args.debug:
                print passivecheck
            try:
                logger.info(passivecheck)
                cmd.write(passivecheck + '\n')
            except IOError:
                logger.warn('Error writing to ' + icingacmd)
                print 'Error writing to ' + icingacmd
    else:
        # Set the host to OK
        passivecheck = ('[' + str(int(time())) + '] PROCESS_HOST_CHECK_RESULT;' + \
                        CIDname.lower() + ';0;OK - All APs are online')
        if writecmd and not args.file:
            if args.debug:
                print passivecheck
            try:
                logger.info(passivecheck)
                cmd.write(passivecheck + '\n')
            except IOError:
                print 'Error writing to ' + icingacmd
    output = output + ', ' + CID + '=' + str(len(data[CID])) + '/' + str(APok) + '/' + str(APcrit)

if len(output) > 350:
    output = output[:350] + ' ... '

if args.file:
    f.close
else:
    cmd.close
    print str(totalAPs) + ' total APs, (' + str(updated) + ' updated) ' + \
          str(totalAPok) + ' OK, ' + str(totalAPwarn) + ' WARNING, ' + \
          str(totalAPcrit) + ' CRITICAL, ' + 'CIDs=' + str(len(data)) + '|totalAPs=' + \
          str(totalAPs) + ', OKAPs=' + str(totalAPok) + ', WarnAPs=' + str(totalAPwarn) + \
          ', CritAPs=' + str(totalAPcrit)

with open(lastfile, 'w') as f:
    f.write(str(checkoffset))
    
logger.info('END: wrote ' + str(checkoffset) + ' to ' + lastfile)
