#!/bin/bash
URL=$1
PORT=$2
SERVERNAME=$3
check(){
	echo $(echo QUIT |openssl s_client -showcerts -connect ${URL}:${PORT} -servername $SERVERNAME -debug
}

check