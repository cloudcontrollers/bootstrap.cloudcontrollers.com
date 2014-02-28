#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../ec2/snapshots')

puts 'About to delete all *available snapshots* except the most recent snapshot per volume ...'

CloudControllers::Ec2::Snapshots.delete_all_available
