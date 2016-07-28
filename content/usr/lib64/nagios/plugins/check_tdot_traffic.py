#!/usr/bin/python

# A script to check for I 24 Traffic
# David Mabry
# 08-17-2013
#
# 2016-04-21 - Steve Black - Updated tdot URL to 
#       http://m.tdot.tn.gov/DisplayIncidentConstructionData.aspx?Info=0&Region=3
#

from BeautifulSoup import BeautifulSoup
import requests
import optparse

parser = optparse.OptionParser('%prog -i <interstate> -r <regions number>\nExample: %prog -i "Interstate 24" -r 3')
parser.add_option('-i', '--interstate', dest='interstate', type='string',\
                    help='specify the interstate to monitor')
parser.add_option('-r', '--region', dest='region', type='string',\
                    help='specify the region number 3 = Middle TN')
parser.add_option('-d', '--debug', action='store_true', dest='debug')
    
(options, args) = parser.parse_args()
    
if options.debug:
    debug = True
else:
    debug = False

if options.region:
    region = options.region
else:    
    region = 3

if options.interstate:
    interstate = options.interstate
else:
    interstate = 'Interstate 24'

info = 0
count = 0
returnCode = 0
OKreturnMsg = "OK - No Traffic Incidents found for %(interstate)s"
CRITreturnMsg = "CRITICAL - %(num)s Traffic Incidents found for %(interstate)s: %(incidents)s"
url = 'http://m.tdot.tn.gov/DisplayIncidentConstructionData.aspx?Info=%(info)s&Region=%(region)s'
payload = {
    'info': info,
    'region': region,
}

try:
  r = requests.get(url % payload)

  soup = BeautifulSoup(r.text)
  incidents = [td.text for td in soup.findAll('td', attrs={'align': 'left'})]
  matchedIncidents = []

  if debug:
      print "URL: " + url % payload + "\n\n"
      print "Here's the pretty output:\n\n"
      print(soup.prettify())

  for i in incidents:
      if interstate in i:
          count = count + 1
          matchedIncidents.append(i)
  if count > 0:
      incidentText = ""
      for i in matchedIncidents:
          incidentText = incidentText + i + "; "
    
      payload = {
          'num': str(count),
          'interstate': interstate,
          'incidents': incidentText,
      }
      print CRITreturnMsg % payload
      exit(2)
  else:
      payload = {
          'interstate': interstate,
      }
      print OKreturnMsg % payload
      exit(0)
except Exception as e:
  print "Oops - " + e
  exit(3)
