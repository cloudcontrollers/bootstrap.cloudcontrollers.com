#!/bin/bash
#################################notes#################################
# cloudcontrollers-sslcertsetup.sh r1                                 #
# this script run at first boot and generates random numbers, a unique#
#         server.csr, server.key and server.crt files for use by the  #
#         apache2 web server. This self-signed cert will generate     #
#         browser warnings, but will be secure. System administrators #
#		  should consider purchasing a SSL certificate through Cloud  #
# 		  Controllers or another SSL certificate reseller if the web  #
#         application is meant to be accessed by the general public.  #
#                      												  #
# Created for Cloud Controllers by Razvan Gavril					  #
#																	  #
# Have a better idea? Share it at 									  #
# http://www.cloudcontrollers.com/community/wiki					  #
#######################################################################
TEMP_DIR="/tmp/out.$$"
DEST_DIR='/etc/apache2/certs'
KEY_NAME='server'

mkdir -p "$TEMP_DIR"
mkdir -p "$DEST_DIR"

## Create a temporary openssl config file 
echo "
[ req ]
default_bits = 2048
default_keyfile = key.pem
default_md = md5
string_mask = nombstr
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
0.organizationName = Organization Name (company)
organizationalUnitName = Organizational Unit Name (department, division)
emailAddress = Email Address
emailAddress_max = 40
localityName = Locality Name (city, district)
stateOrProvinceName = State or Province Name (full name)
countryName = Country Name (2 letter code)
countryName_min = 2
countryName_max = 2
commonName = Common Name (hostname, IP, or your name)
commonName_max = 64

#-------------------Edit this section------------------------------
countryName_default            = US
stateOrProvinceName_default    = CA
localityName_default           = San Francisco
0.organizationName_default     = Cloud Controllers
organizationalUnitName_default = Cloud Server Support
commonName_default             = self-signed.cloudcontrollers.com
emailAddress_default           = support@cloudcontrollers.com
" > "$TEMP_DIR/$KEY_NAME".conf


## Generate the certificates
openssl genrsa -out "$TEMP_DIR/$KEY_NAME".key 2048
openssl req -new -nodes -key "$TEMP_DIR/$KEY_NAME".key -out "$TEMP_DIR/$KEY_NAME".csr -config "$TEMP_DIR/$KEY_NAME".conf -batch
openssl x509 -req -days 3650 -in "$TEMP_DIR/$KEY_NAME".csr -signkey "$TEMP_DIR/$KEY_NAME".key  -out "$TEMP_DIR/$KEY_NAME".crt
chmod 0640 "$TEMP_DIR/$KEY_NAME".key

## Move keys and certs to the destination folder
mv "$TEMP_DIR/$KEY_NAME".{key,csr,crt} "$DEST_DIR/"
rm -rf "$TEMP_DIR"

