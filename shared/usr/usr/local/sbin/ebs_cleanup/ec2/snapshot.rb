#!/usr/bin/env ruby

require 'time'

module CloudControllers
  module Ec2

    class Snapshot
      Fields = [ :type, :id, :volume_id, :status, :date, :percent, :undef7, :undef8, :description
      ]
            
      def initialize(data)
        @data = Hash[ Fields.zip(data) ]
        return nil unless @data[:type] == 'SNAPSHOT'
        @data[:date] = Time.parse(@data[:date])
      end
      
      def id
        @data[:id]
      end
      
      def volume_id
        @data[:volume_id]
      end
      
      def status
        @data[:status]
      end
      
      def date
        @data[:date]
      end
      
      def percent
        @data[:percent]
      end
      
      def description
        @data[:description]
      end
      
      def completed?
        (status == 'completed' and percent == '100%')
      end
      
      def to_s
        id
      end
      
      def ==(other)
        id == other.id
      end
      
    end
  end
end
