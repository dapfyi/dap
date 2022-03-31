#!/bin/bash

lib_path=workflow/aws/lib
source $lib_path/profile-configuration.sh
source $lib_path/runtime.sh

echo "DaP ~ going to destroy cluster and AWS objects"
run_workflow dap-cleanup aws/cleanup.sh

echo "DaP ~ cleanup exit code: $?"

