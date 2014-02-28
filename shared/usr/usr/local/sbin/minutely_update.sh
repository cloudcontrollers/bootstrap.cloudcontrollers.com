#!/bin/bash

# import root user environment variables
. /usr/local/etc/env.conf

LOGFILE="/var/log/minutely.log"
echo "$(date) Starting minutely script"  >> $LOGFILE

echo "$(date) Downloading current deployment update script"  >> $LOGFILE
s3cmd --config /root/.s3cfg get --force --no-progress s3://${S3_BUCKET}/${SERVER}/update_bucket/deployment_update.sh /usr/local/sbin/deployment_update.sh

echo "$(date) Enabling deployment update script"  >> $LOGFILE
chmod +x /usr/local/sbin/deployment_update.sh

echo "$(date) Running deployment update script"  >> $LOGFILE
/usr/local/sbin/deployment_update.sh

echo "$(date) Exiting and unlocking minutely update script"  >> $LOGFILE
exit
