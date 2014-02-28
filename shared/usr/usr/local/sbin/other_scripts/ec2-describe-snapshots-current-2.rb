#!/usr/bin/env ruby
# File: /usr/local/sbin/ec2-describe-snapshots-current.rb
# Purpose: outputs current snapshot of current_volume
#   used by 
# Install: chmod u+x /usr/local/sbin/ec2-describe-snapshots-current.rb
# Update: change <current_volume> to current volume

require 'cloud_controllers/ec2/snapshots'

puts CloudControllers::Ec2::Snapshots.current_snapshot(ENV['EC2_CURRENT_VOLUME_2'])
