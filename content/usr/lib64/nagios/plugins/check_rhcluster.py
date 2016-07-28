#!/usr/bin/env python

"""
#===================================================================================#

FILE		: check_rhcluster.py

USAGE		: ./check_rhcluster.py [SERVICE NAME TO CHECK FOR - AS DISPLAYED BY CLUSTAT]

DESCRIPTION	: Nagios plugin to check Red Hat cluster services.

OPTION(S)	: -v / --version & -h / --help
REQUIREMENTS	: RedHat cluster. Tested with clustat 1.9.53
BUGS		: Search for XXX in the script.
NOTES 		: Tab stop = 8. My First Python Script (tm). Some bits gathered from the interwebs.
AUTHOR(s)	: Martinus Nel (martinus.nel@linuxit.com)
COMPANY		: LinuxIT
VERSION		: 1.0
CREATED		: 15-07-08
WISH LIST	: Get list of cluster services. This might be slightly pointless as the admin should know how to use clustat :_)


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

#===============#
# V2 - xx-xx-08 #
#===============#
Features
--------

Bugs
----


"""

import os, re, sys, getopt, string


#====================#
# Nagios exit status #
#====================#
STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3
STATE_DEPENDENT = 4

#=================##
# Global variables #
#=================##
VERSION = 1

#===========#
# Functions #
#===========#
def usage():
	print 'check_rhcluster.py version %s' % (VERSION)
	print 'This is a Nagios check to see if specific Red Hat clusters services are running.'
	print '''
Copyright (C) 2008  LinuxIT Europe LTD, www.linuxit.com

Usage : check_rhcluster.py [SERVICE]
--If unsure, use 'clustat' to get a list of services--

Options: -h	-- displays this help message
	 -v	-- displays version
'''
	sys.exit(STATE_OK)

def grep(string,list):
	expr = re.compile(string)
	return filter(expr.search,list)


#===========================#
# Check options / arguments #
#===========================#
try:
	options, argument = getopt.getopt(sys.argv[1:],'hv', ["help", "version"])
except getopt.error:
	usage()

for a in options[:]:
	if a[0] == '-h' or a[0] == '--help':
		usage()
for a in options[:]:
	if a[0] == '-v' or a[0] == '--version':
		print 'check_rhcluster.py version %s' % (VERSION)
		sys.exit(STATE_OK)

if len(argument) != 1:
	print "Incorrect amount of arguments."
	print "See 'check_rhcluster.py -h' for more details"
	sys.exit(STATE_CRITICAL)


#======#
# Main #
#======#
pipe = os.popen('/usr/sbin/clustat')
output = pipe.readlines()
exit_status = pipe.close()


"""
As I don't know any better, the following 4 lines takes :
['  SERVICE                  NODE-NAME                       STATUS         \n']
and makes it:
['SERVICE', 'NODE-NAME', 'STATUS']
"""
SERVICE = grep("".join(argument), output)
SERVICE = str(SERVICE)
SERVICE = SERVICE.split()
SERVICE = SERVICE[1:-1]

try:
	invalid = SERVICE[2]
except IndexError:
	print "No such service found."
	print "Use 'clustat' to see a list of services."
	sys.exit(STATE_CRITICAL)
if SERVICE[2] == 'started':
	print "%s is OK" % (SERVICE[0])
	sys.exit(STATE_OK)
else:
	print "%s is DOWN" % (SERVICE[0])
	sys.exit(STATE_CRITICAL)

