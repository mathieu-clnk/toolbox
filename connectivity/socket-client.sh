#!/bin/bash
SITE_NAME=$1
PORT=$2
exec 3<> /dev/tcp/${SITE_NAME}/${PORT}
echo -e "GET / HTTP/1.1\nHost: ${SITE_NAME}\n\n" >&3
cat <&3