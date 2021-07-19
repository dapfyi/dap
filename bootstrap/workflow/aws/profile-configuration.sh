#!/bin/bash

if [ -z $AWS_PROFILE ]; then

    echo "BLAKE ~ AWS_PROFILE not set: workflow to authenticate with [default] AWS profile."

    if ! grep -q '\[default\]' ~/.aws/config; then
        printf "\nA [default] profile must be configured in ~/.aws/config.\n"
        printf "Install AWS cli and run 'aws configure' before this script.\n\n"
        exit 1
    fi

    export AWS_PROFILE=default

else

    echo "BLAKE ~ AWS_PROFILE set: workflow to authenticate with [$AWS_PROFILE] AWS profile."

fi

