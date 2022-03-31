#!/bin/bash

run_workflow () {

    local runtime_name=$1
    local workflow=$2

    # use absolute path to mount local folders
    docker run \
        --rm \
        --name $runtime_name \
        -e AWS_PROFILE=$AWS_PROFILE \
        -v ~/.aws:/root/.aws \
        -v ~/.dap:/root/.dap \
        -v `pwd`/workflow:/opt/dap \
        -v `git rev-parse --show-toplevel`/DaP:/opt/DaP \
        -w /opt/dap \
        dap-bootstrap $workflow

}

