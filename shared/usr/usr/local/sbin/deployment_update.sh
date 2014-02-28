#!/bin/bash
#
# import root user environment variables
. /usr/local/etc/env.conf
#
LOGFILE="/var/log/deployment_update.log"
echo "$(date) starting deployment update script"  >> $LOGFILE
echo "$(date) nothing to do- exiting" >> $LOGFILE
exit