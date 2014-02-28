#! /bin/bash
#
# Provides:          firstrun-create-ebs-from-snapshot-and-mount
# Required-Start:    $networking 
# Required-Stop: 
# Default-Start:     2 3 4 5 
# Default-Stop:
# Create a new EBS volume from a given snapshot ID
# and attach the newly-created volume
# original script by Shlomo Swidler
# http://shlomoswidler.com/
#
# edited by Mike Mell and Jack Murgia at Cloud Controllers to
# search for the most recent snapshot for a given volume,
# registered as an environment variable in .bashrc_for_ec2
# and parsed by ec2-describe-snapshots-current.rb
# http://wiki.cloudcontrollers.com
#

#
# Set environment variables for the ec2 scripts
#
. /usr/local/aws-tools/aws-tools-env.sh
#
# Configure these variables accordingly
# The device to attach the EBS drive on
#
EBS_ATTACH_DEVICE="/dev/sdg"

#
# The snapshot ID
# Values provided by the user-data override this setting
#
EBS_VOL_FROM_SNAPSHOT_ID=`/usr/local/sbin/other_scripts/ec2-describe-snapshots-current-2.rb` # e.g. snap-2b74b841

PATH=$PATH:$EC2_HOME/bin
MAX_TRIES=60

prog=$(basename $0)
logger="logger -st $prog"

$logger "Create new EBS volume from snapshot and attach it"

# Wait for the network to come up.
perl -MIO::Socket::INET -e '
 until(new IO::Socket::INET("169.254.169.254:80")){print"Waiting for network...\n";sleep 1}
' | $logger

# Wait for the meta-data to be available.
INSTANCE=`wget -qO- http://169.254.169.254/latest/meta-data/instance-id`
CTR=1
BACKOFF=1
while [ ! -n "$INSTANCE" ]
do
  if [ $CTR -eq 7 ]
  then
    $logger "WARNING: Failed to retrieve instance meta-data after `expr $BACKOFF \* 2` seconds"
    exit 1
  fi
  CTR=`expr $CTR + 1`
  sleep "$BACKOFF"
  BACKOFF=`expr $BACKOFF \* 2`
  INSTANCE=`wget -qO- http://169.254.169.254/latest/meta-data/instance-id`
done
$logger "Got instance id: $INSTANCE"

case "$1" in

start|"")
  $logger "Checking if we need to create a new EBS volume from snapshot"
  if [ ! -e "$EBS_ATTACH_DEVICE" ]
  then
    $logger "Need to create new EBS volume from snapshot: $EBS_ATTACH_DEVICE does not exist"
    AZONE=`wget -qO- http://169.254.169.254/latest/meta-data/placement/availability-zone`
    OVERRIDDEN_SNAP_ID=$(wget -qO- http://169.254.169.254/latest/user-data | awk -F"=" '/^EBS_VOL_FROM_SNAPSHOT_ID=/ {print $2}')
    if [ -n "$OVERRIDDEN_SNAP_ID" ]
    then
      $logger "Using snapshot specified in user-data"
      EBS_VOL_FROM_SNAPSHOT_ID="$OVERRIDDEN_SNAP_ID"
    fi
    $logger "Creating new EBS volume from snapshot $EBS_VOL_FROM_SNAPSHOT_ID in availability zone $AZONE"
    VOL_ID=`ec2-create-volume -z $AZONE -snapshot $EBS_VOL_FROM_SNAPSHOT_ID | awk '{print $2}'`
    if [ ! -n "$VOL_ID" ]
    then
      $logger "WARNING: Failed to create new EBS volume from snapshot $EBS_VOL_FROM_SNAPSHOT_ID"
      exit 1
    fi
    $logger "Created new EBS volume $VOL_ID from snapshot $EBS_VOL_FROM_SNAPSHOT_ID"
    sed -i "s/\$VOL2/$VOL_ID/g" /etc/init.d/aws_ebs_mount

    $logger "Added new EBS volume $VOL_ID from snapshot $EBS_VOL_FROM_SNAPSHOT_ID to /etc/init.d/aws_ebs_mount"
  else
    $logger "Device is already attached to $EBS_ATTACH_DEVICE"
  fi
  ;;

#
# the stop command should not be called in this version of the script
# but its functions are handy to have available if for some reason 'aws_eb_mount stop' is not working,
# perhaps because of problems with python?
#

stop)
  $logger "we don't delete volumes-sorry"
  ;;

*)
  $logger "Usage: $0 [start|stop]"
  exit 1

esac

exit 0