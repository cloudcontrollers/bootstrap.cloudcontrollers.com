#!/bin/bash
#
. /root/.bashrc
. /usr/local/aws-tools/aws-tools-env.sh
#
exec > >(tee -a /var/log/ebs_create_and_attach.log)
echo "$(date) starting ebs create and attachment script"
#
export LOCAL_IPV4=$(curl -s --noproxy 169.254.169.254  http://169.254.169.254/latest/meta-data/local-ipv4)

# configurable parameters
# exported in script which call this one or manual export statements run in the shell
dev=$DEVICE
instanceid=$INSTANCE_ID
AZ=$AVAILABILITY_ZONE
size=$DEVICE_SIZE
mountpoint=$MOUNT
volume=$VOL
#
# make the volume and attach to the instance
#
export VOLUMEID=$(ec2-create-volume -z $AZ --size $size | cut -f2)
echo "$(date) $i: created  $VOLUMEID"
device=/dev/$dev
ec2-attach-volume -d $device -i $instanceid $VOLUMEID
echo "$(date) attaching $VOLUMEID to $device"
#
# Need to be sure device has attached so we pause 60 seconds. Totally lame.
# Need to chnage this to querying attachment status of the device via API
# or attempting format in a loop until done

echo "$(date) Sleeping 60 seconds"

sleep 60

echo "$(date) Formatting volume xfs"
mkfs.xfs /dev/$dev
#
echo "$(date) Making volume mountpoint"
mkdir -p $mountpoint

# we should not have to mount if the script calling this one handles mounting
#echo "$(date) Mounting volume"
#mount -t xfs -o noatime /dev/$DEVICE $mountpoint
#mount /dev/$DEVICE $mountpoint

echo "$(date) Adding device to fstab"
FSTAB=/etc/fstab
cat << EOF >> $FSTAB
/dev/$DEVICE /mnt/log xfs noatime,nobootwait 0 0

EOF

echo "$(date) Add the volume ID to env.conf, format volume and mount it"
sed -i "s/$volume=/$volume=$VOLUMEID/" /usr/local/etc/env.conf

echo "$(date) Finished"

