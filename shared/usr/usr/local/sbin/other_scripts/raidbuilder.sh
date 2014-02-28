#!/bin/bash
#
. /root/.bashrc
#
exec > >(tee /var/log/raid-builder.log|logger -t raid-builder -s 2>/dev/console) 2>&1
echo "$(date) starting raidbuilder script"
#
# configurable parameters
#
instanceid=$INSTANCE_ID
AZ=$AVAILABILITY_ZONE
volumes=$DEVICE_COUNT
size=$DEVICE_SIZE
mountpoint=$MOUNT
#
# make the volumes and attach to the instance
# DOES THIS NEED TO CHANGE NOW THAT UBUNTU PRECISE USES XVD... INSTEAD OF SD... for device path?
#
devices=$(perl -e 'for$i("h".."k"){for$j("",1..15){print"/dev/sd$i$j\n"}}'|
           head -$volumes)
devicearray=($devices)
volumeids=
i=1
while [ $i -le $volumes ]; do
  volumeid=$(ec2-create-volume -z $AZ --size $size | cut -f2)
  echo "$i: created  $volumeid"
  device=${devicearray[$(($i-1))]}
  ec2-attach-volume -d $device -i $instanceid $volumeid
  volumeids="$volumeids $volumeid"
  let i=i+1
done
echo "volumeids='$volumeids'"
#
# Need to be sure last device has attached so we pause 60 seconds. Totally lame.
#
sleep 60
# make the raid array, format and mount it
#
devices=$(perl -e 'for$i("h".."k"){for$j("",1..15){print"/dev/sd$i$j\n"}}'|
           head -$volumes)
yes |  mdadm --create /dev/md0 --level 0 --metadata=1.1 --raid-devices $volumes $devices
echo DEVICE $devices | tee /etc/mdadm/mdadm.conf
mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf
mkfs.xfs /dev/md0
echo "/dev/md0 $mountpoint xfs noatime,nobootwait 0 0" | sudo tee -a /etc/fstab
mkdir -p $mountpoint
echo "set the block device read ahead have to 64k"
# http://coreyhulen.org/2010/07/28/raid-level-0-setup-on-amazon-ec2-ebs-drives/
blockdev --setra 65536 /dev/md0
echo "updating ramdisk"
/usr/sbin/update-initramfs -k all -u
exit 0

