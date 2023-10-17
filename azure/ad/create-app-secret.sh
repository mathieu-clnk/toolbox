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
  az ad app credential reset --display-name ${DISPLAY_NAME} --id ${APP_ID} --end-date "${EXPIRATION}"
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