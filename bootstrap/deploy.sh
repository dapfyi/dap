#!/bin/bash

lib_path=workflow/aws/lib
source $lib_path/profile-configuration.sh
source $lib_path/runtime.sh

echo "DaP ~ building bootstrap environment"
docker build -t dap-bootstrap .

echo "DaP ~ running deployment workflow"
run_workflow dap-bootstrap aws/blue-green-deployment.sh

echo "DaP ~ deployment exit code: $?"

