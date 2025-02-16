#!/bin/bash

USAGE="Usage: add_mfa.sh -d <device_name> -f <device_key> -u <user_name> [ -t <token-code> ] [ -h ]\n\
Options: \n\
    -d: Required. Unique MFA device name. \n\
    -f: Required. The file name where the security key shall be saved. \n\
    -u: Required. The user name. \n\
    -t: Optional. The token code in case an MFA device is already assigned to this user. \n\
    -h: Display this help. \n\
"

usage() {
    echo -e $USAGE
}

die() {
    echo "ERROR: $1"
    exit 1
}

install_tool() {
  sudo apt-get install -y oathtool || die "Cannot install oathtool."
}

create_mfa() {
  serial_number=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name ${DEVICE_NAME} \
  --outfile ${FILE_NAME} --bootstrap-method Base32StringSeed
  | jq -r ".VirtualMFADevice.SerialNumber") || die "Cannot create the MFA device."
  [[ $serial_number =~ ^[[:alnum:]]+$ ]] || die "Serial number not created."
  echo "MFA ${serial_number} has been created successfully."
}

check_existing_mfa() {
  number_device=$(aws iam list-mfa-devices --user-name ${AWS_USERNAME}| jq '.MFADevices | length')
  [[ ${number_device} -gt 0 ]] && return 0
  return 1
}
get_2fa_authentication() {
  #echo "A MFA already exists for this user. Please enter the Temporary token of this existing MFA below."
  #echo -n "TOTP: " ; read totp
  aws sts get-session-token --serial-number "arn:aws:iam::761701271556:mfa/aws-cli-totp" --token-code $TOTP > /tmp/mfa.json
  export AWS_ACCESS_KEY_ID=$(cat /tmp/mfa.json| jq -r ".Credentials.AccessKeyId")
  export AWS_SESSION_TOKEN=$(cat /tmp/mfa.json| jq -r ".Credentials.SessionToken")
  export AWS_SECRET_ACCESS_KEY=$(cat /tmp/mfa.json| jq -r ".Credentials.SecretAccessKey")
}

enable_mfa() {
    check_existing_mfa && get_2fa_authentication
    totp1=$(oathtool -b --totp $(cat ${FILE_NAME})) || die "Cannot generate the first TOTP"
    totp2=$totp1
    while [ "$totp2" == "$totp1" ]
    do
      totp2=$(oathtool -b --totp $(cat ${FILE_NAME})) || die "Cannot generate the second TOTP"
    done
    aws iam enable-mfa-device --user-name ${AWS_USERNAME} --serial-number ${serial_number} --authentication-code1 $totp1 --authentication-code2 $totp2
}

while getopts "d:f:ht:u:" options; do
    case "${options}" in
        d)
            DEVICE_NAME=${OPTARG}
            ;;
        f)
            FILE_NAME=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        t)
            TOTP=${OPTARG}
            ;;
        u)
            AWS_USERNAME=${OPTARG}
            ;;
        *)
            usage
            die "Option not known. Please review the usage."
            ;;
    esac
done
[[ -z ${DEVICE_NAME} ]] && usage && die "Please specify the device name."
[[ -z ${FILE_NAME} ]] && usage && die "Please specify the file name."
[[ -z ${AWS_USERNAME} ]] && usage && die "Please specify the user name."

aws iam get-user --user-name ${AWS_USERNAME} > /dev/null 2>&1 || die "User ${AWS_USERNAME} not found."
sudo dpkg -l jq > /dev/null 2>&1 || die "Please install jq."
sudo dpkg -l oathtool > /dev/null 2>&1 || die "Please install oathtool."
check_existing_mfa && [ -z ${TOTP} ] && usage && die "An MFA device already exists for this user but the token code has not been specify."