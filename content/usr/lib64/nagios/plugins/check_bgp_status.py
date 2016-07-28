#!/usr/bin/env python

# Icinga check to get the BGP status from the OPS 2.0 database.
#
# TODO:

import os
import sys
from time import strftime
import MySQLdb
import argparse

prog = os.path.basename(__file__)

parser = argparse.ArgumentParser(description='Icinga check for BGP status in the OPS 2.0 database.')
parser.add_argument('-H', '--host', default='', help='host to check in the ops.bgppeer table')
parser.add_argument('-P', '--peer', default='', help='BGP peer IP')
args = parser.parse_args()

host = args.host.lower()
peer = args.peer

if host == '' or peer == '':
    parser.print_help()
    sys.exit()

try:
    conn = MySQLdb.connect(host='opsdb.ena.net',user='opsquery',passwd='ops2015',db='ops')
except:
    print 'WARNING - Error connecting to the OPS 2.0 database at opsdb.ena.net.'
    sys.exit(1)

sql = 'SELECT localasn,remoteasn,peeripstr,localipstr,status,state,' \
      'unicastacceptedprefixes,vpnacceptedprefixes,a.orgid,bp.description,d.class ' \
      'FROM bgppeer bp ' \
      'LEFT JOIN device d ON (d.id = bp.deviceid) ' \
      'LEFT JOIN asn a ON (a.asn = bp.remoteasn) ' \
      'WHERE d.hostname = \'' + host + '\' and bp.peeripstr = \'' + peer + '\''
cur = conn.cursor()
cur.execute(sql)
row = cur.fetchone()

if row:
    output = 'OK'
    localasn = int(row[0])
    remoteasn = int(row[1])
    peeripstr = str(row[2])
    localipstr = str(row[3])
    status = int(row[4])
    state = int(row[5])
    unicastacceptedprefixes = int(row[6])
    vpnacceptedprefixes = int(row[7])
    asnorgid = str(row[8])
    parts = asnorgid.split('-')
    if len(parts) > 2:
        asnorgid = parts[0] + '-' + parts[1]
    desc = str(row[9])
    dclass = int(row[10])
    acceptedprefixes = unicastacceptedprefixes + vpnacceptedprefixes
    if state == 1:
        output = 'WARNING'
    if (status == 2 and state <> 6) or (acceptedprefixes == 0 and (remoteasn == 65534 or remoteasn == 65117)):
        output = 'CRITICAL'
    print output + ' - ' + asnorgid + ' (' + str(remoteasn) + ') to ' + desc + ' status=' + str(status) + \
        ', state=' + str(state) + ', ' + str(acceptedprefixes) + \
        ' accepted prefixes|\'accepted prefixes\'=' + str(acceptedprefixes)
    if output == 'WARNING':
        sys.exit(1)
    if output == 'CRITICAL':
        sys.exit(2)
else:
    print 'UNKNOWN - query returned no results for host \'' + host + '\' and peer \'' + peer + '\''
    sys.exit(3)
