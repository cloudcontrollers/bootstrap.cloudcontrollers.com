#!/bin/bash

service mysql start

# MySQL Upstart job baby-sitter script
	until /bin/netstat -ln | /bin/grep ":3306 "; do 
		echo "MySQL is not available- sleeping 5 seconds"
		sleep 5; 
	done
echo "MySQL is now responding - launching password setup"
