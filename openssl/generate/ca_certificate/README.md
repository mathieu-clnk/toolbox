# Overview
This `Dockerfile` generate a *Certificate Authority (CA)* for the domain `kamvity.com`.
Then it generates a certificate from this CA for the *Common Name (CN)* `localhost.kamvity.com` 
Finally the script generate the *Key store* which is used by the Java https server to encrypt the data.
It also generates a *Trust store* which is used to trust all certificates signed by this CA.

Run the following command to generate the both stores.

```bash
docker build . --tag ca_certificate:1.0
docker run --name ca_certificate ca_certificate:1.0 /bin/true
docker cp ca_certificate:/tmp/keystore.pfx ./output/keystore.pfx
docker cp ca_certificate:/tmp/truststore.pfx ./output/truststore.pfx
docker rm ca_certificate 
```