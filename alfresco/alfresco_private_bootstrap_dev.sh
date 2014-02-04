#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "$(date) installing dependencies and configuring system"
# wait for EC2 instance's network link to be active
#
perl -MIO::Socket::INET -e ' 
until(new IO::Socket::INET("169.254.169.254:80")){print"Waiting for network...\n";sleep 1} 
' | logger -t ec2
#
# The next 3 variables are used to derive the S3 URL for config files. Currently they are set to 
# Cloud Controllers public buckets. On reboot, your server will poll these buckets for application 
# updates or  critical OS configuration updates and execute them. If you choose to "detach" this
# server from our update system, you may wish to copy the current CC bucket to your own S3 account
# and perhaps edit /etc/rc.local and other key files accordingly 
#
S3_BUCKET=bootstrap.cloudcontrollers.com
SERVER=alfresco
ENVIRONMENT=public
#
# EIP is optional, but the right thing to do for full-time servers. EC2 servers which are rebooted
# retain their DHCP assigned IP address, but servers which are stopped or lost due to hardware failure
# will lose their IP address, requiring careful edits to key files. Visit http://wiki.cloudcontrollers.com
# for more information on how to deploy this server as a full time server with a static Elastic IP address
#
#EIP=
#
#
# We need to know where this server is being launched in order to set a few of the variables used
# by EC2 API tools on full-time servers 
#
AVAIL_ZONE=`curl -s --noproxy 169.254.169.254  -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
REGION="`echo \"$AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
#
# We need to now the size of the instance to provision memory to processes correctly
#
INSTANCE_TYPE=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/instance-type)
# Hostname options: for a fully-qualified domain name (FQDN), e.g. webserver.cloudcontrollers.com, you might 
# just enter HOSTNAME=webserver.cloudcontrollers.com or instead reference the variables above with
# HOSTNAME=$SERVER.yourdomain.com, otherwise use the automatically generated EC2 public hostname,
# e.g. ec2-50-17-27-192.compute-1.amazonaws.com by entering 
# HOSTNAME=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/public-hostname)
#
HOSTNAME=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/public-hostname)
#
# For use in /etc/hosts with other configuration files that require the 
# local (NAT) IP (not all configurations require, this, but for some it's mandatory
# such as if you wish to properly enable the local Postfix server)
#
LOCAL_IPV4=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/local-ipv4)
#
#
echo "$(date) Insert note on how to add ssh keys for authorized users of root account in /root/.ssh/authorized_keys" 
AUTH_KEYS=/root/.ssh/authorized_keys
cat << EOF >> $AUTH_KEYS
INSERT PUBLIC KEY HERE FOR SSH PUBLIC KEY AUTHENTICATION- PASSWORD AUTHENTICATION IS OFF BY DEFAULT
ssh-dss AAAAB3NzaC1kc3MAAACBAKTf7Ymw5u1MND566QIZIlqzExLJ9nhs+C6Yx4kZECldAggKS2vEUvjcTUQQaOv+Xem7KnUCqO3NKkzIUehBgA/tURvvTVFxvGUglcpP6/s15+0PoFPwYEgOJ+BI4LisB+IJ6Xg0YiQXo0/wIQWAV5+2AMblE8fuOVa39RyxOB2zAAAAFQDtzvch6Ub4emcV3jvWaO6++BySswAAAIEAgbCQzkQhCQBDXagHFVG9seynYDDeyQ8y3QLmAFrxR2ELJLNg6a+8Eb83K0xi+1BfLfrvEN0ugMv43cEdCn1AU59ZviRs2mfxvh+oqFRC3Q9zuH1PAT5++ItfMw4AJfNcfUHLKFaIaqEz27E9mqQAhpwP0zv0onPYNxnZkz0xiUoAAACAfq/ccxNL0G0l0v5uYOBc+Re4SkcZL3YvPLWjgj0Kly8j6JiftBrc/bI9x6KvEbKLdrtXPcPc2lkAjTlur5IGv6GTBs6rdc0h93xC+r4Yvb3rfm+DvwrZdd6cRzzqWtJ5qFH+CNSiy9Q3I2mIctV3e9Cy/MLvEKVfwgJu4n6fObc= jack@edmodo.com
ssh-dss AAAAB3NzaC1kc3MAAACBAKnh3pBW5GWWuDkjg8HUqiYii+GuT8qkQTOSUqBIx3bod6/WLMdi7Jl7AHWEY3lS4RYvibiOBppKzkDAuOXOrJ6BowSnNr6PsQUH1bv1FaBVegDO8WBly4WIyJBrw6W+aKJ9Sid6UZGmXeeQuw3gOZWaLINQxNMe5CTTNxNce5OXAAAAFQCnkNXQt8H/t2eZxdUxRdMgR6dfawAAAIBAHM4ZWb4ll43IfTg61AzG2ecQ83XZO9Veh6dZ6WJtOthx1uGucpalnUm6bPRhfTNH3RozvgJWomBUjQKXIbuL4EDgZWg6crdA/YvQ6J0ZjmkEaR3Bp4THAvnM3TJk15o7Zt7+Xga1qNrgJk/JjA1p8LLlpkaCeviCIbIiCxDtJwAAAIAHqSxSYiDiHriztFKv2e9g4CU6vyH2vjln8CMOiF1ctZ/P20AaP7UAEmgMuxcCV9lSRWZsLqzm3XOhxO8fEZ7p8N3wYaoH+EOQ+4bSkKJShG7NssCoyz6Ce2agkOaDkT0CgeOGe+0gg/w99KF91RV3K1qJiVP+CobOwT4dmvMHIg== luka.cky@gmail.com

EOF

echo "$(date) Setting up AWS CLI tools"
apt-get update
apt-get -y -qq install git-core
cd /usr/local/
git clone http://github.com/floodfx/aws-tools.git
chmod +x /usr/local/aws-tools/aws-tools-env.sh
# when we automate git clone to s3 bucket, we will do this instead:
#s3cmd --config /root/.s3cfg get  --force s3://$S3_BUCKET/shared/usr/local/aws.tgz /usr/local/
#cd /usr/local/ 
#tar -xzf aws.tgz

echo "$(date) Remember to run 'vi /root/.ec2/aws-access-keys.txt' if/when you configure this server to access a private S3 bucket"

echo "$(date) Installing the s3tools repos to make sure we have the latest debian packages for s3cmd"
wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | apt-key add -
wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
#
echo "$(date) Editing sshd config to prevent time expiration logouts" 
SSHD_FILE=/etc/ssh/sshd_config
cat << EOF >> $SSHD_FILE
ClientAliveInterval 30
ClientAliveCountMax 99999
EOF
#
echo "$(date) Editing ulimit to override the default limit on file descriptors"
SYSCTL=/etc/sysctl.conf
cat << END >> $SYSCTL
fs.file-max = 200000
END
#
echo "$(date) Running the sysctl command to override the default limit on file descriptors"
sysctl -p
#
echo "$(date) Editing limit.conf to override the default limit on file descriptors"
LIMITS=/etc/security/limits.conf
cat << STOP >> $LIMITS
* hard nofile 200000
* soft nofile 200000
root hard nofile 200000
root soft nofile 200000
STOP
ulimit -n 200000
#
echo "$(date) Installing webmin"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions
wget -q http://www.webmin.com/download/deb/webmin-current.deb
dpkg -i webmin-current.deb 
apt-get -y -f install

echo "$(date) Installing packages which enable web management, monitoring, outgoing smtp via postfix, ebs attachment scripts, s3 bucket management, Amazon Route53 DNS management, unzip and the locate command"
wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | apt-key add -
wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
apt-get -y -qq update
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' install s3cmd postfix xfsprogs unzip htop nagios-nrpe-server snmpd procmail ruby1.9.1 rubygems1.9.1 ruby1.9.1-dev build-essential libopenssl-ruby mlocate unzip
#gem install route53

apt-get -y autoremove
#
echo "$(date) Begining application setup"
echo "$(date) Setting access keys for Cloud Controllers public bucket downloads"
cd /root
wget http://$S3_BUCKET.s3.amazonaws.com/shared/root/.s3cfg
#
#
# Begin shared server configuration file downloads and setup
# this section is the same irregardless of server or environment
#
#
echo "$(date) Setting hostname"
echo -e "$LOCAL_IPV4 $HOSTNAME \n127.0.0.1 localhost"  > /etc/hosts
echo $HOSTNAME > /etc/hostname
hostname $HOSTNAME
#
#
echo "$(date) Setting postfix hostname to actual hostname"
MAILNAME=/etc/mailname
cat << END > $MAILNAME
$HOSTNAME
END

echo "$(date) Making directory for splash page"
mkdir -p /opt/data

# downloading various scripts and configuration files 
#
# Always follow logical file override order:
# /$S3_BUCKET/shared/...
# /$S3_BUCKET/shared/$ENVIRONMENT...
# /$S3_BUCKET/$SERVER/shared/... 
# /$S3_BUCKET/$SERVER/$ENVIRONMENT/...
#
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/home/ /home/

s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/root/ /root/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/$ENVIRONMENT/root/ /root/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/shared/root/ /root/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/root/ /root/

s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/etc/ /etc/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/$ENVIRONMENT/etc/ /etc/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/shared/etc/ /etc/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/ /etc/

s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/opt/ /opt/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/$ENVIRONMENT/opt/ /opt/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/shared/opt/ /opt/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/opt/ /opt/

s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/usr/ /usr/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/$ENVIRONMENT/usr/ /usr/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/shared/usr/ /usr/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/usr/ /usr/

chmod +x /usr/local/sbin/*
chmod +x /usr/local/sbin/*/*

echo "$(date) Installing Alfresco dependencies and java jdk 1.7"
yes|add-apt-repository ppa:libreoffice/ppa
yes|add-apt-repository ppa:guilhem-fr/swftools
yes|add-apt-repository ppa:webupd8team/java
apt-get -y -qq update
echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef'  install lynx-cur mdadm subversion apache2-mpm-worker oracle-java7-installer python-software-properties ffmpeg imagemagick swftools ttf-mscorefonts-installer libreoffice libtcnative-1 tomcat7 postgresql

echo "$(date) Setting up the environment variables file usr/local/etc/env.conf"
sed -i "s/SERVER=/SERVER=$SERVER/" /usr/local/etc/env.conf
sed -i "s/ENVIRONMENT=/ENVIRONMENT=$ENVIRONMENT/" /usr/local/etc/env.conf
sed -i "s/export HOSTNAME=/export HOSTNAME=$HOSTNAME/" /usr/local/etc/env.conf
sed -i "s/java-6-openjdk-amd64/java-7-oracle/" /usr/local/etc/env.conf

echo "$(date) Setting oracle-java7 as system default"
apt-get install oracle-java7-set-default

echo "$(date) Making some directories we need on the system boot volume"
mkdir -p /etc/apache2/certs/
mkdir -p /var/lib/tomcat7/shared/classes/alfresco/extension
mkdir -p /var/lib/tomcat7/shared/classes/alfresco/messages
mkdir -p /var/lib/tomcat7/shared/classes/alfresco/web-extension

#echo "$(date) Attaching /dev/xvdf for /opt/data1"
#export VOL=VOL1
#export DEVICE=xvdf
#export DEVICE_SIZE=10
#export MOUNT=/opt/data1
#/usr/local/sbin/ebs_create_and_attach.sh

##echo "confirming ebs attachment of /dev/xvdf"
#mount -all
#	until df | grep "/dev/xvdf"; do 
#	echo "attempting to mount ebs device xvd"
#	sleep 2; 
#done

#echo "$(date) Attaching /dev/xvde for /opt/data2"
#export VOL=VOL2
#export DEVICE=xvde
#export DEVICE_SIZE=10
#export MOUNT=/opt/data2
#/usr/local/sbin/ebs_create_and_attach.sh

#echo "confirming ebs attachment of /dev/xvde"
#mount -all
#	until df | grep "/dev/xvde"; do 
#	echo "attempting to mount ebs device xvde"
#	sleep 2; 
#done

echo "Making some directories on our new ebs volumes"
mkdir -p /opt/data/var/www/htdocs
mkdir -p /opt/data1/alf_data
mkdir -p /opt/data2/var/lib/postgresql


echo "$(date) Symlinking web root"
rm -rf /var/www
ln -s /opt/data/var/www /var/www

echo "$(date) Setting up apache2 configuration"
chown -R www-data:www-data /opt/data/var/www/htdocs
a2ensite default-ssl
a2enmod ssl
a2enmod proxy
a2enmod proxy_ajp
a2enmod rewrite
update-rc.d apache2 defaults 20

echo "$(date) Setting up Alfresco"
cd /usr/share/tomcat7/lib
wget http://jdbc.postgresql.org/download/postgresql-9.1-901.jdbc3.jar
cd /opt/data2/
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/shared/app_installers/alfresco-community-4.2.e.zip /opt/data2/alfresco-community-4.2.e.zip
unzip alfresco-community-4.2.e.zip
#rm -rf bin licenses README.txt web-server
#unzip alfresco-community-5-latest.zip
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/var/lib/tomcat7/shared/classes/alfresco-global.properties  /var/lib/tomcat7/shared/classes/alfresco-global.properties
ln -s /opt/data2/web-server/webapps/alfresco.war  /var/lib/tomcat7/webapps/alfresco.war
ln -s /opt/data2/web-server/webapps/share.war  /var/lib/tomcat7/webapps/share.war
chown -R tomcat7:tomcat7 /opt/data1/web-server /var/lib/tomcat7 /opt/data1/alf_data
#update-rc.d tomcat7 defaults
#postgresql -h localhost -uroot < /usr/local/sbin/${SERVER}_scripts/alfresco_db.sql
#
echo "$(date) Setting default system root and postgresql root password used by password setup scripts"
echo "root:ROOTPASSWORD"|chpasswd
#
echo "$(date) Commencing the application bootstrapping scripts"
echo "$(date) setting up unique ssl cert"
/usr/local/sbin/sslcertsetup.sh
echo "$(date) Writing hostname and localip to key config files"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/edit-hostname.py
echo "$(date) Writing new IP to key config files"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/edit-local-ip.py
#echo "$(date) checking to see if postgresql is running before commencing password setup"
#/usr/local/sbin/postgresqlcheck.sh
echo "$(date) commencing password setup"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/passwordsetup.py
echo "$(date) passwords setup complete- written to /home/ubuntu/passwords"
#
#echo "$(date) Setting up rc.local to insure local IP changes are propagated and processes start cleanly on reboot"
#s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/rc.local  /etc/rc.local 
chmod +x /etc/rc.local
update-rc.d -f rc.local remove
update-rc.d rc.local defaults 99
#
echo "$(date) updating all packages and kernel and rebooting system"
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' dist-upgrade
#
echo "$(date) relocating postgresql data to persistent ebs volume"
service postgresql stop
cp -pr /var/lib/postgresql/* /opt/data2/var/lib/postgresql/
chown -R postgres:postgres /opt/data2/var/lib/postgresql/
rm -rf /var/lib/postgresql
ln -s /opt/data2/var/lib/postgresql /var/lib/postgresql
#s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/apparmor.d/usr.sbin.postgresqld  /etc/apparmor.d/usr.sbin.postgresqld
#s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/postgresql/my.cnf.$INSTANCE_TYPE  /etc/postgresql/my.cnf

echo "$(date) incrementing the public AMI launch count"
s3cmd --config /root/.s3cfg get --recursive --force --no-progress s3://$S3_BUCKET/shared/etc/lynx-cur  /etc/
/usr/local/sbin/${SERVER}_scripts/launchcount.sh

echo "$(date) ending user data script and rebooting to activate latest kernel"
#rm -rf /var/lib/cloud/data/scripts/bootstrap.sh
reboot
