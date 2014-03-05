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
SERVER=crashplan
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
AVAIL_ZONE=`curl -s --noproxy 169.254.169.254 http://169.254.169.254/latest/meta-data/placement/availability-zone`
REGION="`echo \"$AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
#
# We need to now the size of the instance to provision memory to processes correctly
#
INSTANCE_TYPE=$(curl -s --noproxy 169.254.169.254 http://169.254.169.254 /latest/meta-data/instance-type)
# Hostname options: for a fully-qualified domain name (FQDN), e.g. webserver.cloudcontrollers.com, you might 
# just enter HOSTNAME=webserver.cloudcontrollers.com or instead reference the variables above with
# HOSTNAME=$SERVER.yourdomain.com, otherwise use the automatically generated EC2 public hostname,
# e.g. ec2-50-17-27-192.compute-1.amazonaws.com by entering 
# HOSTNAME=$(curl -s --noproxy 169.254.169.254 http://169.254.169.254 /latest/meta-data/public-hostname)
#
HOSTNAME=$(curl -s --noproxy 169.254.169.254 http://169.254.169.254 /latest/meta-data/public-hostname)
#
# the expect command needs to know the "host" section of the FQDN
# if we made our own FQDN entry in DNS, like crashplan.mydomain.com it might be HOST=crashplan
HOST=`echo $HOSTNAME | sed -rn 's/\.us-west-1\.compute\.amazonaws\.com//p'`
#
# For use in /etc/hosts with other configuration files that require the 
# local (NAT) IP (not all configurations require, this, but for some it's mandatory
# such as if you wish to properly enable the local Postfix server)
#
LOCAL_IPV4=$(curl -s --noproxy 169.254.169.254 http://169.254.169.254 /latest/meta-data/local-ipv4)
#
#
echo "$(date) adding ssh keys for authorized dashboard users" 
AUTH_KEYS=/root/.ssh/authorized_keys
cat << EOF >> $AUTH_KEYS
INSERT PUBLIC KEY HERE FOR SSH PUBLIC KEY AUTHENTICATION- PASSWORD AUTHENTICATION IS OFF BY DEFAULT
EOF
echo "$(date) appending ec2 variable file to /root/.bashrc" 
BASHRC=/root/.bashrc
cat << EOF >> $BASHRC
# import these environment variables for our ec2 scripts and other application specific variables
. /usr/local/etc/env.conf
EOF

echo "$(date) downloading current AWS command line tools"
apt-get -y autoremove
apt-get clean
apt-get update
apt-get -y -qq install git-core
cd /usr/local/ 
git clone http://github.com/floodfx/aws-tools.git
chmod +x /usr/local/aws-tools/aws-tools-env.sh

echo "$(date) Installing the s3tools repos to make sure we have the latest debian packages for s3cmd"
wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | apt-key add -
wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
#
echo "$(date) editing sshd config to prevent time expiration logouts" 
SSHD_FILE=/etc/ssh/sshd_config
cat << EOF >> $SSHD_FILE
ClientAliveInterval 30
ClientAliveCountMax 99999
EOF
#
echo "$(date) editing ulimit to override the default limit on file descriptors"
SYSCTL=/etc/sysctl.conf
cat << END >> $SYSCTL
fs.file-max = 200000
END
#
echo "$(date) running the sysctl command to override the default limit on file descriptors"
sysctl -p
#
echo "$(date) editing limit.conf to override the default limit on file descriptors"
LIMITS=/etc/security/limits.conf
cat << STOP >> $LIMITS
* hard nofile 65535
* soft nofile 65535
root hard nofile 65535
root soft nofile 65535
STOP
ulimit -n 65535
#
echo "$(date) installing packages which enable web management, monitoring, outgoing smtp via postfix, ebs attachment scripts, s3 bucket management, Amazon Route53 DNS management, unzip and the locate command"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install postfix
apt-get -y install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions
wget http://www.webmin.com/download/deb/webmin-current.deb
dpkg -i webmin-current.deb 
apt-get -y -f install
apt-get -y install xfsprogs htop nagios-nrpe-server snmpd procmail ruby1.8 rubygems1.8 ruby-dev build-essential libopenssl-ruby mlocate unzip lynx-cur mdadm subversion expect openjdk-6-jre-headless openjdk-6-jdk
wget http://wi-fizzle.com/downloads/autoexpect
chmod a+x autoexpect
mv autoexpect /usr/bin/autoexpect
gem install route53
apt-get update
apt-get -y install s3cmd
apt-get -y autoremove
#
echo "$(date) begining application setup"
echo "$(date) Setting access keys for Cloud Controllers public bucket downloads"
cd /root
curl http://$S3_BUCKET.s3.amazonaws.com/shared/root/.s3cfg > /root/.s3cfg
#
#
# Begin shared server configuration file downloads and setup
# this section is the same irregardless of server or environment
#
#
echo "$(date) downloading current nrpe.cfg, nagios plugins and snmpd.conf"
s3cmd --config /root/.s3cfg get --recursive --force --no-progress s3://$S3_BUCKET/shared/usr/lib/nagios/plugins/ /usr/lib/nagios/plugins/
chmod +x -R /usr/lib/nagios/plugins/
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/shared/etc/nagios/nrpe.cfg /etc/nagios/nrpe.cfg
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/shared/etc/snmp/snmpd.conf /etc/snmp/snmpd.conf

echo "$(date) downloading current common scripts and making executable"
s3cmd --config /root/.s3cfg get  --no-progress --recursive --force s3://$S3_BUCKET/shared/usr/local/ /usr/local/
chmod -R +x /usr/local/sbin/*.sh
chmod -R +x /usr/local/bin/*

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
#
# downloading various /root scripts and other files 
#
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/home/ /home/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/root/ /root/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/$ENVIRONMENT/root/ /root/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/shared/root/ /root/
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/root/ /root/
#
chmod +x /root/*.sh
#
#
#
echo "$(date) downloading create-volume-from-snapshot dependencies 64 bit"
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/shared/usr/local/lib/site_ruby/1.8/x86_64-linux/ /usr/local/lib/site_ruby/1.8/x86_64-linux/
#
echo "$(date) Downloading lockrun binary to prevent cron job overruns"
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/shared/usr/local/bin/lockrun /usr/local/bin/lockrun
chmod +x /usr/local/bin/lockrun
#
#
echo "$(date) Installing mysql client"
apt-get -qq -y mysql-client
#
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y -qq install apache2-mpm-worker tomcat6
echo "$(date) Setting up the environment variables file .bashrc_for_ec2"
# the following variables are set above - do not edit here
sed -i "s/SERVER=/SERVER=$SERVER/" /usr/local/etc/env.conf
sed -i "s/ENVIRONMENT=/ENVIRONMENT=$ENVIRONMENT/" /usr/local/etc/env.conf
sed -i "s/export HOSTNAME=/export HOSTNAME=$HOSTNAME/" /usr/local/etc/env.conf
sed -i "s/export S3_BUCKET=/export S3_BUCKET=$S3_BUCKET/" /usr/local/etc/env.conf

# edit away as needed!
# here are the variables that determine how big our RAID is
#sed -i "s/DEVICE_COUNT=/DEVICE_COUNT=4/" /usr/local/etc/env.conf
#sed -i "s/DEVICE_SIZE=/DEVICE_SIZE=50/" /usr/local/etc/env.conf
#sed -i "s/MOUNT=/MOUNT=\/mnt/" /usr/local/etc/env.conf
# if we start using ebs volumes and associated mounts, these are the variable to populate
# the first is for building an ebs volume from a snapshot of a specific ebs volume
#sed -i "s/EC2_CURRENT_VOLUME=/EC2_CURRENT_VOLUME=/" /usr/local/etc/env.conf
# and this is where we specify other more or less static EBS volumes
#sed -i "s/VOL1=/VOL1=/" /usr/local/etc/env.conf
#sed -i "s/VOL2=/VOL2=/" /usr/local/etc/env.conf
#sed -i "s/VOL3=/VOL3=/" /usr/local/etc/env.conf
#sed -i "s/VOL4=/VOL4=/" /usr/local/etc/env.conf
#sed -i "s/VOL5=/VOL5=/" /usr/local/etc/env.conf
#sed -i "s/VOL6=/VOL6=/" /usr/local/etc/env.conf
#sed -i "s/VOL7=/VOL7=/" /usr/local/etc/env.conf
#sed -i "s/VOL8=/VOL8=/" /usr/local/etc/env.conf
#sed -i "s/VOL9=/VOL9=/" /usr/local/etc/env.conf
#sed -i "s/VOL10=/VOL10=/" /usr/local/etc/env.conf
#sed -i "s/VOL11=/VOL11=/" /usr/local/etc/env.conf
#
#
echo "$(date) Making some directories we need for splash site and up to 10TB of EBS volumes"
mkdir -p /etc/apache2/certs/
mkdir -p /opt/data/var/www/htdocs
mkdir -p /opt/data1
mkdir -p /opt/data2
mkdir -p /opt/data3
mkdir -p /opt/data4
mkdir -p /opt/data5
mkdir -p /opt/data6
mkdir -p /opt/data7
mkdir -p /opt/data8
mkdir -p /opt/data9
mkdir -p /opt/data10
#
#echo "confirming ebs attachment and mounting of web root is complete before starting rc.local"
#mount /dev/sdf /opt/data
#	until df | grep "/dev/sdf"; do 
#	echo "attempting to mount ebs volumes"
#	sleep 2; 
#done
#echo "confirming ebs attachment and mounting of alfresco data is complete before starting rc.local"
#mount /dev/sdg /opt/data1
#	until df | grep "/dev/sdg"; do 
#	echo "attempting to mount ebs volumes"
#	sleep 2; 
#done
#echo "confirming ebs attachment crashplan data is complete before starting rc.local" >> $LOGFILE
#mount /dev/sdh /opt/data2
#	until df | grep "/dev/sdh"; do 
#	echo "attempting to mount ebs volume sdh" >> $LOGFILE
#	sleep 2; 
#done
#
mkdir -p /opt/data/var/www/htdocs
#
echo "$(date) downloading current $SERVER scripts"
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/usr/local/sbin/${SERVER}_scripts /usr/local/sbin/
chmod -R +x /usr/local/sbin/*
#
#
echo "$(date) Symlinking web root"
rm -rf /var/www
ln -s /opt/data/var/www /var/www
#
#
#
echo "$(date) Activating EBS Volume management and mounting web root data volume at /opt/data"
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/shared/etc/init.d/aws_ebs_mount /etc/init.d/aws_ebs_mount 
chmod +x /etc/init.d/aws_ebs_mount
update-rc.d aws_ebs_mount defaults 98
service aws_ebs_mount start
#
sleep 30
#
#
echo "$(date) Setting up apache2 configuration"
s3cmd --config /root/.s3cfg get --no-progress --recursive --force s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/opt/data/var/www/ /opt/data/var/www/
chown -R www-data:www-data /opt/data/var/www/htdocs
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/apache2/apache2.conf /etc/apache2/apache2.conf 
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/apache2/mods-available/proxy.conf /etc/apache2/mods-available/proxy.conf
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/apache2/sites-available/default /etc/apache2/sites-available/default 
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/apache2/sites-available/default-ssl /etc/apache2/sites-available/default-ssl
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/apache2/ports.conf /etc/apache2/ports.conf
a2ensite default-ssl
a2enmod ssl
a2enmod proxy
a2enmod proxy_connect
a2enmod proxy_http
a2enmod rewrite
update-rc.d apache2 defaults 20
#
#
echo "$(date) Setting up crashplan server"
s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/default/tomcat6.$INSTANCE_TYPE /etc/default/tomcat6
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/tomcat6/server.xml /etc/tomcat6/server.xml
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/init.d/proserver /etc/init.d/proserver
chmod +x /etc/init.d/proserver
chmod +x /home/ubuntu/CrashPlanPROServer/install.sh
chmod +x /home/ubuntu/CrashPlanPROServer/uninstall.sh
chmod +x /home/ubuntu/CrashPlanPROServer/script.exp
cd /home/ubuntu/CrashPlanPROServer
./script.exp
#
#
echo "$(date) Setting temporary system root password for setup scripts"
echo "root:ROOTPASSWORD"|chpasswd
#
echo "$(date) Commencing the application bootstrapping scripts"
echo "$(date) setting up unique ssl cert"
/usr/local/sbin/sslcertsetup.sh
echo "$(date) Writing hostname and localip to key config files"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/edit-hostname.py
echo "$(date) commencing password setup"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/passwordsetup.py
echo "$(date) passwords setup complete- written to /home/ubuntu/passwords"
#
echo "$(date) Setting up rc.local to insure local IP changes are propagated and processes start cleanly on reboot"
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/rc.local  /etc/rc.local 
chmod +x /etc/rc.local
update-rc.d -f rc.local remove
update-rc.d rc.local defaults 99
#
echo "$(date) updating all packages and kernel and rebooting system"
apt-get update
apt-get -y -qq dist-upgrade
#
echo "$(date) incrementing the public AMI launch count"
s3cmd --config /root/.s3cfg get --recursive --force --no-progress s3://$S3_BUCKET/shared/etc/lynx-cur  /etc/
/usr/local/sbin/${SERVER}_scripts/launchcount.sh
echo "$(date) ending user data script and rebooting to activate latest kernel"
rm -rf /var/lib/cloud/data/scripts/bootstrap.sh
reboot

