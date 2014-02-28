#!/bin/bash
exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "$(date) Bootstrap script3: Setting up AWS CLI tools"
apt-get update
apt-get -y -qq install git-core
cd /usr/local/
git clone http://github.com/floodfx/aws-tools.git
chmod +x /usr/local/aws-tools/aws-tools-env.sh
# when we automate git clone to s3 bucket, we will do this instead:
#s3cmd --config /root/.s3cfg get  --force s3://$S3_BUCKET/shared/usr/local/aws.tgz /usr/local/
#cd /usr/local/ 
#tar -xzf aws.tgz
echo "$(date) Bootstrap script3: Remember to edit /root/.ec2/aws-access-keys.txt if/when you configure this server to access a private S3 bucket"
