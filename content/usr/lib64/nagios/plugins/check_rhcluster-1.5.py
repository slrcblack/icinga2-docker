#!/usr/bin/env python

"""
#===================================================================================#

FILE		: check_rhcluster.py

USAGE		: ./check_rhcluster.py [-s service] [-n node] [-q quorate]

DESCRIPTION	: Nagios plugin to check Red Hat cluster services.

OPTION(S)	: -v / --version & -h / --help
REQUIREMENTS	: RedHat cluster. Tested with clustat 1.1.7.5
BUGS		: Search for XXX in the script.
NOTES 		: If you run this script as the nagios user, you migt want to chmod +s /usr/sbin/clustat
AUTHOR(s)	: Martinus Nel (martinus.nel@linuxit.com)
COMPANY		: LinuxIT
VERSION		: 1.5
CREATED		: 15-07-08
WISH LIST	: Need to test for all possible status or nodes and services.


Copyright (C) 2008  LinuxIT Europe LTD, www.linuxit.com
  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#===================================================================================#

#============#
# CHANGE LOG #
#============#

#=================#
# V1.5 - 10-08-09 #
#=================#
Features
--------
Options for checking quorum, nodes or service.
Moved to optparse.
Removed the grep function, that cleaned things up a bit.

Bugs fixes
----------


"""

import os, sys, string
from optparse import OptionParser


#=================##
# Global variables #
#=================##
VERSION = 1.5
CLUSTAT = '/usr/bin/sudo /usr/sbin/clustat'
# Nagios exit status
STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3
STATE_DEPENDENT = 4


#===========#
# Functions #
#===========#
def test_node():
	pipe = os.popen(CLUSTAT)
	for line in pipe.readlines():
		line=line.strip()
		if (options.node in line) and ("Online" in line):
			print line
			sys.exit(STATE_OK)
		elif (options.node in line) and ("Offline" in line):
			print line
			sys.exit(STATE_CRITICAL)

def test_service():
	pipe = os.popen(CLUSTAT)
	for line in pipe.readlines():
		line=line.strip()
		if (options.service in line) and ("started" in line):
			print line
			sys.exit(STATE_OK)
		elif (options.service in line) and ("stopped" in line):
			print line
			sys.exit(STATE_CRITICAL)
		elif options.service in line:
			print line
			sys.exit(STATE_WARNING)

def test_quorate():
	pipe = os.popen(CLUSTAT)
	for line in pipe.readlines():
		line=line.strip()
		if "Member Status" and "Quorate" in line: 
			print line
			sys.exit(STATE_OK)
		else:
			print line
			sys.exit(STATE_CRITICAL)

def do_all_tests():
	ERROR = 0
	WARNING = 0
	pipe = os.popen(CLUSTAT)
	for line in pipe.readlines():
		line=line.strip()
		if ("Inquorate" in line) or ("stopped" in line) or ("Offline" in line):
			print line,
			ERROR = 1
		elif ("starting" in line) or ("stopping" in line):
			print line,
			WARNING = 1
	if ERROR:
		sys.exit(STATE_CRITICAL)
	elif WARNING:
		sys.exit(STATE_WARNING)
	

#===========================#
# Check options / arguments #
#===========================#
usage = """See options below.

This is a Nagios check to see if specific Red Hat clusters services are running.
Copyright (C) 2009  LinuxIT Europe LTD, www.linuxit.com
Version %s
"""% (VERSION)

parser = OptionParser(usage)
# Remeber that store and type of string is implicit. Dest can also be implied, but let's declare.
parser.add_option("-s", "--service", dest="service",
	help="The service name as reported by clustat.", metavar="SERVICE")
parser.add_option("-n", "--node", dest="node",
	help="The node name as reported by clustat.", metavar="NODE")
parser.add_option("-q", "--quorate", action="store_true", dest="quorate",
	help="Check if the cluster is quorate.")
(options, args) = parser.parse_args()


#======#
# Main #
#======#
def main():
	if options.service == None and options.node == None and options.quorate == None:
		do_all_tests()
	if options.quorate == True:
		test_quorate()
	if options.service != None:
		test_service()
	if options.node != None:
		test_node()


if __name__ == "__main__":
    main()
