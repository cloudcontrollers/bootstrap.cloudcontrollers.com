#!/bin/bash
#
#ping java-less analytics page at website
#so we know how many of these AMIs have been launched
#
lynx -dump -term=xterm http://www.cloudcontrollers.com/analytics/alfresco-devpay-ami-first-boots/ >/tmp/tmpsw

echo "thanks for trying this public AMI- please let us now what you think! Cloud Controllers: http://www.cloudcontrollers.com"

