#!/usr/bin/python
"""Helpdesk_Password_Change.py
**************************************
Author: Andrew Barrett
Version: 1.0
Date: 4/28/15
Purpose: To randomize the helpdesk local account on a mac,
then have the password securely sent to the JSS.  Each machine
will have a different password for the helpdesk account.  This
password will be displayed in an extension attribute.

This script is available to anyone who feels it would be beneficial
to their organization or any other group.  There is no warranty that
come from using this script.

This program is licensed under the GNU General Public License.

"""
import subprocess
import random
import string
import urllib
import urllib2
import base64
import sys
import ssl
import plistlib
import xml.etree.ElementTree as ET
from functools import wraps
user = ''
UserName=''
PassWord=''

def random_password(size=8, chars=string.ascii_lowercase + string.digits):
	""" Randomized password for helpdesk local account.
	"""
	return ''.join(random.choice(chars) for _ in range(size)) + ''.join(random.choice(string.punctuation))
	
	
def change_password(random_password):
	"""
	This takes the random password generated and sets the
	password for the helpdesk account.
	"""
	passwd = subprocess.Popen(['/usr/bin/dscl', '.', '-passwd', '/Users/helpdesk', random_password])
	(err, out) = passwd.communicate()
	print err, out
	print passwd.returncode
	print random_password
	if passwd.returncode == 0:
		update_JSS(random_password)
	else:
		print random_password
		print passwd.returncode
		sys.exit('Failed to change Password')
			
def update_JSS(new_pass):
	"""
	Imports computer id and uses it to update the JSS with the
	new hepldesk password for each computer.
	"""
	get_machine_serial()
	PUTxml = '''<computer>
    	<extension_attributes>
        	<attribute>
            	<name>Helpdesk Password</name>
            	<value>%s</value>
        	</attribute>
    	</extension_attributes>
	</computer>''' % new_pass
	request = urllib2.Request('https://chscasper.benefitfocus.com:8443/JSSResource/computers/id/' + computer_id)
	request.add_header('Authorization', 'Basic ' + base64.b64encode(UserName + ':' + PassWord))
	request.add_header('Content-Type', 'text/xml')
	request.get_method = lambda: 'PUT'
	response = urllib2.urlopen( request, PUTxml )
	
def get_machine_serial():
	"""
	Pulls serial from machine.
	"""
	serial_number = subprocess.Popen(["ioreg", "-l"], stdout=subprocess.PIPE)
	serialout, serialerr = serial_number.communicate()
	lines = serialout.split('\n')
	raw_line = ''
	for i in lines:
		if i.find('IOPlatformSerialNumber') > 0:
			serial_number = i.split('=')[-1]
			serial_number = serial_number.strip()
			serial_number = serial_number.strip('"')
			get_machine_id(serial_number)

def get_machine_id(serial):
	"""
	Takes the serial from get_machine_serial and then
	pulls the id from JSS of machine.
	"""
	request = urllib2.Request('https://chscasper.benefitfocus.com:8443/JSSResource/computers/serialnumber/' + serial)
	request.add_header('Authorization', 'Basic ' + base64.b64encode(UserName + ':' + PassWord))
	response = urllib2.urlopen(request)
	JSSResponse = response.read()
	#print JSSResponse
	xml = ET.fromstring(JSSResponse)
	for id in xml.iter('id'):
		global computer_id 
		computer_id = id.text
		break
	return computer_id
	

def sslwrap(func):
	"""
	Fixes issue with securely connecting the JSS.
	"""
    @wraps(func)
    def bar(*args, **kw):
        kw['ssl_version'] = ssl.PROTOCOL_TLSv1
        return func(*args, **kw)
    return bar

ssl.wrap_socket = sslwrap(ssl.wrap_socket)

change_password(random_password())
