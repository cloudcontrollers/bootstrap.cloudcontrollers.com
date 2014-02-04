#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
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
gem install route53

apt-get -y autoremove

echo "$(date) Begining application setup"
echo "$(date) Setting access keys for Cloud Controllers public bucket downloads"
cd /root
wget http://$S3_BUCKET.s3.amazonaws.com/shared/root/.s3cfg

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