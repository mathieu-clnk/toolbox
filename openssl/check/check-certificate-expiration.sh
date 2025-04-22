#!/bin/bash
URL=$1
PORT=$2
check(){
	RESULT=$(echo $(echo QUIT |openssl s_client -showcerts -connect ${URL}:${PORT}| sed -n -e '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ p'|openssl x509 -noout -enddate)|grep notAfter)
} > /dev/null 2>&1
check
echo $RESULT|awk -F"notAfter=" '{ print $2 }'
