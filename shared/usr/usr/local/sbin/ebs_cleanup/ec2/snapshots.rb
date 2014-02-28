#!/usr/bin/env ruby

require 'time'
require File.expand_path(File.dirname(__FILE__) + '/snapshot')

=begin
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
=end

module CloudControllers
  module Ec2

    class Snapshots < Array
      SEP = "\t"
      DEBUG = false
      
      def initialize(describe_snapshots, opts = {})
        super( 
          describe_snapshots.strip.split("\n").map { |e| 
            Snapshot.new(e.split(SEP)) 
          }.delete_if { |e| 
            e.nil? or !e.completed?
          }
        )
        @opts = opts
      end
      
      def current_snapshot(volume_id)
        return @latest[volume_id] if @latest and @latest[volume_id]
        @latest ||= {}
        Snapshots.create_by_volume_id(volume_id).each { |e| 
          if @latest[e.volume_id].nil? or e.date > @latest[e.volume_id].date
            @latest[e.volume_id] = e 
          end
        }
        @latest[volume_id]
      end
    
      def delete_snapshots
        each { |snap| 
          if allow_delete?(snap)
            puts "ec2-delete-snapshot #{snap.id}"
            if DEBUG
              puts '(disabled)'
            else
              %x[ec2-delete-snapshot #{snap.id}] 
            end
          else
            puts "Not deleting #{snap}"
          end
        }
      end
     
      def allow_delete?(snap)
        @opts[:delete_all] or (snap.completed? and !is_current_snapshot?(snap))
      end
      
      def is_current_snapshot?(snap)
        (snap == current_snapshot(snap.volume_id))
      end

      def self.create_by_volume_id(volume_id)
        snapshot_rows = %x[ec2-describe-snapshots --filter volume-id=#{volume_id}]
        new( snapshot_rows )
      end
      
      # DOES delete the CURRENT snapshot of specified volume
      #
      def self.delete_all_of_volume(volume_id)
        snapshot_rows = %x[ec2-describe-snapshots --filter volume-id=#{volume_id}]
        new( snapshot_rows, :delete_all => true ).delete_snapshots
      end
      
      # does NOT delete the current snapshot of any volume
      #
      def self.delete_all_available
        snapshot_rows = %x[ec2-describe-snapshots -o self]
        new( snapshot_rows ).delete_snapshots
      end

      # current_snapshot_id used by the EC2 bootstrap to create a new volume from snapshot
      #
      def self.current_snapshot_id(volume_id)
        create_by_volume_id(volume_id).current_snapshot(volume_id).id
      end
      
    end
  end
end
