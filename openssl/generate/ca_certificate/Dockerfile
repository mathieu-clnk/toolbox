FROM ubuntu:22.04
RUN apt-get update -y
RUN apt install -y wget apt-transport-https gpg
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
RUN echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
RUN apt update -y; apt install -y temurin-17-jdk

COPY scripts /tmp/scripts/
WORKDIR /tmp/

RUN chmod u+x /tmp/scripts/create-self-signed.sh
RUN /tmp/scripts/create-self-signed.sh -c /tmp/scripts/ -o /tmp/ -d localhost.kamvity.com