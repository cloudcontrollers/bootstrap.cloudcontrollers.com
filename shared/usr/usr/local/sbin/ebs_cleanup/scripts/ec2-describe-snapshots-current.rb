#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../ec2/snapshots')

puts CloudControllers::Ec2::Snapshots.current_snapshot_id(ENV['EC2_CURRENT_VOLUME'])
