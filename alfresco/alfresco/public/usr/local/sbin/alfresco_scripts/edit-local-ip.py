#!/usr/bin/env python
#######################################################################
# cloudcontrol-ipset.py r1                                            #
# this script updates files with the current ip address at first boot #
#         and writes IP to /etc/current_ip for comparsion by          #
#         other scripts in the event IP changes on subsequent reboots #
#         and also restarts sendmail (useful for some apps).		  #
#                               ~configure~                           #
# files = '/path/to/file1', '/path/to/file2/' file to replace #ip~up# #
#          placeholder with IP address of interface                   #
# interface = 'eth0|ath0|wlan0|etc0' = name of the interface to poll  #
# log = '/path/to/firstrun/log' = log file                            #
#                      												  #
# Created for Cloud Controllers by mirimar, based on ipup.py script   #
# posted by kumico at http://bbs.archlinux.org/viewtopic.php?id=40655 #
#																	  #
# Have a better idea? Share it at http://wiki.cloudcontrollers.com    #
#######################################################################
import re
import os.path
import shutil
from subprocess import PIPE, Popen

files = ['/etc/authbind/byuid/110','/etc/apache2/conf.d/proxy_ajp']
interface = 'eth0'
log = '/var/log/firstrun'

def replace_ip(filename, ip):
  handle = open(filename, 'r')
  hbuf = handle.read()
  handle.close()
  hpat = re.compile('.*#ip~up#.*', re.DOTALL)
  ih = hpat.search(hbuf) # Just decide if we're going to process the file...
  if ih and ip:
    try:
      # Now actually run the final regexp
      out = re.sub('#ip~up#', ip, hbuf);
      handle = open(filename, 'w')
      handle.write(out)
      logh.write('updated ip address to ' + ip + ' in file ' + filename  + "\n")
      
    except:
      logh.write('failed to update ' + filename  + "\n")
      logh.write('maybe you don\'t have permission to write to it?\n')
  else:
    ih = ih and ih.group(2)
    logh.write('failed to get old ip address(es)\n')
    logh.write('old ip(' + filename + '): ')
    try:
      logh.write(ih)
    except:
      logh.write("(unknown old ip)")
    
    logh.write("\n  new ip(ifconfig):" + ip  + "\n")

logh = open(log, "a")
logh.write("Starting...\n")
if (os.path.isfile("/root/firstrun")):
  for file in files:
    shutil.copy2(file, file + ".bak")

ibuf = Popen(['ifconfig', interface], stdout=PIPE).stdout.read()
ipat = re.compile('inet addr:(\d+\.\d+\.\d+\.\d+) ')
ip = ipat.search(ibuf)
ip = ip and ip.group(1)
logh.write("Detected IP " + ip  + "\n")
try:
  handle = open("/etc/current_ip", 'w')
  handle.write(ip)
  logh.write('updated ip address to ' + ip + " in file /etc/current_ip\n")

except:
  logh.write("failed to update /etc/current_ip\n")
  logh.write('maybe you don\'t have permission to write to it?\n')

for file in files:
  replace_ip(file, ip)

logh.write("Finished\n")
logh.close