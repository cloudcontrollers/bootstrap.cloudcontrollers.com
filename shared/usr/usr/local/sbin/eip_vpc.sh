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
. /root/.bashrc_for_ec2
. /usr/local/aws-tools/aws-tools-env.sh

echo "Setting proxy for s3cmd downloads and other operations over http/https"
export EC2_JVM_ARGS="-Dhttp.proxySet=true -Dhttps.proxySet=true -Dhttp.proxyHost=aws.us-west-2.nodemodo.com -Dhttp.proxyPort=80 -Dhttps.proxyHost=aws.us-west-2.nodemodo.com -Dhttps.proxyPort=80"

perl -MIO::Socket::INET -e ' 
until(new IO::Socket::INET("169.254.169.254:80")){print"Waiting for network...\n";sleep 1} 
' | logger -t ec2 
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

ec2-associate-address -a $EIP --allow-reassociation -i $INSTANCE_ID
