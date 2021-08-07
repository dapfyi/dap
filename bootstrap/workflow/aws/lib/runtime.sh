#!/bin/bash

run_workflow () {

    local runtime_name=$1
    local workflow=$2

    docker run \
        --rm \
        --name $runtime_name \
        -e AWS_PROFILE=$AWS_PROFILE \
        -v ~/.aws:/root/.aws \
        -v `pwd`/workflow:/opt/blake \
        -w /opt/blake \
        blake-bootstrap aws/$workflow

}

