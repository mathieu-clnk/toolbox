## Available fields

When creating a policy, you can evaluate the attribute of the resources available in the API call to determine if this matches your expectation.
Not all attributes are available in the API call. To find out what they are you can use the command below:

### Get namespaces
```
az provider list --query "[].namespace"
```

### Kubernetes
```bash
#Check for AAD, Kubernetes version, ...
az provider show --namespace  Microsoft.Kubernetes --expand "resourceTypes/aliases" --query "resourceTypes[].aliases[].name"
#Check the configuration of the AKS extensions
az provider show --namespace  Microsoft.KubernetesConfiguration --expand "resourceTypes/aliases" --query "resourceTypes[].aliases[].name"
#Check all the configuration of the Kubernetes 
az provider show --namespace  "Microsoft.ContainerService" --expand "resourceTypes/aliases" --query "resourceTypes[].aliases[].name"
```
### Virtual Machines
```
az provider show --namespace Microsoft.Compute --expand "resourceTypes/aliases" --query "resourceTypes[?resourceType=='virtualMachines'].aliases[].name"
```

