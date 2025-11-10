#!/bin/bash
# This script needs to run with an account which as the permission "Application Owner" on the Service Principal.
# To add such permissions on the portal you need to do:
# Microsoft Entra ID / Entreprise applications / <Application name> / Roles and administrators / Application Owner / Add assignment
# /!\ NOTE: if you try to add the same assignment as indicated above but from the "App registrations" blade, this will grant you access not on the Service Principal but on the "Application".
# To review the scope of the assignment, you can go Microsoft Entra ID / Roles and Administrators / Application owner
USAGE="Usage: create-app-secret.sh -a <application_id> -d <display_name> -e <expiration_date> [ -h ]\n\
Options: \n\
    -a: Required. Application id. \n\
    -d: Required. Secret display name. \n\
    -e: Required. When the secret expires. Format example 2099-12-31\n\
    -h: Display this help. \n\
"

usage() {
    echo -e $USAGE
}

create_secret() {
  az ad app credential reset --append --display-name ${DISPLAY_NAME} --id ${APP_ID} --end-date "${EXPIRATION}"
}

die() {
    echo "ERROR: $1"
    exit 1
}

while getopts "a:d:e:h" options; do
    case "${options}" in
        a)
            APP_ID=${OPTARG}
            ;;
        d)
            DISPLAY_NAME=${OPTARG}
            ;;
        e)
            EXPIRATION=${OPTARG}
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

if [ -z "$APP_ID" ] || [ -z "$DISPLAY_NAME" ] || [ -z "$EXPIRATION" ]
then
    usage
    die "Please specify the required options"
fi
create_secret || die "Cannot create a secret."