#!/bin/bash
die() {
    echo "ERROR: $1"
    exit 1
}
secret_name_pat="ado-git-pull-pat"
secret_name_username="ado-git-pull-username"
[[ -f /usr/bin/jq ]] || die "Please install jq command."
[[ -z "$KEY_VAULT_NAME" ]] && die "Please set the environment variable KEY_VAULT_NAME."
[[ -z "$SUBSCRIPTION_NAME" ]] && die "Please set the environment variable SUBSCRIPTION_NAME."
token=$(az keyvault secret show --name $secret_name_pat --vault-name $KEY_VAULT_NAME --subscription $SUBSCRIPTION_NAME| jq -r ".value")
username=$(az keyvault secret show --name $secret_name_username --vault-name $KEY_VAULT_NAME --subscription $SUBSCRIPTION_NAME| jq -r ".value")
echo "protocol=https"
echo "username=$username"
echo "password=$token"
echo "host=dev.azure.com"
