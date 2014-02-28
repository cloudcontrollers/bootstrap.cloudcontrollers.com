#!/bin/bash
. /usr/local/aws-tools/aws-tools-env.sh
#
EBS_DEVICE='/dev/sdp'
INSTANCE_ID='ENTER_INSTANCE_ID_HERE'
AKI=${2:-'ENTER_KERNEL_ID'}
ARI=${3:-''}
ARCH=${4:-'ENTER_INSTANCE_i386_OR_x86_64_HERE'}
SIZE=${5:-10}
AZ=${6:-'us-east-1d'}
NAME=${7:-'name'}
DESCRIPTION=${8:-'description'}
IMAGE_DIR=${9:-'/mnt/tmp'}
EBS_MOUNT_POINT=${10:-'/mnt/ebs'}


VOL_ID=`ec2-create-volume --size $SIZE -z $AZ |cut -f2|grep vol`
echo $VOL_ID
# sample output => VOLUME  vol-0500xxx  10    us-east-1d  creating  2009-12-05T08:07:51+0000

ec2-attach-volume $VOL_ID -i $INSTANCE_ID -d $EBS_DEVICE
# sample output => ATTACHMENT	vol-0500fxxx	i-c72f6aaf	/dev/sdh	attaching	2009-12-05T08:14:17+0000

sleep 10

# in case directories are left over from previous bundle operations
rm -rf /mnt/tmp /mnt/ebs

mkdir -p $EBS_MOUNT_POINT
mkfs.ext3 ${EBS_DEVICE}
mount  ${EBS_DEVICE} $EBS_MOUNT_POINT

# make a local working copy
mkdir /mnt/tmp

# add excludes as needed- especially ebs volume mount directories
rsync --stats -av --exclude /root/.bash_history --exclude /home/*/.bash_history --exclude /etc/ssh/ssh_host_* --exclude /etc/ssh/moduli --exclude /etc/udev/rules.d/*persistent-net.rules --exclude /var/lib/ec2/* --exclude=/mnt/* --exclude=/proc/* --exclude=/tmp/* / $IMAGE_DIR

# ensure that ami init scripts will be run
chmod u+x $IMAGE_DIR/etc/init.d/ec2-init-user-data

# clear out log files
cd $IMAGE_DIR/var/log
for i in `ls ./**/*`; do
  echo $i && echo -n> $i
done

cd $IMAGE_DIR
tar -cSf - -C ./ . | tar xvf - -C $EBS_MOUNT_POINT
# NOTE, You could rsync / directly to EBS_MOUNT_POINT, but this tar trickery saves some space in the snapshot

umount $EBS_MOUNT_POINT

ec2-detach-volume $VOL_ID
# sample output => ATTACHMENT  vol-0500fb6c  i-c72f 6aaf  /dev/sdh  detaching 2009-12-05T08:14:17+0000

SNAP=`ec2-create-snapshot $VOL_ID|cut -f2|grep snap`
echo $SNAP
# sample output => SNAPSHOT  snap-415b3xxx vol-0500xxx  pending 2009-12-05T09:04:27+0000    424024621003  10  Ubuntu 9.10 base 32bit server image

sleep 10

ec2-delete-volume $VOL_ID

echo "once you have verified that the snapshot has completed via the AWS console, run the following command to register your new server application Amazon Machine Image (AMI):"
echo ""
echo "ec2-register --snapshot $SNAP --kernel $AKI --description="$DESCRIPTION" --name="$NAME" --architecture $ARCH --root-device-name /dev/sda1"



