#!/bin/bash
URL=$1
PORT=$2
check(){
	echo $(echo QUIT |openssl s_client -showcerts -connect ${URL}:${PORT} -debug
}

check