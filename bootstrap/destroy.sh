#!/bin/bash

lib_path=workflow/aws/lib
source $lib_path/profile-configuration.sh
source $lib_path/runtime.sh

echo "BLAKE ~ going to destroy cluster and AWS objects"
run_workflow blake-cleanup cleanup.sh

echo "BLAKE ~ cleanup exit code: $?"

