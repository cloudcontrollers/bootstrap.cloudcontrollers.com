#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# We need to know where this server is being launched in order to set a few of the variables used
# by EC2 API tools on full-time servers 
AVAIL_ZONE=`curl -s --noproxy 169.254.169.254  -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
REGION="`echo \"$AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
# We need to now the size of the instance to provision memory to processes correctly
INSTANCE_TYPE=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/instance-type)

# For use in /etc/hosts with other configuration files that require the 
# local (NAT) IP (not all configurations require, this, but for some it's mandatory
# such as if you wish to properly enable the local Postfix server)

LOCAL_IPV4=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/local-ipv4)
# INSTANCE_ID is useful too
# We need to know the instanceID to set tags
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "$(date) Bootstrap script1: Running bootstrap script2"
/usr/local/cc/shared_02_bootstrap.sh
echo "$(date) Bootstrap script1: Running bootstrap script3"
/usr/local/cc/shared_03_bootstrap.sh
echo "$(date) Bootstrap script1: Running bootstrap script4"
/usr/local/cc/shared_04_bootstrap.sh