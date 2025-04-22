#!/bin/bash
die() {
    echo "ERROR: $1"
    exit 1
}
[[ -z "$FILE_GIT_USERNAME" ]] && die "Please set the environment variable FILE_GIT_USERNAME."
[[ -z "$FILE_GIT_PASSWORD" ]] && die "Please set the environment variable FILE_GIT_USERNAME."
[[ -s "$FILE_GIT_USERNAME" ]] || die "The file $FILE_GIT_USERNAME does NOT exists"
[[ -s "$FILE_GIT_PASSWORD" ]] || die "The file $FILE_GIT_PASSWORD does NOT exists"
echo "protocol=https"
echo "username=$(cat $FILE_GIT_USERNAME)"
echo "password=$(cat $FILE_GIT_PASSWORD)"
echo "host=dev.azure.com"
git config --global credential.helper 'read-only --file ~/.gitcreds'
