#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/snapshots')

module CloudControllers
  module Ec2
  
    class Volume
      Fields = [ :type, :id, :undef2, :snap_id, :region, :state, :date, :undef7, :undef8, :undef9, 
        :undef10, :undef11, :undef12, :tag, :tag_value, :undef15, :name, :name_value
      ]
      
      def initialize(data)
        @data = Hash[ Fields.zip(data) ]
        return nil unless @data[:type] == 'VOLUME'
        @data[:date] = Time.parse(@data[:date])
      end
      
      def id
        @data[:id]
      end
      
      def snap_id
        @data[:snap_id]
      end
      
      def region
        @data[:region]
      end
      
      def date
        @data[:date]
      end
      
      def state
        @data[:state]
      end
      
      def tag
        @data[:tag]
      end
      
      def tag_value
        @data[:tag_value]
      end

      def name
        @data[:name]
      end
      
      def name_value
        @data[:name_value]
      end

      def in_use?
        (state == 'in-use')
      end
      
      def is_tagged?
        (tag == 'TAG' and name == 'Name')
      end
      
      def to_s
        id
      end
      
      def snapshots
        CloudControllers::Ec2::Snapshots.snapshots_of_volume(id)
      end
      
    end
  end
end
