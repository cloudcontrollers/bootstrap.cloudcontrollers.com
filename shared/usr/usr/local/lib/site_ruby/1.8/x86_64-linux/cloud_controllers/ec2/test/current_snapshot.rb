#!/usr/bin/env ruby

require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../current_snapshot')

class CurrentSnapshot < Test::Unit::TestCase
  
  def test_current_snapshot
    describe_snapshots = %Q{SNAPSHOT	snap-15d87e7e	vol-cd2968a6	completed	2010-10-14T02:38:32+0000	100%	308696310818	10	Created by CreateImage(i-9fde74db) for ami-1805555d from vol-cd2968a6
SNAPSHOT	snap-5121853a	vol-812160ea	completed	2010-10-13T04:38:53+0000	100%	308696310818	10	
SNAPSHOT	snap-858f29ee	vol-41296a2a	completed	2010-10-14T05:19:56+0000	100%	308696310818	10	Created by CreateImage(i-492e840d) for ami-c4055581 from vol-41296a2a
SNAPSHOT	snap-CURRENT	vol-41296a2a	completed	2010-10-15T06:01:23+0000	100%	308696310818	10	www-dev-10-14
SNAPSHOT	snap-f1e84e9a	vol-cd2968a6	completed	2010-10-13T23:18:52+0000	100%	308696310818	10	Created by CreateImage(i-9fde74db) for ami-5a05551f from vol-cd2968a6}


  	assert_equal('snap-CURRENT', CloudControllers::Ec2::CurrentSnapshot.new(describe_snapshots).current_snapshot)
  end

end
