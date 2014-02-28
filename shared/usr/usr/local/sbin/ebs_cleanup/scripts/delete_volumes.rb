#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../ec2/volumes')

CloudControllers::Ec2::Volumes.delete_all_available
