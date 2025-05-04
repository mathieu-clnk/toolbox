#!/bin/bash
# This script create an AKS with the workload identity.
name_suffix="$(date +%Y%m%d%H%M%s)"
location="westeurope"
resource_group="rsg-demo-3432"
vnet_name="vnt-demo-3432"
subnet="default"
route_table="rte-demo-3432"
subscription=$(az account show --query "name" --output tsv)
die() {
  echo "ERROR: $1"
  exit 1
}

get_private_dns() {
 echo "Check if private DNS zone exists"
 zone=$(az network private-dns zone show --name aks-demo.privatelink.westeurope.azmk8s.io --resource-group ${resource_group} || echo 0)
 if [ "$(echo $zone|jq -r '.name')" == "aks-demo.privatelink.westeurope.azmk8s.io" ]
  then
    export zone_id=$(echo $zone|jq -r '.id')
    return 0
  fi
  return 1
}

create_private_dns() {
  echo "Creating private DNS zone."
  zone=$(az network private-dns zone create --name aks-demo.privatelink.westeurope.azmk8s.io --resource-group ${resource_group} ) || return 1
  if [ "$(echo $zone|jq -r '.name')" == "aks-demo.privatelink.westeurope.azmk8s.io" ]
  then
    export zone_id=$(echo $zone|jq -r '.id')
    return 0
  fi
  return 1
}

get_cluster_managed_identity() {
  echo "Get AKS managed identity."
  mid=$(az identity show --name mid-aks-demo --resource-group ${resource_group} || echo 0 )
  if [ "$(echo $mid|jq -r '.name')" == "mid-aks-demo" ]
  then
    export aks_mid_principalId=$(echo $mid|jq -r '.principalId')
    export aks_mid_id=$(echo $mid|jq -r '.id')
    return 0
  fi
  return 1
}

create_cluster_managed_identity() {
  echo "Creating AKS managed identity."
  mid=$(az identity create --name mid-aks-demo --resource-group ${resource_group}) || return 1
  if [ "$(echo $mid|jq -r '.name')" == "mid-aks-demo" ]
  then
    export aks_mid_principalId=$(echo $mid|jq -r '.principalId')
    export aks_mid_id=$(echo $mid|jq -r '.id')
    return 0
  fi
  return 1
}

create_role_assignment() {
  echo "Create Role assignment for the managed identity."
  sleep 30
  a1_id=$(az role assignment list --role "Private DNS Zone Contributor" --scope ${zone_id} --assignee ${aks_mid_principalId} --query "[0].principalId" --output tsv)
  if [ "${a1_id}" != "${aks_mid_principalId}" ]
  then
    a1=$(az role assignment create --role "Private DNS Zone Contributor" --scope ${zone_id} --assignee-object-id ${aks_mid_principalId} ) || return 1
  fi
  route_table_id=$(az network route-table show --name ${route_table} --resource-group ${resource_group}  --query "id" --output tsv)
  a2_id=$(az role assignment list --role "Network Contributor" --scope ${route_table_id} --assignee ${aks_mid_principalId} --query "[0].principalId" --output tsv)
  if [ "${a2_id}" != "${aks_mid_principalId}" ]
  then
    a2=$(az role assignment create --role "Network Contributor" --scope ${route_table_id} --assignee-object-id ${aks_mid_principalId}) || return 1
  fi
  vnet_id=$(az network vnet show --name ${vnet_name} --resource-group ${resource_group}  --query "id" --output tsv)
  a3_id=$(az role assignment list --role "Network Contributor" --scope ${vnet_id} --assignee ${aks_mid_principalId} --query "[0].principalId" --output tsv)
  if [ "${a2_id}" != "${aks_mid_principalId}" ]
  then
    a3=$(az role assignment create --role "Network Contributor" --scope ${vnet_id} --assignee-object-id ${aks_mid_principalId} ) || return 1
  fi
}

create_aks() {
  echo "Create the AKS aks-demo-${name_suffix}"
  subnet_id=$(az network vnet subnet show --vnet-name ${vnet_name} --name ${subnet} --resource-group ${resource_group}  --query "id" --output tsv )
  aks=$(az aks create --name aks-demo-${name_suffix} --resource-group ${resource_group} --enable-workload-identity --enable-oidc-issuer \
                      --enable-private-cluster --enable-managed-identity --enable-blob-driver --enable-azure-rbac --disable-local-accounts \
                      --assign-identity ${aks_mid_id} --outbound "userDefinedRouting" --pod-cidr "172.28.0.0/16" --node-count 1\
                      --private-dns-zone ${zone_id} --service-cidr "172.21.0.0/16" --dns-service-ip "172.21.0.10" --tier standard --vnet-subnet-id ${subnet_id} --generate-ssh-keys --enable-aad --yes)
  if [ "$(echo $aks|jq -r '.name')" == "aks-demo-${name_suffix}" ]
  then
    return 0
  fi
  return 1
}
get_private_dns
if [[ $? -gt 0 ]]
then
  create_private_dns || die "Cannot create the private dns zone."
fi
get_cluster_managed_identity
if [[ $? -gt 0 ]]
then
  create_cluster_managed_identity || die "Cannot create the AKS managed identity."
fi
create_role_assignment || die "Cannot create the role assignment for the AKS."
create_aks || die "Cannot create the AKS."
