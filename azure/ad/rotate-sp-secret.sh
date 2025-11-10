#!/bin/bash
# This script needs to run with an account which as the permission "Application Owner" on the Service Principal.
# To add such permissions on the portal you need to do:
# Microsoft Entra ID / Entreprise applications / <Application name> / Roles and administrators / Application Owner / Add assignment
# /!\ NOTE: if you try to add the same assignment as indicated above but from the "App registrations" blade, this will grant you access not on the Service Principal but on the "Application".
# To review the scope of the assignment, you can go Microsoft Entra ID / Roles and Administrators / Application owner
script_name=$(basename $0)
USAGE="Usage: ${script_name} -a <application_id> -k <key_id> -o <output_folder> [ -D <number_days> ] [ -v <number_months_validity> ] [ -h ]\n\
Options: \n\
    -a <application_id>: Required. Application id. \n\
    -D <number_days>: Facultative. The number of days before the expiration when we generate a new client key. Default value is 30.\n\
    -k <key_id>: Required. The current key id in used.\n\
    -o <output_folder>: Required. The folder where the new password will be stored.\n\
    -v <number_months_validity>: Facultative. The number of month the certificate shall be valid. Default 6 months.\n\
    -h: Display this help. \n\
"

die() {
    echo "$(date +%b' '%_e' '%H':'%m':'%S) $(hostname) ${script_name} - ERROR: $1"
    exit 1
}

log() {
  echo "$(date +%b' '%_e' '%H':'%m':'%S) $(hostname) ${script_name} - INFO: $1"
}

usage() {
    echo -e $USAGE
}

check_secret_threshold_expiration() {
  has_error="no"
  is_current_secret_exists="no"
  all_credentials=$(az ad app credential list --id ${APP_ID} -o json) || return 1
  number_secrets=$(echo $all_credentials | jq ". | length")
  log "Checking existing credentials expiration."
  for item in $(echo $all_credentials | jq -r -c '.[]')
  do
    if [ "$has_error" == "no" ]
    then
      item_display_name=$(echo $item| jq -r ".displayName")
      log "Credential secret name $item_display_name."
      item_expiration_date=$(echo $item| jq -r ".endDateTime")
      if [[ $? -gt 0 ]]
      then
        has_error="yes"
        log "Error while getting endDateTime value of $item_display_name."
      else
        item_expiration_keyid=$(echo $item| jq -r ".keyId") || return 1
        if [ "$KEY_ID" == "$item_expiration_keyid" ]
        then
          log "The credential secret stored in the Key Vault with the key Id $KEY_ID does exist."
          is_current_secret_exists="yes"
        fi
        input_ts=$(date -d "${item_expiration_date%.*}Z" +%s) || return 1
        threshold_ts=$(date -d "+$NUMBER_DAYS days" +%s)
        now_ts=$(date +%s)
        if [[ $input_ts -lt $now_ts ]]
        then
          az ad app credential delete --key-id "$item_expiration_keyid" --id ${APP_ID}
          if [[ $? -gt 0 ]]
          then
            has_error="yes"
            log "Error while deleting the expired key $item_expiration_keyid."
          else
            log "The expired key $item_expiration_keyid has been deleted successfully."
          fi
        elif [[ $input_ts -lt $threshold_ts ]]
        then
          log "The credential with the key Id $current_secret_keyid is about to expire in the following $NUMBER_DAYS days."
          if [ "$current_secret_keyid" == "$item_expiration_keyid" ]
          then
            if [[ $number_secrets -eq 1 ]]
            then
              log "The current credential is about to expire, generating a new key pair."
              generate_expiration_date
              if [ -z "$generate_expiration_date" ]
              then
                has_error="yes"
                log "Cannot generate an expiration date of $VALIDITY_MONTH months validity."
              else
                create_secret
              fi
            else
              has_error="yes"
              log "The current key $current_secret_keyid is going to expired but too many key pairs exist."
            fi
          else
            log "The key $item_expiration_keyid is going to expired but is not in used. We will delete automatically once expired."
          fi
        fi
      fi
    fi
  done
  if [ "$has_error" == "yes" ]
  then
    log "The key update process has failed."
    return 1
  fi
}

generate_expiration_date() {
  expiration_date=$(date -u -d "+$VALIDITY_MONTH months" +"%Y-%m-%dT%H:%M:%S.%3NZ") || return 1
}

get_credential_keyid() {
  new_key_id=$(az ad app credential list --id ${APP_ID} -o json | jq '.| select(.endDateTime == "'${expiration_date}'") | .keyId') || return 1
  if [ -z "$new_key_id" ]
  then
    log "Cannot find a key id with an expiration is ${expiration_date} for the application id ${APP_ID}."
    return 1
  fi
}

create_secret() {
  DISPLAY_NAME=$(date +%Y%m)
  secret_key_json=$(az ad app credential reset --display-name ${DISPLAY_NAME} --id ${APP_ID} --end-date "${expiration_date}" --append) || return 1
  secret_password=$(echo $secret_key_json| jq ".password") || return 1
  if [ -z "secret_password" ]
  then
    log "The client credential cannot be generated with the name ${DISPLAY_NAME} and the expiration ${expiration_date} for the application id ${APP_ID}."
    return 1
  fi
  log "The client credential with the name ${DISPLAY_NAME} and the expiration ${expiration_date} for the application id ${APP_ID} has been generated."
  get_credential_keyid || return 1
  umask 177
  echo -n "$secret_password" > $OUTPUT_FOLDER/.client_p
  if [[ $? -gt 0 ]]
  then
    log "Cannot save the secret."
    return 1
  fi
  echo -n "$new_key_id" > $OUTPUT_FOLDER/.client_k
  if [[ $? -gt 0 ]]
  then
    log "Cannot save the key."
    return 1
  fi
  log "New credential $new_key_id has been updated to he secret $SECRET_NAME under the key vault $KEYVAULT_NAME in $SUBSCRIPTION_NAME."
}

while getopts "a:D:k:o:v:h" options; do
    case "${options}" in
        a)
            APP_ID=${OPTARG}
            ;;
        D)  NUMBER_DAYS=${OPTARG}
            ;;
        k)  KEY_ID=${OPTARG}
            ;;
        o)  OUTPUT_FOLDER=${OPTARG}
            ;;
        v)  VALIDITY_MONTH=${OPTARG}
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

DEFAULT_NUMBER_DAYS="30"
DEFAULT_MONTH_VALIDITY="6"
if [ -z "$APP_ID" ] || [ -z "$KEY_ID" ] || [ -z "$OUTPUT_FOLDER" ]
then
    usage
    die "Please specify the required options"
fi
if [! -d "$OUTPUT_FOLDER" ]
then
  die "$OUTPUT_FOLDER is not a folder."
fi
if [ -z "$NUMBER_DAYS" ]
then
  NUMBER_DAYS=$DEFAULT_NUMBER_DAYS
fi
if [ -z "$VALIDITY_MONTH" ]
then
  VALIDITY_MONTH=DEFAULT_MONTH_VALIDITY
fi

# Loop over the key and see if we need to update.
check_secret_threshold_expiration || die "Cannot update the key for the application id ${APP_ID}."