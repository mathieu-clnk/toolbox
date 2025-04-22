#!/bin/bash

KUBELOGIN_VERSION="v0.0.13"

USAGE="Usage: aks-login-sp.sh -a <aks-cluster-name> -k <kube-config-file> -r <resource-group> -s <subscription-name> [ -h ]\n\
Options: \n\
    -a: Required. AKS Cluster name to login. \n\
    -k: Required. The Kube configuration file where to store the certificate to login. \n\
    -r: Required. The resource group name where the AKS cluster is deployed. \n\
    -s: Required. The subscription where the AKS is deployed \n\
    -h: Display this help. \n\
"

usage() {
    echo -e $USAGE
}

die() {
    echo "ERROR: $1"
    exit 1
}

install_kubelogin() {
    wget https://github.com/Azure/kubelogin/releases/download/v0.0.13/kubelogin-linux-amd64.zip -O kubelogin-linux-amd64.zip || return 1
    unzip kubelogin-linux-amd64.zip || return 1
    chmod 755 bin/linux_amd64/kubelogin || return 1
    mkdir -p $HOME/.bin || return 1
    mv bin/linux_amd64/kubelogin $HOME/.bin/ || return 1
}

install_kubelogin_if_absent() {
    ( /usr/bin/which kubelogin 2> /dev/null || install_kubelogin ) || return 1
}

convert_kube() {
    [[ ! -z $KUBECONFIG ]] && [[ -f $KUBECONFIG ]] || ( echo "KUBECONFIG variable ($KUBECONFIG) not set or the file does NOT exist" && return 1 )
    kubelogin convert-kubeconfig -l azurecli --kubeconfig $KUBECONFIG || return 1
}

login_aks() {
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --subscription $SUBSCRIPTION_NAME -f $KUBECONFIG || return 1
}

debug_connection() {
    k8s_fqdn=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --subscription $SUBSCRIPTION_NAME 2> /dev/null |grep privateFqdn |awk -F': "' '{print $2}'|awk -F'"' '{ print $1}')
    curl -m 10 -k https://${k8s_fqdn}/version 
    cat /etc/resolv.conf
    return 0
}

check_login() {
    timeout 20s kubectl --request-timeout 10 get ns > /dev/null 2>&1 || ( debug_connection && return 1 )
}

while getopts "a:k:hr:s:" options; do
    case "${options}" in 
        a)
            AKS_CLUSTER_NAME=${OPTARG}
            ;;
        k)
            KUBECONFIG=${OPTARG}
            ;;
        r)
            RESOURCE_GROUP=${OPTARG}
            ;;
        s)
            SUBSCRIPTION_NAME=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            die "Option not known. Please review the usage."
            ;;
    esac
done

if [ -z "$AKS_CLUSTER_NAME" ] || [ -z "$KUBECONFIG" ] || [ -z "$RESOURCE_GROUP" ] || [ -z "$SUBSCRIPTION_NAME" ]
then
    usage
    die "Please specify the required options"
fi

login_aks || die "Cannot login to AKS."
install_kubelogin_if_absent || die "Cannot install kubelogin."
export PATH=$PATH:$HOME/.bin/
convert_kube || die "Cannot convert the kubeconfig file defined under the KUBECONFIG variable."
check_login || die "Cannot connect to the cluster"