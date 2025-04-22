#!/bin/bash
USAGE="Usage: create-self-signed.sh -c <configuration_directory> -d <certificate_name> -o <output_directory> [ -h ]\n\
Options: \n\
    -c: the configuration directory where the openssl files are. \n\
    -d: the Certificate Name to generate.
    -o: the output directory where the keystore and truststore will be set. \n\
    -h: Display this help. \n\
"

die() {
  echo "ERROR: $1"
  exit 1
}

usage() {
  echo -e $USAGE
}

clean_directory() {
  rm -rf ${configuration_directory}/certificates || return 1
}

generate_request() {
  mkdir -p ${configuration_directory}/certificates || return 1
  echo "Generate the client private key"
  openssl genrsa -out ${configuration_directory}/certificates/${name}.key 2048 || return 1
  echo "Generate the client CSR"
  openssl req -new -config ${configuration_directory}/${name}.cfg -key ${configuration_directory}/certificates/${name}.key -out ${configuration_directory}/certificates/${name}.csr || return 1
  echo "Check the CSR validity"
  openssl req -text -noout -verify -in ${configuration_directory}/certificates/${name}.csr || return 1
}

generate_ca() {
  echo "Generate the CA private key"
  openssl genrsa -out  ${configuration_directory}/certificates/CA.key 2048 || return 1
  echo "Generate the CA cert"
  openssl req -x509 -sha256 -days 1825 -newkey rsa:2048 -key ${configuration_directory}/certificates/CA.key -passin pass: -out ${configuration_directory}/certificates/CA.crt -config ${configuration_directory}/${domain_name}.cfg || return 1
}

generate_certificate_from_ca() {
  echo "Generate the certificate"
  openssl x509 -req -CA ${configuration_directory}/certificates/CA.crt -CAkey ${configuration_directory}/certificates/CA.key -in ${configuration_directory}/certificates/${name}.csr -out ${configuration_directory}/certificates/${name}.crt -days 365 -CAcreateserial -extfile ${configuration_directory}/${name}.ext || die "Cannot generate the certificate from the CA."
  echo "Creating the full chain cert"
  cat ${configuration_directory}/certificates/${name}.crt ${configuration_directory}/certificates/CA.crt > ${configuration_directory}/certificates/fullchain.pem || die "Cannot generate the full chain."
}

generate_stores() {
  echo "Generate the PFX"
  openssl pkcs12 -export -out ${output_directory}/keystore.pfx -inkey ${configuration_directory}/certificates/${name}.key -in ${configuration_directory}/certificates/fullchain.pem -passin pass: -passout pass:changeit -name myalias || die "Generate the keystore."
  echo "Creating the Truststore PFX"
  keytool -keystore ${output_directory}/truststore.pfx -storepass changeit -importcert -alias client-ca -file ${configuration_directory}/certificates/CA.crt -noprompt  || die "Generate truststore."
}

while getopts "c:d:o:h" options; do
    case "${options}" in
        c)
            configuration_directory=${OPTARG}
            ;;
        d)
            name=${OPTARG}
            ;;
        o)
            output_directory=${OPTARG}
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

if [ -z "${configuration_directory}" ] || [ -z "${name}" ] || [ -z "${output_directory}" ]
then
  usage
  die "Please specify the mandatory options."
fi

domain_name="$(echo ${name} | cut -d"." -f2-99)"

clean_directory || die "Cannot clean the directory."
generate_request || die "Cannot generate certificate."
generate_ca || die "Cannot generate the CA."
generate_certificate_from_ca || die "Cannot generate the certificate from the CA."
generate_stores || die "Cannot generate stores."
