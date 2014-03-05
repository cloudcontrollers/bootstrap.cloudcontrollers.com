#!/usr/bin/env python
#######################################################################
# cloudcontrollers-hostname.py r1                                     #
# this script updates configuration files with the public hostname    #
#         and writes the hostname to /etc/current_hostnameip at first #
#         boot for comparsion by other scripts in the event the public#
#		  hostname changes on subsequent reboots. It also restarts 	  #
#		  sendmail (useful for some apps).							  #
#                               ~configure~                           #
# files = '/path/to/file1', '/path/to/file2/' file to replace the	  #
#          placeholder 'localname' with the public DNS name written to#
# 		  /etc/hostname by the cloudcontrollers-publichostnamesetup.sh#
#		  script, which is called earlier at first boot by 			  #
#		  /etc/rc.local.         									  #
#                      												  #
# Created for Cloud Controllers by Jack Murgia based on				  #
# controllers-ipsetup.oy by mirimar, which is based on ipup.py script #
# posted by kumico at http://bbs.archlinux.org/viewtopic.php?id=40655 #
#																	  #
# Have a better idea? Share it at 									  #
# http://www.cloudcontrollers.com/community/wiki					  #
#######################################################################

import re
import os
import os.path
import socket
import shutil

from subprocess import call, PIPE, Popen

files = ['/etc/apache2/sites-available/default','/opt/data/var/www/htdocs/index.html']
log = '/var/log/firstrun'

def replace_hostname(filename, HOSTNAME):
  handle = open(filename, 'r')
  hbuf = handle.read()
  handle.close()
  hpat = re.compile('.*localname.*', re.DOTALL)
  ih = hpat.search(hbuf) # Just decide if we're going to process the file...
  if ih and HOSTNAME:
    try:
      # Now actually run the final regexp
      out = re.sub('localname', HOSTNAME, hbuf);
      handle = open(filename, 'w')
      handle.write(out)
      logh.write('updated hostname address to ' + HOSTNAME + ' in file ' + filename  + "\n")
      
    except:
      logh.write('failed to update ' + filename  + "\n")
      logh.write('maybe you don\'t have permission to write to it?\n')
  else:
    ih = ih and ih.group(2)
    logh.write('failed to get old hostname\n')
    logh.write('old hostname(' + filename + '): ')
    try:
      logh.write(ih)
    except:
      logh.write("(unknown old ip)")
    
    logh.write("\n  new hostname:" + HOSTNAME  + "\n")

logh = open(log, "a")
logh.write("Starting...\n")
if (os.path.isfile("/root/firstrun")):
  for file in files:
    shutil.copy2(file, file + ".bak")

#ibuf = Popen(['ifconfig', interface], stdout=PIPE).stdout.read()
#ipat = re.compile('inet addr:(\d+\.\d+\.\d+\.\d+) ')
#ip = ipat.search(ibuf)
HOSTNAME = socket.gethostname()
logh.write("Detected hostname " + HOSTNAME  + "\n")
try:
  handle = open("/etc/current_hostname", 'w')
  handle.write(ip)
  logh.write('updated hostname address to ' + HOSTNAME + " in file /etc/current_hostname\n")

except:
  logh.write("failed to update /etc/current_hostname\n")
  logh.write('maybe you don\'t have permission to write to it?\n')

for file in files:
  replace_hostname(file, HOSTNAME)

logh.write("Finished\n")
logh.close
