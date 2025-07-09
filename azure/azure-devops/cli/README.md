# Overview
Azure devops CLI can be installed with the pip package `azure-devops`. 
The login requires a PAT token.

# Commands

## Connect behind a proxy
If you are behind a proxy which does TLS inspection and returns a self-signed certificate, you may receive the error below:
```
Unable to get extension index.
Please ensure you have network connection. Error detail: HTTPSConnectionPool(host='aka.ms', port=443): Max retries exceeded with url: /azure-cli-extension-index-v1 (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:992)')))
```

The best practice is to create a bundle of all publicly trusted certificates and the proxy self-signed certificate in a bundle and then to use the environment variable `REQUESTS_CA_BUNDLE`. 

Another workaround, quite dangerous as it exposes the user to man-in-the-middle attack is to set the following variables.

Bash:
```bash
export AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1
export ADAL_PYTHON_SSL_NO_VERIFY=1
```

Powershell:
```
$Env:AZURE_CLI_DISABLE_CONNECTION_VERIFICATION=1
$Env:ADAL_PYTHON_SSL_NO_VERIFY=1
```

## Login

When you login with Azure DevOps, you shall set the organization when you need to login. Otherwise the following commands that you will enter may fail dues to an access deny.

You shall login with the command below:

```
az devops login --organization https://dev.azure.com/<organization-name>
```

## Remove the default wiki

If you have inadvertly click on the `Create wiki` button the first time you have been on the Wiki section, Azure DevOps create a `projectWiki`. This wiki cannot be deleted from the portal.
You need to run the commands below:

```bash
az devops wiki list --organization https://dev.azure.com/<organization> --project "<project name>"
#check the result where the `type` is `projectWiki`, note the `repositoryId` value.
az repos delete --id <repository-id> --organization https://dev.azure.com/<organization> --project "<project name>"
```
