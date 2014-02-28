#!/bin/bash
#
. /usr/local/etc/env.conf
#
echo "updating scripts in root user home folder in case checkout scripts have changed"
s3cmd --config /root/.s3cfg get --recursive --force s3://${S3_BUCKET}/$SERVER/shared/usr/local/sbin/ /usr/local/sbin/
s3cmd --config /root/.s3cfg get --recursive --force s3://${S3_BUCKET}/$SERVER/$ENVIRONMENT/usr/local/sbin/ /usr/local/sbin/
chmod +x /usr/local/sbin/*.sh
chmod +x /usr/local/sbin/${SERVER}_scripts/*.sh
exit