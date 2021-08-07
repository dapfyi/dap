#!/bin/bash
set -u
source ../bootstrap/workflow/aws/lib/env.sh

cluster=$1
bucket_name=$cluster-$REGION-airflow-$AWS_ACCOUNT

aws ecr delete-repository --repository-name $cluster/airflow --force
aws s3 rb s3://$bucket_name --force

