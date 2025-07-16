#!/bin/bash

# Get all regions
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

echo "Listing Customer Gateways in all regions..."

for region in $regions; do
  echo "Region: $region"
  aws ec2 describe-customer-gateways \
    --region "$region" \
    --query "CustomerGateways[*].{Id:CustomerGatewayId,BgpAsn:BgpAsn,IpAddress:IpAddress,Type:Type,State:State}" \
    --output table
done

