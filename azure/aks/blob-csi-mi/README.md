# Overview

The files under this folder are used to demonstrate the issue [#3432](https://github.com/Azure/AKS/issues/3432).

## Step to reproduce

### Prerequisite

Create a resource group, a VNET with a subnet and a route table attached to the subnet.

### Create the AKS

Replace the value of the resource group, VNET, subnet and route table in the script `create-aks.sh`

```bash
# replace the value with the resources you want before executing the script.
chmod u+x create-aks.sh
./create-aks.sh
```

### Generate the file

Replace the value of the resource group, storage account name, container name and AKS name.

```bash
# replace the value with the resources you want before executing the script.
chmod u+x generate-workload-files.sh
./generate-workload-files.sh
```

### Deploy

The files have been generated, we just need to connect to the new cluster and deploy the generated files.

```bash
# This commands are executed in a VM with a system identity.
# This system identity is owner of the resource group.
# The object id of this VM is 11111111-1111-1111-1111-111111111111
aksID=$(az aks show --name aks-demo-2025050416111746375118 --resource-group rsg-demo-3432 --query "id" -o tsv)
az role assignment create --role "Azure Kubernetes Service RBAC Cluster Admin" --scope ${aksID} --assignee-object-id $object_id --query "name" 
az aks get-credentials --resource-group rsg-demo-3432 --name aks-demo-2025050416111746375118 --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl create ns app1
kubectl apply -f output/storage-class.yaml
kubectl apply -f persistent-volume-claim.yaml
kubectl apply -f deployment-mi.yaml
```

### Troubleshooting

```bash
kubectl -n app1 get po
kubectl -n app1 get pvc
kubectl get sc
client_id=$(kubectl get sc sc-fuse -o json| jq -r ".parameters.AzureStorageIdentityClientID")
storage_name=$(kubectl get sc sc-fuse -o json| jq -r ".parameters.storageAccount")
resource_group=$(kubectl get sc sc-fuse -o json| jq -r ".parameters.resourceGroup")
storage_id=$(az storage account show --name ${storage_name} --resource-group ${resource_group} --query "id" -o tsv)
az role assignment list --scope ${storage_id} --assignee-object-id ${client_id} 
# As the deployment above is using a singe replica, we will check on which worker node it tries to run
worker=$(kubectl -n app1 get po -l app=app1 -o custom-columns="node":.spec.nodeName --no-headers)
csi_pod=$( kubectl -n kube-system get po -l app=csi-blob-node -o json| jq -r '.items[] | select(.spec.nodeName == "'$worker'").metadata.name')
kubectl -n kube-system logs $csi_pod -c blob
```