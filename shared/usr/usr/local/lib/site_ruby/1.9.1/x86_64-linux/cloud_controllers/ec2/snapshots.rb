#!/usr/bin/env ruby

=begin
  Name: CloudControllers::Ec2::Snapshots
  Description: Assist the firstrun-create-ebs-from-snapshot-and-mount.sh
  Author:  Michael Mell
  Date: October 17, 2010
  License: MIT
  Modified by : Leo Shin
  Date: June 4, 2012
=end

require 'time'

ENV['PATH'] = "#{ENV['PATH']}"

module CloudControllers
  module Ec2
  
    # Snapshots
    #   parse the ec2-describe-snapshots output
    #
    class Snapshots
      SEP = "\t"
      
      def initialize(describe_snapshots)
        @snapshots = describe_snapshots.split("\n").map { |e|
          row = e.split(SEP)
          row[4] = Time.parse(row[4])
          row
        }.reject { |e|
          e[3] != 'completed' or e[5] != '100%'
        }.sort { |a, b|
          b[4] <=> a[4] # descending date
        }
      end
      
      # find the most recent, complete (100%) snapshot in the describe_snapshots
      def current_snapshot
        @snapshots[0][1]
      end
    
      def self.get_describe_snapshots(volume_id=nil, description=nil)
        volume_filter = volume_id == nil || volume_id.length == 0 ? '' : "--filter " << "\"volume-id=" << volume_id << "\""
        other_filter = description == nil || description.length == 0 ? '' : "--filter " << "\"description=" << description << "\""
        snapshots = `ec2-describe-snapshots #{volume_filter} --filter "progress=100%" --filter "status=completed" #{other_filter}`
        raise RuntimeError, "ec2-describe-snapshots returned: #{describe_snapshots.inspect}" unless snapshots
        snapshots
      end
      
      def self.current_snapshot(volume_id=nil, description=nil)
        o = CloudControllers::Ec2::Snapshots.new( get_describe_snapshots(volume_id, description) )
        o.current_snapshot
      end
      
    end
  end
end
