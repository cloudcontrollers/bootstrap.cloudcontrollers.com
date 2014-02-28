#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "$(date) downloading the current versions of our Downloading bootstrap scripts"

perl -MIO::Socket::INET -e ' 
until(new IO::Socket::INET("169.254.169.254:80")){print"Waiting for network...\n";sleep 1} 
' | logger -t ec2
# The next 3 variables are used to derive the S3 URL for config files. Currently they are set to 
# Cloud Controllers public buckets. On reboot, your server will poll these buckets for application 
# updates or  critical OS configuration updates and execute them. If you choose to "detach" this
# server from our update system, you may wish to copy the current CC bucket to your own S3 account
# and perhaps edit /etc/rc.local and other key files accordingly 
export S3_BUCKET=bootstrap.cloudcontrollers.com
export SERVER=alfresco
export ENVIRONMENT=public

# Hostname options: for a fully-qualified domain name (FQDN), e.g. webserver.cloudcontrollers.com, you might 
# just enter HOSTNAME=webserver.cloudcontrollers.com or instead reference the variables above with
# HOSTNAME=$SERVER.yourdomain.com, otherwise use the automatically generated EC2 public hostname,
# e.g. ec2-50-17-27-192.compute-1.amazonaws.com by entering 
# HOSTNAME=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/public-hostname)
export HOSTNAME=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/public-hostname)

echo "$(date) Installing the s3tools repos to make sure we have the latest debian packages for s3cmd"
wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | apt-key add -
wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
apt-get update
apt-get -y -qq install s3cmd

echo "$(date) Begining application setup"
echo "$(date) Setting access keys for Cloud Controllers public bucket downloads"
cd /root
wget http://${S3_BUCKET}.s3.amazonaws.com/shared/root/.s3cfg

echo "$(date) Downloading the current versions of our Downloading bootstrap scripts"
mkdir /usr/local/cc
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/app_configuration/ /usr/local/cc/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/public/app_configuration/ /usr/local/cc/
chmod -R +x /usr/local/cc/*

echo "$(date) Running bootstrap script1"
/usr/local/cc/shared_01_bootstrap.sh

echo "$(date) Running Alfresco App bootstrap script"
/usr/local/cc/01_alfresco_public_bootstrap.sh
