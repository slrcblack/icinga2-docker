#!/usr/bin/python
"""
Copyright (C) 2014 - David Mabry <dmabry@ena.com>

check_php-fpm is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

check_php-fpm is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>

"""

"""
Example php-fpm json payload

http://lapp12-mar.marion.in.ena.net:8080/fpm-status.php?json

{"pool":"www",
"process manager":"dynamic",
"start time":1393875426,
"start since":284796,
"accepted conn":55754,
"listen queue":0,
"max listen queue":1,
"listen queue len":128,
"idle processes":63,
"active processes":1,
"total processes":64,
"max active processes":66,
"max children reached":0,
"slow requests":0}

"""

from optparse import OptionParser
import requests
import json
import sys
import subprocess
import re

mon_codes = {
    'OK': 0,
    'WARNING': 1,
    'CRITICAL': 2,
    'UNKNOWN': 3,
    'DEPENDENT': 4,
}

def option_none(option, opt, value, parser):
    """ checks a parameter for taking value"""
    if parser.rargs and not parser.rargs[0].startswith('-'):
        print "Option arg error"
        print opt, " option should be empty"
        sys.exit(2)
    setattr(parser.values, option.dest, True)

def check_levels(message, status_value):
    """status level critical, warning, ok"""
    #status = status_value
    status = ''

    if options.critical > options.warning:
        if status_value >= options.critical:
            print "CRITICAL - " + message, status
            return sys.exit(mon_codes['CRITICAL'])
        elif status_value >= options.warning:
            print "WARNING - " + message, status
            return sys.exit(mon_codes['WARNING'])
        else:
            print "OK - " + message, status
            return sys.exit(mon_codes['OK'])
    else:
        if status_value >= options.warning:
            print "WARNING - " + message, status
            return sys.exit(mon_codes['WARNING'])
        elif status_value >= options.critical:
            print "CRITICAL - " + message, status
            return sys.exit(mon_codes['CRITICAL'])
        else:
            print "OK - " + message, status
            return sys.exit(mon_codes['OK'])

def check_processes(result):
    """check proccess max, current and idle"""
    if result is None:
        #Oops... that shouldn't happen
        print "Bummer - That shouldn't happen"
        sys.exit(2)
    else:
        idle_processes = result['idle processes']
        active_processes = result['active processes']
        total_processes = result['total processes']
        max_processes = result['max active processes']
        status_value = total_processes
        #erfdata = '|idle=' + str(idle_processes) + ';' + str(options.warning) + ';' + str(options.critical) + ';0;'
        #perfdata = perfdata + ' idle=' + str(idle_processes) + ';' + str(options.warning) + ';' + str(options.critical) + ';0;'
        message = ''.join(['idle: ', str(idle_processes), ' active: ', str(active_processes), ' total: ', str(total_processes), ' max: ', str(max_processes)])
        message = message + ''.join(['|idle=', str(idle_processes), ';', str(options.warning), ';', str(options.critical), ';0;'])
        message = message + ''.join([' active=', str(active_processes), ';', str(options.warning), ';', str(options.critical), ';0;'])
        message = message + ''.join([' total=', str(total_processes), ';', str(options.warning), ';', str(options.critical), ';0;'])
        message = message + ''.join([' max=', str(max_processes), ';', str(options.warning), ';', str(options.critical), ';0;'])
    check_levels(message, status_value)

def http_warnings(return_code):
    """ returns http warnings codes"""
    if r.status_code == requests.codes.created:
        print "No HTTP response body returns - 201 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.accepted:
        print "Request proccessing is not complete - 202 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.no_content:
        print "No content - 204 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.bad_request:
        print "Bad request - 400 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.unauthorized:
        print "Unauthorized - 401 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.forbidden:
        print "Forbidden - 403 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.not_found:
        print "Not found - 404 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.not_acceptable:
        print "Not acceptable - error 406 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.conflict:
        print "Conflict error- 409 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.internal_server_error:
        print "Internal server error - 500 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.not_implemented:
        print "Not Implemented - 501 error"
        return sys.exit(2)
    elif r.status_code == requests.codes.service_unavailable:
        print "Service error - 503 error"
        return sys.exit(2)

def which_argument(result):
    """calls related option for the choosen option"""
    if options.processes:
        check_processes(result)
    if options.connections:
        check_connections(result)

# option parse
parser = OptionParser()
parser.disable_interspersed_args()
arg = False

# option define
parser.add_option('-H', '--hostname', dest='hostname', help='name or IP address of PHP-FPM Server')
parser.add_option('-u', dest='username', help='User for PHP-FPM Status Page')
parser.add_option('-p', dest='password', help='Password for PHP-FPM Status Page')
parser.add_option('-P', '--port', dest='port', help='Port used for PHP-FPM Status Page')
parser.add_option('-W', type='int', dest='warning', help='Warning treshold')
parser.add_option('-C', type='int', dest='critical', help='Critical treshold')
parser.add_option('--processes', action='callback',
    callback=option_none, dest='processes',
    help='check running processes')
options, args = parser.parse_args()

try:
    url = ''.join(['http://', options.hostname, ':', options.port, '/fpm-status.php?json'])
#    r = requests.get(url, auth=(options.username, options.password))
    r = requests.get(url)
    http_warnings(r.status_code)
    result = r.json()
    which_argument(result)

except Exception as e:
    print "Invalid option combination"
    print "Try '--help' for more information "
    print e
    sys.exit(2)
