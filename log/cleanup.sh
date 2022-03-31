#!/bin/bash

cluster=$1
if [ -z $cluster ]; then
    echo 'Cluster name argument is missing, e.g. run `./cleanup.sh {blue|green}-dap`.'
    exit 1
fi

echo "WARNING: log bucket and its content will be deleted."
read -p "Are you sure? Type YES to confirm or any character to exit: "

if [[ $REPLY =~ ^YES$ ]]; then
    source ../bootstrap/workflow/aws/lib/env.sh
    echo "DaP ~ deleting stateful Fluent resources tied to $cluster cluster"
    aws s3 rb s3://$cluster-$REGION-log-$ACCOUNT --force
fi

