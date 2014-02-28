#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../ec2/snapshots')

puts 'About to delete all snapshots on the given volume including the most recent ...'

puts 'Obtaining the list of eligible snapshots ...'
puts %x[ec2-describe-snapshots -o self]
puts 'Please enter one or more volume ids (space-separated) from the list above ...'

volume_ids = gets.chomp.split(" ")
volume_ids.each { |volume_id|
  puts "Deleting snapshots of volume #{volume_id} ..."
  CloudControllers::Ec2::Snapshots.delete_all_of_volume(volume_id)
}
