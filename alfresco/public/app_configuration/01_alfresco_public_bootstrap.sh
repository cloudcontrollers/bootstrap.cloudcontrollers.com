#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "$(date) Installing Alfresco dependencies and java jdk 1.7"
yes|add-apt-repository ppa:libreoffice/ppa
yes|add-apt-repository ppa:guilhem-fr/swftools
yes|add-apt-repository ppa:webupd8team/java
apt-get -y -qq update
echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef'  install lynx-cur mdadm subversion apache2-mpm-worker oracle-java7-installer python-software-properties ffmpeg imagemagick swftools ttf-mscorefonts-installer libreoffice libtcnative-1 libpostgresql-java tomcat7 postgresql

echo "$(date) Setting up postgresql"
cd /usr/share/tomcat7/lib
wget http://jdbc.postgresql.org/download/postgresql-9.1-901.jdbc3.jar

echo "$(date) relocating postgresql data to persistent ebs volume"
service postgresql stop
cp -pr /var/lib/postgresql/* /opt/data2/var/lib/postgresql/
chown -R postgres:postgres /opt/data2/var/lib/postgresql/
rm -rf /var/lib/postgresql
ln -s /opt/data2/var/lib/postgresql /var/lib/postgresql

echo "$(date) Setting up alfresco DB in postgres"
echo "CREATE ROLE alfresco LOGIN ENCRYPTED PASSWORD 'alfresco';" | sudo -u postgres psql
su postgres -c "createdb alfresco --owner alfresco"

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

#echo "$(date) Attaching /dev/xvdd for /opt/data1"
#export VOL=VOL1
#export DEVICE=xvdd
#export DEVICE_SIZE=10
#export MOUNT=/opt/data1
#/usr/local/sbin/ebs_create_and_attach.sh

#echo "confirming ebs attachment of /dev/xvdd"
#mount -all
#	until df | grep "/dev/xvdd"; do 
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

echo "$(date) Enabling Alfresco"
#apt-get -qq -y install unzip libpostgresql-java libtcnative-1
#ln -s /usr/share/java/postgresql-connector-java-5.1.10.jar /var/lib/tomcat7/shared/
cd /opt/data2/
s3cmd --config /root/.s3cfg get --force --no-progress s3://bootstrap.cloudcontrollers.com/shared/app_installers/alfresco-community-4-latest.zip /opt/data2/alfresco-community-4-latest.zip
unzip alfresco-community-4-latest.zip
#unzip alfresco-community-5-latest.zip
rm -rf bin licenses README.txt web-server
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
/usr/bin/python2.6 /usr/local/sbin/${SERVER}_scripts/passwordsetup.py
echo "$(date) passwords setup complete- written to /home/ubuntu/passwords"
#
#echo "$(date) Setting up rc.local to insure local IP changes are propagated and processes start cleanly on reboot"
#s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/rc.local  /etc/rc.local 
chmod +x /etc/rc.local
update-rc.d -f rc.local remove
update-rc.d rc.local defaults 99

echo "$(date) updating all packages and kernel and rebooting system"
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' dist-upgrade

echo "$(date) incrementing the public AMI launch count"
s3cmd --config /root/.s3cfg get --recursive --force --no-progress s3://$S3_BUCKET/shared/etc/lynx-cur  /etc/
/usr/local/sbin/${SERVER}_scripts/launchcount.sh

echo "$(date) ending user data script and rebooting to activate latest kernel"
rm -rf /var/lib/cloud/data/scripts/*
rm -rf /usr/local/cc/
reboot
