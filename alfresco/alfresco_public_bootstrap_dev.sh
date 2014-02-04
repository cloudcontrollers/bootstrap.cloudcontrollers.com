#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "$(date) downloading the current versions of our bootstrap scripts"

perl -MIO::Socket::INET -e ' 
until(new IO::Socket::INET("169.254.169.254:80")){print"Waiting for network...\n";sleep 1} 
' | logger -t ec2
# The next 3 variables are used to derive the S3 URL for config files. Currently they are set to 
# Cloud Controllers public buckets. On reboot, your server will poll these buckets for application 
# updates or  critical OS configuration updates and execute them. If you choose to "detach" this
# server from our update system, you may wish to copy the current CC bucket to your own S3 account
# and perhaps edit /etc/rc.local and other key files accordingly 
S3_BUCKET=bootstrap.cloudcontrollers.com
SERVER=alfresco
ENVIRONMENT=public

echo "$(date) Downloading the current versions of our bootstrap scripts"
cd /root
wget http://$S3_BUCKET.s3.amazonaws.com/shared/root/.s3cfg
mkdir /usr/local/cc
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/app_configuration/ /usr/local/cc/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/public/config/ /usr/local/cc/

chmod -R +x /usr/local/cc/*

echo "$(date) Bootstrap script1"
/usr/local/cc/shared_01_bootstrap.sh
echo "$(date) Bootstrap script2"
/usr/local/cc/shared_02_bootstrap.sh
echo "$(date) Bootstrap script3"
/usr/local/cc/shared_03_bootstrap.sh
echo "$(date) Bootstrap script4"
/usr/local/cc/shared_04_bootstrap.sh
echo "$(date) Alfresco App bootstrap"
/usr/local/cc/01_alfresco_public_bootstrap.sh





