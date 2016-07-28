#!/usr/bin/env python2.7

import sys
import argparse
import consulate

statustext = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')
status = 0

parser = argparse.ArgumentParser(description='Check Consul health')
parser.add_argument('-H', '--host', default='localhost', help='Host or IP address of the Consul agent or server')
parser.add_argument('-P', '--port', default='8500', help='Port of the consul agent or server')
parser.add_argument('-w', '--warn', default=1, help='Warning threshold')
parser.add_argument('-c', '--crit', default=1, help='Critical threshold')
args = parser.parse_args()

def shorten(s):
    if len(s) > 18:
        s = s[:15] + '...'
    return s

c = consulate.Consul(host=args.host,port=args.port)

try:
	nodes = c.catalog.nodes()
except:
	print 'Error connecting to Consul at ' + args.host + ':' + args.port
	sys.exit(1)

output = str(len(nodes)) + ' nodes, '

servicecount = 0
services = c.catalog.services()
for service in services:
	for s in sorted(service):
		servicecount += 1
output += str(servicecount) + ' services, '

passing = c.health.state('passing')
output += str(len(passing)) + ' checks passing, '

unknlist = []
unknowns = c.health.state('unknown')
if unknowns:
	if len(unknowns) >= int(args.warn):
		status = 1
	output += str(len(unknowns)) + 'unknown = '
	for unknown in unknowns:
		if unknown['ServiceName'] and not unknown['ServiceName'] in unknlist:
			output += shorten(unknown['ServiceName']) + ', '
			unknlist.append(unknown['ServiceName'])

warnlist = []
warnings = c.health.state('warning')
if warnings:
	if len(warnings) >= int(args.warn):
		status = 1
	output += str(len(warnings)) + ' warning = '
	for warning in warnings:
		if warning['ServiceName'] and not warning['ServiceName'] in warnlist:
			output += shorten(warning['ServiceName']) + ', '
			warnlist.append(warning['ServiceName'])

critlist = []
criticals = c.health.state('critical')
if criticals:
	if len(criticals) >= int(args.warn):
		status = 1
	if len(criticals) >= int(args.crit):
		status = 2
	output += str(len(criticals)) + ' failing = '
	for critical in criticals:
		if critical['ServiceName'] and not critical['ServiceName'] in critlist:
			output += shorten(critical['ServiceName']) + ', '
			critlist.append(critical['ServiceName'])

print statustext[status] + ' - ' + output[:-2] + '|nodes=' + str(len(nodes)) + \
    ',services=' + str(servicecount) + ',passing=' + str(len(passing)) + \
    ',unknown=' + str(len(unknowns)) + ',warning=' + str(len(warnings)) + \
    ',failing=' + str(len(criticals))

sys.exit(status)
