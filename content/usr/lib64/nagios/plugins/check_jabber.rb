#!/usr/bin/env ruby1.8
#
# Copyright 2009 Stephan Maka <stephan@spaceboyz.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
require 'rubygems'
require 'getopt/long'

opt = Getopt::Long.getopts(
  ["--help",      "-h", Getopt::BOOLEAN],
  ["--jid",       "-j", Getopt::REQUIRED],
  ["--password",  "-p", Getopt::OPTIONAL],
  ["--hostname",  "-H", Getopt::OPTIONAL],
  ["--port",      "-P", Getopt::OPTIONAL],
  ["--verbose",   "-v", Getopt::BOOLEAN, Getopt::OPTIONAL]
)

HELP = opt['help']
HOST = opt['hostname']
PORT = opt['port']
JID = opt['jid']
PASSWORD = opt['password']
VERBOSE = opt['verbose']

def print_usage
  puts "Usage: #{$0} -j <JID> [-p <password>] [-H <host>] [-P <port>] [-v]"
  puts "or: #{$0} -h"
end

def print_help
  print_usage

  puts <<-EOT

    This plugin checks checks if logging into a given jabber server works.

    -h, --help
      Print this help message.

    -j, --jid
      Jabber ID to use for logging in.

    -p, --password
      Use this password for authenticating to the jabber server. If no password
      is given, anonymous authentication will be assumed.

    -H, --hostname
      If you want the plugin to connect to a host that is different from the
      domain part of the jabber id (e.g. to check a single jabber server from
      a jabber network), use this option to specify it.

    -P, --port
      Use this port for connecting to the jabber server.

    -v, --verbose
      Print lots of text.

Don't hesitate to contact Astro <stephan@spaceboyz.net> or leon <leon@leonweber.de>
for any questions about this plugin.

Copyright 2009 Stephan Maka <stephan@spaceboyz.net>
This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions; see <http://www.gnu.org/licenses/gpl.txt>
for the full license text.

  EOT
end

if HELP
  print_help
  exit 3
end

unless JID
  print_usage
  exit 3
end



require 'xmpp4r'

def status(lvl, s)
  puts "LOGIN #{lvl}: #{s}"
end
def method_missing(method, s)
  status(method.to_s, s)
end

jid, time = begin
  t1 = Time.now

  cl = Jabber::Client.new(JID)
  if VERBOSE
    Jabber::debug = true
  end
  cl.connect HOST, PORT
  if PASSWORD
    cl.auth
  else
    cl.auth_anonymous
  end
  cl.close

  t2 = Time.now
  [cl.jid.to_s, t2 - t1]
rescue Exception => e
  CRITICAL "#{e.class}: #{e.to_s}"
  exit 2
end
OK format("Successfull login as %s to %s:%s in %.3fs", jid, HOST, PORT, time)

