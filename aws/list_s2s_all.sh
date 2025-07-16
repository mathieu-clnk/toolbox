#!/bin/bash

# Get all regions
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

echo "Listing Site-to-Site VPN connections in all regions..."

for region in $regions; do
  echo "Region: $region"
  aws ec2 describe-vpn-connections \
    --region "$region" \
    --query "VpnConnections[*].{VpnId:VpnConnectionId,State:State,Type:Type,VgwId:VpnGatewayId,TgwId:TransitGatewayId}" \
    --output table
done
