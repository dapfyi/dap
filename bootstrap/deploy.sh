#!/bin/bash

lib_path=workflow/aws/lib
source $lib_path/profile-configuration.sh
source $lib_path/runtime.sh

echo "BLAKE ~ building bootstrap environment"
docker build -t blake-bootstrap .

echo "BLAKE ~ running deployment workflow"
run_workflow blake-bootstrap blue-green-deployment.sh

echo "BLAKE ~ deployment exit code: $?"

