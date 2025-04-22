#!/bin/bash
USAGE="Usage: manage-pat.sh -a <action> [-i <authorization-id>] -o <organization> \n\
Options: \n \
    -a: Required. Action to execute. Options supported are 'create','get','list' \n\
    -i: Required with 'get' action. The authorization id of the PAT. Can be retrieved with the list action. \n\
    -k: Required. The Key Vault name where the service account password is. This is also used when we 'create' the PAT token.\n\
    -n: Required. The subscription name where the Key vault is.\n\
    -p: Required. The secret name where the service account password is stored.\n\
    -s: Required. The service account name.\n\
    -t: Required with 'create' action. The secret name that contains the PAT.\n\
    -o: Required. ADO organization name.\n \
"

usage() {
    echo -e $USAGE
}

die() {
    echo "ERROR: $1"
    exit 1
}

generate_json() {
    cat > token.json << EOF
{
    "displayName": "auto-generated-${now}",
    "scope": "app_token",
    "validTo": "${expiration}",
    "allOrgs": false
}
EOF
}

# Return a JSON result as below
# {
#   "patToken":
#      {
#         "displayName":"auto-generated-<timestamp>",
#         "validTo": "<expiration-day>",
#         "scope":"app_token",
#         "targetAccounts": [ "<org-id>"],
#         "validFrom":"2022-04-27T15:03:45.6266667Z",
#         "authorizationId":"<id>",
#         "token":"<the-token>"
#      },
#      "patTokenError":"none"
# }
retrieve_login_svc() {
    az account clear
    az login --identity
    az keyvault secret download --subscription $SUBSCRIPTION_NAME --name $PWD_SECRET_NAME --vault-name $KEYVAULT_NAME --file .tmp_sec || die "Please check that the secret $PWD_SECRET_NAME exists in the keyvault $KEYVAULT_NAME within the subscription $SUBSCRIPTION_NAME"
    SVC_PASSWORD="$(cat .tmp_sec)" || die "Cannot read the secret file"
    rm .tmp.sec || die "File cannot be deleted"
}

generate_pat() {
    az account clear
    retrieve_login_svc
    az login -u $SVC_ACCOUNT -p $SVC_PASSWORD --allow-no-subscriptions
    now=$(date +%F"_"%T)
    expiration=$(date --date="+1 month" +%F"T"%T".000Z")
    result=$(az account get-access-token)
    token=$(echo $result|jq -r ".accessToken")
    generate_json
    PAT_TOKEN="$(curl -s -X POST -d @token.json -H "Authorization: Bearer $token" -H "Content-Type: application/json" https://vssps.dev.azure.com/${ORGANIZATION}/_apis/tokens/pats?api-version=7.1-preview.1| jq -r ".patToken.token")"
}

list_pats() {
    az account clear
    retrieve_login_svc
    az login -u $SVC_ACCOUNT -p $SVC_PASSWORD --allow-no-subscriptions
    result=$(az account get-access-token)
    token=$(echo $result|jq -r ".accessToken")
    curl -s -X GET -H "Authorization: Bearer $token" -H "Content-Type: application/json" https://vssps.dev.azure.com/${ORGANIZATION}/_apis/tokens/pats?api-version=7.1-preview.1
}

get_pat() {
    az account clear
    retrieve_login_svc
    az login -u $SVC_ACCOUNT -p $SVC_PASSWORD --allow-no-subscriptions
    result=$(az account get-access-token)
    token=$(echo $result|jq -r ".accessToken")
    curl -s -X GET -H "Authorization: Bearer $token" -H "Content-Type: application/json" "https://vssps.dev.azure.com/${ORGANIZATION}/_apis/tokens/pats?authorizationId=${AUTHORIZATION_ID}&api-version=7.1-preview.1"
}


save_pat() {
    generate_pat
    az account clear
    az login --identity
    az keyvault secret set --subscription $SUBSCRIPTION_NAME --name $PAT_SECRET_NAME --vault-name $KEYVAULT_NAME --value "$PAT_TOKEN"
}
while getopts "a:hi:k:o:n:p:s:t:" options; do
    case "${options}" in 
        a)
            ACTION=${OPTARG}
            ;;
        i)
            AUTHORIZATION_ID=${OPTARG}
            ;;
        k)
            KEYVAULT_NAME=${OPTARG}
            ;;
        o)
            ORGANIZATION=${OPTARG}
            ;;
        n)
            SUBSCRIPTION_NAME=${OPTARG}
            ;;
        p)
            PWD_SECRET_NAME=${OPTARG}
            ;;
        s)
            SVC_ACCOUNT=${OPTARG}
            ;;
        t)
            PAT_SECRET_NAME=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            die "Bad usage."
            ;;
    esac
done

if [ -z "$ACTION" ] || [ -z "$ORGANIZATION" ] || [ -z "$SUBSCRIPTION_NAME" ] || [ -z "$PWD_SECRET_NAME" ] || [ -z "$KEYVAULT_NAME" ]
then
    usage
    die "Required options are not set."
fi

if [ "$ACTION" != "get" ] && [ "$ACTION" != "create" ] && [ "$ACTION" != "list" ]
then
    usage
    die "Value not supported for option '-a'. Supported values are: 'create','get' and 'list'"
fi
if [ "$ACTION" == "get" ] && [ -z "$AUTHORIZATION_ID" ]
then
    usage
    die "Please specify the authorization id."
elif [ "$ACTION" == "create" ] && [ -z "$PAT_SECRET_NAME" ]
then
    usage
    die "Please specify the PAT secret name."
fi

if [ "$ACTION" == "get" ]
then
    get_pat
elif [ "$ACTION" == "create" ]
then
    save_pat
elif [ "$ACTION" == "list" ]
then
    list_pats
fi    