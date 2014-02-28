#!/usr/bin/env python

#################################notes#################################
# cloudcontrol-passwordsetup.py r1                                    #
# this script runs at first boot of the server and generates unique	  #
#           passwords for the system root user, MySQL root users,     #
# 			other MySQL database users and encryption key password or #
#           other configuration file user name and password combin-   #
#			ations by replacing "placeholder" user and password values#
# 			in the specifed system, MySQL users and config files      #
#                      												  #
# Created for Cloud Controllers by mirimar							  #
#																	  #
# Have a better idea? Share it at 									  #
# http://wiki.cloudcontrollers.com					  #
#######################################################################

# Udates system & MySQL root passwords on first boot
files = ['/home/ubuntu/passwords','/home/ubuntu/duncil']
userpasswords = {'root':'ROOTPASSWORD'}
otherpasswords = ['OTHERPASSWORD']
log = '/var/log/firstrun'

import random, string
import crypt
import re
import time
from subprocess import PIPE, Popen

def getsalt(chars = string.letters + string.digits):
    # generate a random 2-character 'salt'
    return random.choice(chars) + random.choice(chars)

def getpwd(chars = string.letters + string.digits, len = 12):
    retval = "";
    for i in range(0, len):
    # generate 12 character alphanumeric password
        retval += random.choice(chars)
        
    return retval

def replace_pass(filename):
    handle = open(filename, 'r')
    hbuf = handle.read()
    handle.close()
    for placeholder, password in pdict.iteritems():
        hbuf = re.sub(placeholder, password, hbuf)
    
    try:
        # Output file
        handle = open(filename, 'w')
        handle.write(hbuf)
        handle.close()
    except:
        pass
        #logh.write('failed to update ' + filename  + "\n")
        #logh.write('maybe you don\'t have permision to write to it?\n')

logh = open(log, "a")
logh.write("Starting...\n")
# Generate passwords
pdict = {}
for user, placeholder in userpasswords.iteritems():    
    syspass = getpwd()
    Popen(['usermod', '--password', crypt.crypt(syspass, getsalt()), user])
    logh.write(placeholder + ": User " + user + " --> " + syspass + "\n")
    pdict[placeholder] = syspass

# What's the MySQL Root password placeholder?
mplace = mysqlpasswords['root']
for user, placeholder in mysqlpasswords.iteritems(): 
    mpass = getpwd()
    if (("root" in mysqlpasswords) and (mysqlpasswords['root'] in pdict)):
        mrootpass = pdict[mysqlpasswords['root']]
    else:
        mrootpass = ""
        
    Popen(['mysql', '-uroot', "--password=" + mrootpass, "-e", "UPDATE user SET Password = PASSWORD('" + mpass + "') WHERE User = '" + user + "';FLUSH PRIVILEGES;","mysql"])
    logh.write(placeholder + ": MySQL " + user + " --> " + mpass + "\n")
    pdict[placeholder] = mpass
    time.sleep(3)
    
for placeholder in otherpasswords:
    opass = getpwd()
    logh.write(placeholder + ": " + opass + "\n")
    pdict[placeholder] = opass
    
# Update passwords
for file in files:
    logh.write("Replacing placeholders in " + file + "\n")
    replace_pass(file)
    
logh.write("Finished\n")
logh.close
