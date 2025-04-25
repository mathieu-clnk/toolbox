#!/bin/bash
storage_name="stademo1857"
container_name="container1857"
resource_group="rsg-demo-1857"
manage_identity="midapp1demo"
aks_cluster=""

die() {
  echo "ERROR: $1"
  exit 1
}
get_storage() {
  echo "Get storage."
  storage=$(az storage account show --name ${storage_name} --resource-group ${resource_group} || echo 0)
  if [ "$(echo $storage|jq -r '.name' 2>/dev/null)" == "$storage_name" ]
  then
    export storage_id=$(echo $storage|jq -r '.id')
    return 0
  fi
  return 1
}

get_container() {
  echo "Get container."
  container=$(az storage container show --name ${container_name} --account-name ${storage_name} --auth-mode login --timeout 5|| echo 0)
  if [ "$(echo $container|jq -r '.name')" == "$container_name" ]
  then
    return 0
  fi
  return 1
}

create_storage() {
  echo "Create storage account"
  storage=$(az storage account create --name ${storage_name} --resource-group ${resource_group})
  if [ "$(echo $storage|jq -r '.name')" == "$storage_name" ]
  then
    export storage_id=$(echo $storage|jq -r '.id')
    return 0
  fi
  return 1
}

create_container() {
  echo "Create container."
  container=$(az storage container create --name ${container_name} --account-name ${storage_name} --auth-mode login --timeout 5|| echo 0)
  if [ "$(echo $container|jq -r '.name' 2>/dev/null)" == "$container_name" ]
  then
    return 0
  fi
  return 1
}

get_aks_oidc() {
  echo "Get the AKS of OIDC."
  aks=$(az aks show --name ${aks_cluster} --resource-group ${resource_group} || echo 0)
  if [ "$(echo $aks|jq -r '.name' 2>/dev/null)" == "$aks_cluster" ]
  then
    export oidc_issuer=$(echo $aks|jq -r '.oidcIssuerProfile.issuerUrl')
    return 0
  fi
  return 1
}

get_identity() {
  echo "Get workload get_identity."
  identity=$(az identity show --name ${manage_identity} --resource-group ${resource_group} || echo 0)
  if [ "$(echo $identity|jq -r '.name' 2>/dev/null)" == "$manage_identity" ]
  then
    export app_principalId=$(echo $identity|jq -r '.principalId')
    export app_client_id=$(echo $identity|jq -r '.clientId')
    return 0
  fi
  return 1
}

create_identity() {
  echo "Create workload identity."
  identity=$(az identity create --name ${manage_identity} --resource-group ${resource_group} || echo 0)
  if [ "$(echo $identity|jq -r '.name')" == "$manage_identity" ]
  then
    federated=$(az identity federated-credential create --identity-name ${manage_identity} --resource-group ${resource_group} --name app1 --issuer $oidc_issuer --subject "system:serviceaccount:app1:sa1" --audiences "api://AzureADTokenExchange")
    if [ "$(echo $federated|jq -r '.name')" == "app1" ]
    then
      export app_principalId=$(echo $identity|jq -r '.principalId')
      export app_client_id=$(echo $identity|jq -r '.clientId')
      return 0
    else
      return 2
    fi
  fi
  return 1

}

create_assignment() {
  echo "Create assignment."
  a1_id=$(az role assignment list --role "Storage Account Contributor" --scope ${storage_id} --assignee ${app_principalId} --query "[0].principalId" --output tsv)
  if [ "${a1_id}" != "${app_principalId}" ]
  then
    a1=$(az role assignment create --role "Storage Account Contributor" --scope ${storage_id} --assignee-object-id ${app_principalId} ) || return 1
  fi
  a2_id=$(az role assignment list --role "Storage Blob Data Contributor" --scope ${storage_id} --assignee ${app_principalId} --query "[0].principalId" --output tsv)
  if [ "${a2_id}" != "${app_principalId}" ]
  then
    a2=$(az role assignment create --role "Storage Blob Data Contributor" --scope ${storage_id} --assignee-object-id ${app_principalId} ) || return 1
  fi
}

render_template() {
  mkdir -p output
  echo "Render template."
  cat templates/storage-class.yaml | sed -e "s/STORAGE_RESOURCE_GROUP_TO_REPLACE/${resource_group}/g" \
                          -e "s/STORAGE_ACCOUNT_TO_REPLACE/${storage_name}/g" \
                          -e  "s/CONTAINER_NAME_TO_REPLACE/${container_name}/g" > output/storage-class.yaml || return 1
  cat templates/persistent-volume-static.yaml | sed -e "s/STORAGE_RESOURCE_GROUP_TO_REPLACE/${resource_group}/g" \
                          -e "s/STORAGE_ACCOUNT_TO_REPLACE/${storage_name}/g" \
                          -e  "s/CONTAINER_NAME_TO_REPLACE/${container_name}/g" \
                          -e "s/CLIENT_ID_TO_REPLACE/${app_client_id}/g" > output/persistent-volume-static.yaml || return 1

}

if [ "$aks_cluster" == "" ]
then
  die "Please set the aks_cluster variable first."
fi
get_storage
if [[ $? -gt 0 ]]
then
  create_storage || die "Cannot create the storage account."
fi
get_container
if [[ $? -gt 0 ]]
then
  create_container || die "Cannot create the storage container."
fi
get_aks_oidc
if [ -z "$oidc_issuer" ]
then
  die "Cannot get the AKS OIDC."
fi
get_identity
if [[ $? -gt 0 ]]
then
  create_identity || die "Cannot create the application identity."
fi
create_assignment
if [[ $? -gt 0 ]]
then
  die "Cannot create assign roles to the application identity."
fi
render_template
if [[ $? -gt 0 ]]
then
  die "Cannot render Kubernetes files."
fi