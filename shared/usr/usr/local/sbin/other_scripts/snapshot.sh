#!/bin/bash
#
# DESCRIPTION
#   snapshot the web disk
#
# USAGE 
#   rollout_snapshot.sh "snapshot description"
#

# run as root

MUST_RUN_AS_ROOT=1
ALL_SHELLS_EXIT=2

function snapshot_timestamp {
  date -u --rfc-3339=seconds
}
function write_snapshot_info {
 
  INFO_TEXT="
This file describes the volume just before it is snapshotted.

Snapshot Created
  `snapshot_timestamp`

Snapshot Description
  $1

snapshot_info Format: 
  v1

  " 
  echo $INFO_TEXT > "$2/snapshot_info"  
}

notice "enter $0"

function require_root {
  if [ ${UID} != 0 ]
  then 
    notice "SNAPSHOT: ${0} must be run as root. exiting."
    exit $MUST_RUN_AS_ROOT
  fi

  if [[ `users` != 'root' ]]; then
    # FIXME: actually we just want to be sure www-data is off the system 
    #   since its home is in the volume we're going to unmount.
    echo "SNAPSHOT: PROCESS HALTED. All shells except this one must exit. Found:"
    echo `users`
    echo
    exit $ALL_SHELLS_EXIT
  fi
}

# snapshot_volume volume_id current_vol interface mountpoint name
#   e.g. snapshot_volume $EC2_CURRENT_VOLUME_2 /dev/sdh xfs /opt/data2 my_app
#
function snapshot_volume {
  
  DESCRIPTION="$4 `snapshot_timestamp`"
  
  write_snapshot_info $DESCRIPTION $3
  
  sync # Force changed blocks to disk, update the super block.

  # http://docs.amazonwebservices.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-CreateSnapshot.html
  #   says we should unmount
  #
  # unmount the one volume that we snapshot
  /usr/local/sbin/mount_ebs_volume.py unmount $1 $3 xfs $4
  wait $!

  /usr/local/ec2-api-tools/bin/ec2-create-snapshot $2 -d $DESCRIPTION 
  wait $!

  /usr/local/sbin/mount_ebs_volume.py mount $1 $3 xfs $4 
  wait $!
  
}

require_root
if [ $? != 0 ]
then
  # kill sessions: seems too dangerous to me...
  #   http://www.linuxquestions.org/questions/programming-9/grep-for-the-result-of-a-command-within-the-result-of-another-command-839848/#post4136218
  exit
fi

notice 'stopping apache'
apache2ctl stop

#snapshot_volume $VOL2 $EC2_CURRENT_VOLUME_2 /dev/sdg /opt/data1 application_root
#snapshot_volume $VOL3 $EC2_CURRENT_VOLUME_3 /dev/sdh /opt/data2 application_data


#/usr/local/sbin/mount_ebs_volume.py unmount $VOL2 /dev/sdg xfs /opt/data1
#/usr/local/ec2-api-tools/bin/ec2-create-snapshot $EC2_CURRENT_VOLUME_2 -d "$1"
#/usr/local/sbin/mount_ebs_volume.py mount $VOL2 /dev/sdg xfs /opt/data1 

notice 'starting apache'
apache2ctl start
