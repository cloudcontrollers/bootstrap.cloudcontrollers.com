#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Making some directories we need"
mkdir -p /opt/data/var/www/htdocs
mkdir -p /opt/data1/alf_data
mkdir -p /opt/data2/var/lib/postgresql

echo "$(date) Alfresco bootstrap: Installing Alfresco dependencies: java jdk 1.7"
yes|add-apt-repository ppa:libreoffice/ppa
yes|add-apt-repository ppa:guilhem-fr/swftools
yes|add-apt-repository ppa:webupd8team/java
apt-get -y -qq update
echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' install oracle-java7-installer 

echo "$(date) Alfresco bootstrap: Installing Alfresco dependencies: tomcat7, postgres, etc"
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' install libtcnative-1 libpostgresql-jdbc-java tomcat7 postgresql lynx-cur mdadm subversion apache2-mpm-worker python-software-properties ffmpeg imagemagick swftools ttf-mscorefonts-installer libjodconverter-java libreoffice 

echo "$(date) Alfresco bootstrap: Setting up postgresql"
cd /usr/share/tomcat7/lib
wget http://jdbc.postgresql.org/download/postgresql-9.1-901.jdbc3.jar

echo "$(date) Alfresco bootstrap: relocating postgresql data to persistent ebs volume"
service postgresql stop
cp -pr /var/lib/postgresql/* /opt/data2/var/lib/postgresql/
chown -R postgres:postgres /opt/data2/var/lib/postgresql/
rm -rf /var/lib/postgresql
ln -s /opt/data2/var/lib/postgresql /var/lib/postgresql
mv /home/ubuntu/postgresql/9.1/main/pg_hba.conf /etc/postgresql/9.1/main/pg_hba.conf
service postgresql start

echo "$(date) Alfresco bootstrap: Setting up alfresco DB in postgres"
echo "CREATE ROLE alfresco LOGIN ENCRYPTED PASSWORD 'alfresco';" | sudo -u postgres psql
su postgres -c "createdb alfresco --owner alfresco"

echo "$(date) Alfresco bootstrap: Setting up the environment variables file usr/local/etc/env.conf"
sed -i "s/SERVER=/SERVER=$SERVER/" /usr/local/etc/env.conf
sed -i "s/ENVIRONMENT=/ENVIRONMENT=$ENVIRONMENT/" /usr/local/etc/env.conf
sed -i "s/export HOSTNAME=/export HOSTNAME=$HOSTNAME/" /usr/local/etc/env.conf
sed -i "s/java-6-openjdk-amd64/java-7-oracle/" /usr/local/etc/env.conf

echo "$(date) Alfresco bootstrap: Setting oracle-java7 as system default"
apt-get install oracle-java7-set-default

echo "$(date) Alfresco bootstrap: Making some directories we need on the system boot volume"
mkdir -p /etc/apache2/certs/
mkdir -p /var/lib/tomcat7/shared/classes/alfresco/extension
mkdir -p /var/lib/tomcat7/shared/classes/alfresco/messages
mkdir -p /var/lib/tomcat7/shared/classes/alfresco/web-extension

#echo "$(date) Alfresco bootstrap: Attaching /dev/xvdd for /opt/data1"
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

#echo "$(date) Alfresco bootstrap: Attaching /dev/xvde for /opt/data2"
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

echo "$(date) Alfresco bootstrap: Symlinking web root"
rm -rf /var/www
ln -s /opt/data/var/www /var/www

echo "$(date) Alfresco bootstrap: Setting up apache2 configuration"
chown -R www-data:www-data /opt/data/var/www/htdocs
a2ensite default-ssl
a2enmod ssl
a2enmod proxy
a2enmod proxy_ajp
a2enmod rewrite
update-rc.d apache2 defaults 20

echo "$(date) Alfresco bootstrap: Enabling Alfresco"
cd /opt/data2/
s3cmd --config /root/.s3cfg get --force --no-progress s3://bootstrap.cloudcontrollers.com/shared/app_installers/alfresco-community-4.2.e.zip /opt/data2/alfresco-community-4.2.e.zip
unzip alfresco-community-4.2.e.zip
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/var/lib/tomcat7/shared/classes/alfresco-global.properties  /var/lib/tomcat7/shared/classes/alfresco-global.properties
ln -s /opt/data2/web-server/webapps/alfresco.war  /var/lib/tomcat7/webapps/alfresco.war
ln -s /opt/data2/web-server/webapps/share.war  /var/lib/tomcat7/webapps/share.war
chown -R tomcat7:tomcat7 /opt/data2/web-server /var/lib/tomcat7 /opt/data1/alf_data
service tomcat7 restart

echo "$(date) Alfresco bootstrap: Setting default system root and postgresql root password used by password setup scripts"
echo "root:ROOTPASSWORD"|chpasswd
#
echo "$(date) Alfresco bootstrap: Commencing the application bootstrapping scripts"
echo "$(date) Alfresco bootstrap: setting up unique ssl cert"
/usr/local/sbin/sslcertsetup.sh
echo "$(date) Alfresco bootstrap: Writing hostname and localip to key config files"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/edit-hostname.py
echo "$(date) Alfresco bootstrap: Writing new IP to key config files"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/edit-local-ip.py
echo "$(date) Alfresco bootstrap: commencing password setup"
/usr/bin/python /usr/local/sbin/${SERVER}_scripts/passwordsetup.py
echo "$(date) Alfresco bootstrap: passwords setup complete- written to /home/ubuntu/passwords"
#
echo "$(date) Alfresco bootstrap: Setting up rc.local to insure local IP changes are propagated and processes start cleanly on reboot"
s3cmd --config /root/.s3cfg get --force --no-progress s3://$S3_BUCKET/$SERVER/$ENVIRONMENT/etc/rc.local  /etc/rc.local 
chmod +x /etc/rc.local
update-rc.d -f rc.local remove
update-rc.d rc.local defaults 99

echo "$(date) Alfresco bootstrap: updating all packages and kernel and rebooting system"
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -o Dpkg::Options::='--force-confdef' dist-upgrade

echo "$(date) Alfresco bootstrap: enabling keystore and proper imagemagick transformations"
cp -pr /var/lib/tomcat7/webapps/alfresco/WEB-INF/classes/alfresco/keystore /opt/data1/alf_data/
mv /home/ubuntu/alfresco/imagemagick-transform.properties /var/lib/tomcat7/webapps/alfresco/WEB-INF/classes/alfresco/subsystems/thirdparty/default/imagemagick-transform.properties
chown -R tomcat7:tomcat7 /opt/data1/alf_data

echo "$(date) Alfresco bootstrap: incrementing the public AMI launch count"
s3cmd --config /root/.s3cfg get --recursive --force --no-progress s3://$S3_BUCKET/shared/etc/lynx-cur  /etc/
/usr/local/sbin/${SERVER}_scripts/launchcount.sh

echo "$(date) Alfresco bootstrap: ending user data script and rebooting to activate latest kernel"
rm -rf /var/lib/cloud/data/scripts/*
rm -rf /usr/local/cc/
reboot