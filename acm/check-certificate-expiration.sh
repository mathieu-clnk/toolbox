#!/bin/bash
ARN=$1
aws acm get-certificate --certificate-arn $ARN| jq -r ".Certificate" | openssl x509 -noout -enddate|awk -F"notAfter=" '{ print $2 }'
