#!/usr/bin/env ruby

=begin
  Name: CloudControllers::Ec2::Snapshots
  Description: Assist the firstrun-create-ebs-from-snapshot-and-mount.sh
  Author:  Michael Mell
  Date: October 17, 2010
  License: MIT
=end

require 'time'

ENV['EC2_HOME'] = '/usr/local/ec2-api-tools'
ENV['EC2_PRIVATE_KEY'] = '/root/.ec2/.key'
ENV['EC2_CERT'] = '/root/.ec2/.cert'
ENV['JAVA_HOME'] = '/usr/lib/jvm/java-6-openjdk'
#Uncomment the next line for an AMI for the US East region
ENV['EC2_URL'] = 'https://ec2.amazonaws.com'
#Uncomment the next line for an AMI for the US West region
#ENV['EC2_URL'] = 'https://ec2.us-west-1.amazonaws.com'
#Uncomment the next line for an AMI for the EU region
#ENV['EC2_URL'] = 'https://eu-west-1.ec2.amazonaws.com'
#Uncomment the next line for an AMI for the AP-Southeast region
#ENV['EC2_URL'] = 'https://ec2.ap-southeast-1.amazonaws.com'

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
    
      def self.get_describe_snapshots(volume_id)
        snapshots = `/usr/local/ec2-api-tools/bin/ec2-describe-snapshots --filter volume-id=#{volume_id}`
        raise RuntimeError, "ec2-describe-snapshots returned: #{describe_snapshots.inspect}" unless snapshots
        snapshots
      end
      
      def self.current_snapshot(volume_id)
        o = CloudControllers::Ec2::Snapshots.new( get_describe_snapshots(volume_id) )
        o.current_snapshot
      end
      
    end
  end
end
