#!/bin/bash
storage_name="stademo3432"
container_name="container3432"
resource_group="rsg-demo-3432"
manage_identity="mid-aks-demo"
aks_cluster=""

die() {
  echo "ERROR: $1"
  exit 1
}
get_storage() {
  echo "Get storage."
  storage=$(az storage account show --name ${storage_name} --resource-group ${resource_group} 2>/dev/null|| echo 0)
  if [ "$(echo $storage|jq -r '.name' 2>/dev/null)" == "$storage_name" ]
  then
    export storage_id=$(echo $storage|jq -r '.id')
    echo "Storage exist:"
    az storage account show --name ${storage_name} --resource-group ${resource_group} --query "name"
    return 0
  fi
  return 1
}

get_container() {
  echo "Get container."
  container=$(az storage container show --name ${container_name} --account-name ${storage_name} --auth-mode login --timeout 5 2>/dev/null|| echo 0)
  if [ "$(echo $container|jq -r '.name' 2>/dev/null)" == "$container_name" ]
  then
    echo "Container exist:"
    az storage container show --name ${container_name} --account-name ${storage_name} --auth-mode login --timeout 5 --query "name"
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
  if [ "$(echo $container|jq -r '.created')" == "true" ]
  then
    return 0
  fi
  return 1
}

get_identity() {
  echo "Get workload get_identity."
  identity=$(az identity show --name ${manage_identity} --resource-group ${resource_group} 2>/dev/null|| echo 0)
  if [ "$(echo $identity|jq -r '.name' 2>/dev/null)" == "$manage_identity" ]
  then
    export app_principalId=$(echo $identity|jq -r '.principalId')
    export app_client_id=$(echo $identity|jq -r '.clientId')
    echo "Principal ID: $app_principalId,Client ID: $app_client_id"
    return 0
  fi
  return 1
}

create_assignment() {
  echo "Create assignment."
  sleep 20
  a1_id=$(az role assignment list --role "Storage Account Contributor" --scope ${storage_id} --assignee ${app_principalId} --query "[0].principalId" --output tsv 2> /dev/null)
  if [ "${a1_id}" != "${app_principalId}" ]
  then
    a1=$(az role assignment create --role "Storage Account Contributor" --scope ${storage_id} --assignee-object-id ${app_principalId} 2> /dev/null) || return 1
  fi
  echo "Check assignment of principal ${app_principalId} on the storage $storage_name:"
  az role assignment list --role "Storage Account Contributor" --scope ${storage_id} --assignee ${app_principalId} --query '[0].[{"assignmentName":name,"principalId":principalId,"role":roleDefinitionName}]' 2> /dev/null
  a2_id=$(az role assignment list --role "Storage Blob Data Contributor" --scope ${storage_id} --assignee ${app_principalId} --query "[0].principalId" --output tsv 2> /dev/null)
  if [ "${a2_id}" != "${app_principalId}" ]
  then
    a2=$(az role assignment create --role "Storage Blob Data Contributor" --scope ${storage_id} --assignee-object-id ${app_principalId} 2> /dev/null) || return 1
  fi
  echo "Check assignment of principal ${app_principalId} on the storage $storage_name:"
  az role assignment list --role "Storage Blob Data Contributor" --scope ${storage_id} --assignee ${app_principalId} --query '[0].[{"assignmentName":name,"principalId":principalId,"role":roleDefinitionName}]' 2> /dev/null
}

render_template() {
  mkdir -p output
  echo "Render template."
  cat templates/storage-class.yaml | sed -e "s/STORAGE_RESOURCE_GROUP_TO_REPLACE/${resource_group}/g" \
                          -e "s/STORAGE_ACCOUNT_TO_REPLACE/${storage_name}/g" \
                          -e  "s/CONTAINER_NAME_TO_REPLACE/${container_name}/g" \
                          -e "s/CLIENT_ID_TO_REPLACE/${app_client_id}/g" > output/storage-class.yaml  || return 1

  cat templates/persistence-volume-static.yaml | sed -e "s/STORAGE_RESOURCE_GROUP_TO_REPLACE/${resource_group}/g" \
                          -e "s/STORAGE_ACCOUNT_TO_REPLACE/${storage_name}/g" \
                          -e  "s/CONTAINER_NAME_TO_REPLACE/${container_name}/g" \
                          -e "s/CLIENT_ID_TO_REPLACE/${app_client_id}/g" > output/persistence-volume-static.yaml  || return 1

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