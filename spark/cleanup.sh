#!/bin/bash

cluster=$1
if [ -z $cluster ]; then
    echo 'Cluster name argument is missing, e.g. run `./cleanup.sh {blue|green}-blake`.'
    exit 1
fi

echo "WARNING: historical s3 data and Spark container images will be erased."
read -p "Are you sure? Type YES to confirm or any other character to exit: "

if [[ $REPLY =~ ^YES$ ]]; then
    source ../bootstrap/workflow/aws/lib/env.sh
    echo "BLAKE ~ deleting stateful Spark resources tied to $cluster cluster"

    aws ecr delete-repository --repository-name $cluster/spark --force
    aws s3 rb s3://$cluster-$REGION-delta-$ACCOUNT --force
fi

