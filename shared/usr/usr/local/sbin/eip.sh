#!/bin/bash
#################################notes#################################
# cloudcontrollers-associate-eip.sh r1                                #
# this script runs at boot and sets the public IP to an Elastic IP    #
#         															  #
#                      												  #
# Created for Cloud Controllers by Jack Murgia						  #
#																	  #
# Have a better idea? Share it at 									  #
# http://wiki.cloudcontrollers.com/				  					  #
#######################################################################
. /usr/local/etc/env.conf

# Set the elastic IP
perl -MIO::Socket::INET -e ' 
until(new IO::Socket::INET("169.254.169.254:80")){print"Waiting for network...\n";sleep 1} 
' | logger -t ec2 
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
ec2-associate-address -i $INSTANCE_ID $EIP
