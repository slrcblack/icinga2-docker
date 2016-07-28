#!/usr/bin/env python

import os
import sys
import argparse
from pysnmp.entity.rfc3413.oneliner import cmdgen
#from pysnmp.proto import rfc1902

cpmCPUTotalPhysicalIndex = '1.3.6.1.4.1.9.9.109.1.1.1.1.2'
# Legacy values deprecated by the "Rev" below
cpmCPUTotal1min = '1.3.6.1.4.1.9.9.109.1.1.1.1.4'
cpmCPUTotal5min	= '1.3.6.1.4.1.9.9.109.1.1.1.1.5'
# 
cpmCPUTotal1minRev = '1.3.6.1.4.1.9.9.109.1.1.1.1.7'
cpmCPUTotal5minRev = '1.3.6.1.4.1.9.9.109.1.1.1.1.8'

parser = argparse.ArgumentParser(description='Nagios/Icinga plugin check for Cisco CPU utilization')
parser.add_argument('-H', '--host', dest='host', required=True, help='host or IP address')
parser.add_argument('-p', '--port', dest='port', type=int, default=161, help='port')
parser.add_argument('-w', '--warn', dest='warn', type=int, default=80, help='warning threshold')
parser.add_argument('-c', '--crit', dest='crit', type=int, default=90, help='critical threshold')
parser.add_argument('-P', '--period', dest='period', type=int, default=5, help='1 or 5 minute period')
parser.add_argument('-A', '--average', dest='average', action='store_true', help='Average CPU utilization')
parser.add_argument('-C', '--community', dest='community', required=True, help='SNMP read community')
parser.add_argument('-t', '--timeout', dest='timeout', type=int, default=5, help='SNMP timeout')
parser.add_argument('-r', '--retries', dest='retries', type=int, default=1, help='SNMP retries')
parser.add_argument('-D', '--deprecated', dest='deprecated', action='store_true', help='Use deprecated OIDs (ASAs)')
args = parser.parse_args()

period = 5
cpmCPUTotalmin = cpmCPUTotal5minRev
if args.deprecated:
    cpmCPUTotalmin = cpmCPUTotal5min
if args.period == 1:
    period = 1
    cpmCPUTotalmin = cpmCPUTotal1minRev
    if args.deprecated:
        cpmCPUTotalmin = cpmCPUTotal1min
average = args.average
    
cmdGen = cmdgen.CommandGenerator()
try:
    errorIndication, errorStatus, errorIndex, varBindTable = cmdGen.nextCmd(
        cmdgen.CommunityData(args.community),
        cmdgen.UdpTransportTarget((args.host, args.port),timeout=args.timeout,retries=args.retries),
        #CISCO-PROCESS-MIB::cpmCPUTotalPhysicalIndex
        cpmCPUTotalPhysicalIndex,
        #lookupNames=True, lookupValues=True
    )
except:
    print 'UNKNOWN: General network error'
    sys.exit(3)

if errorIndication:
    print 'CRITICAL: ' + str(errorIndication)
    sys.exit(2)

if errorStatus:
    print 'UNKNOWN: ' + errorStatus.prettyPrint() + ' at ' + str(varBindTable[-1][int(errorIndex)-1])
    sys.exit(3)

cpucount = 0
utilsum = 0
utilhigh = 0
for varBindTableRow in varBindTable:
    for name, val in varBindTableRow:
        name = name.prettyPrint()
        parts = name.split('.')
        index = parts[-1]
        errorIndication, errorStatus, errorIndex, varBinds = cmdGen.getCmd(
            cmdgen.CommunityData(args.community),
            cmdgen.UdpTransportTarget((args.host, args.port),timeout=args.timeout,retries=args.retries),
            #CISCO-PROCESS-MIB::cpmCPUTotal5min
            #'1.3.6.1.4.1.9.9.109.1.1.1.1.5.' + index,
            cpmCPUTotalmin + '.' + index,
            #lookupNames=True, lookupValues=True
        )
        
        if errorIndication:
            print 'CRITICAL: ' + str(errorIndication)
            sys.exit(2)
            
        if errorStatus:
            print('UNKNOWN: %s at %s' % (
                errorStatus.prettyPrint(),
                errorIndex and varBinds[int(errorIndex)-1] or '?'
                )
            )
            sys.exit(3)
            
        for name2, val2 in varBinds:
            val2 = val2.prettyPrint()
            try:
                utilsum += int(val2)
            except:
                print 'UNKNOWN: ' + val2
                sys.exit(3)
                
            cpucount += 1
            if int(val2) > utilhigh:
                utilhigh = int(val2)

if cpucount == 0:
    print 'CRITICAL: Error getting CPU count'
    sys.exit(2)

utilavg = utilsum // cpucount

output = str(period) + " minute CPU utilization = " + str(utilhigh) + '%'
perf = str(period) + 'MinUtil=' + str(utilhigh)
if cpucount > 1:
    output = str(cpucount) + " CPUs, highest " + output + ' (average = ' + str(utilavg) + '%)'
    perf = str(period) + 'MinAvgUtil=' + str(utilavg) + ' ' + str(period) + 'MinHighUtil=' + str(utilhigh)

if (average and utilavg >= args.crit) or (not average and utilhigh >= args.crit):
    print "CRITICAL: " + output + '|' + perf
    sys.exit(2)

if (average and utilavg >= args.warn) or (not average and utilhigh >= args.warn):
    print "WARNING: " + output + '|' + perf
    sys.exit(1)
    
print "OK: " + output + '|' + perf
