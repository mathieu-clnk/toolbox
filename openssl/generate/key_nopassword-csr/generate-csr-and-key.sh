#!/bin/bash

USAGE="generate-csr-and-key.sh -c <country_code> -l <city_name> \
-o <organization_name> -n <certificate_name> -s <state_name> [ -a <aliases_comma_seperated_list> ]"

help() {
  echo $USAGE
}

die() {
  echo "ERROR: $1"
  exit 1
}

generate_cfg() {
  cat > openssl.cfg << EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = $COUNTRY_CODE
ST = $STATE_NAME
L = $CITY_NAME
O = $ORG_NAME
CN = $CERT_NAME
EOF
if [! -z $CERT_ALIASES]
then
  cat >> openssl.cfg << EOF
[alternate_names]
EOF
  index=1
  for url in $(echo $CERT_ALIASES | tr ',' ' ')
  do
    cat >> openssl.cfg << EOF
DNS.${index} = url
EOF
    index=$(expr $index + 1)
  done
fi
}

generate_csr_key() {
  openssl genrsa -out ${CERT_NAME}.key 2048
  openssl req -new -config openssl.cfg -key ${CERT_NAME}.key -out ${CERT_NAME}.csr
  openssl req -text -noout -verify -in ${CERT_NAME}.csr
}

while getopts "c:hl:o:n:s:a:" opt; do
  case $opt in
     c)
       COUNTRY_CODE=$OPTARG
       ;;
     h)
       help
       ;;
     l)
       CITY_NAME=$OPTARG
       ;;
     n)
       CERT_NAME=$OPTARG
       ;;
     o)
       ORG_NAME=$OPTARG
       ;;
     s)
       STATE_NAME=$OPTARG
       ;;
     a)
       CERT_ALIASES=$OPTARG
       ;;
  esac
done

if [ -z $COUNTRY_CODE ] || [ -z $CITY_NAME ] || [ -z $CERT_NAME ] || [ -z $ORG_NAME ] || [ -z $STATE_NAME ]
then
  help
  die "Bad usage. One or multiple mandatories option are missing."
fi
if [! -z $CERT_ALIASES ] && [[ $(echo $CERT_ALIASES | tr ',' '\n'|wc -l) -gt 40 ]]
then
  die "You cannot create more than 40 aliases."
fi
generate_cfg
generate_csr_key