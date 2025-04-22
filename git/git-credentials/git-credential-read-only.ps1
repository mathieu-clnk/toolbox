function die() {
    Write-Error "ERROR $1"
    exit 1
}
$secret_name_pat="ado-git-pull-pat"
$secret_name_username="ado-git-pull-username"
if ($null -eq $KEY_VAULT_NAME) {
    die "Please set the variable KEY_VAULT_NAME"
}
$PATCreds=az keyvault secret show --name $secret_name_pat --vault-name $KEY_VAULT_NAME --subscription $SUBSCRIPTION_NAME|ConvertFrom-Json
$UsernameCreds=az keyvault secret show --name $secret_name_username --vault-name $KEY_VAULT_NAME --subscription $SUBSCRIPTION_NAME|ConvertFrom-Json
echo "protocol=https"
echo "username=$($UsernameCreds.value)"
echo "password=$($PATCreds.value)"
echo "host=dev.azure.com"