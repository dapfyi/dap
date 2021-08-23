#!/bin/bash

cluster=$1
if [ -z $cluster ]; then 
    echo 'Cluster name argument is missing, e.g. run `./cleanup.sh {blue|green}-blake`.'
    exit 1
fi

echo "WARNING: historical s3 data, container images and dag run records will be erased." 
read -p "Are you sure? Type YES to confirm or any other character to exit: "

if [[ $REPLY =~ ^YES$ ]]; then

    source ../bootstrap/workflow/aws/lib/env.sh
    echo "BLAKE ~ deleting stateful Airflow resources tied to $cluster cluster"

    airflow_bucket=$cluster-$REGION-airflow-$ACCOUNT
    data_bucket=$cluster-$REGION-data-$ACCOUNT
    postgresql_volume_id=`aws ec2 describe-volumes \
        --filters Name=tag:Name,Values=$cluster-airflow-postgresql-0 --query Volumes[*].VolumeId --output text`
    
    aws ecr delete-repository --repository-name $cluster/airflow --force
    aws s3 rb s3://$airflow_bucket --force
    aws s3 rb s3://$data_bucket --force
    aws ec2 delete-volume --volume-id $postgresql_volume_id
    echo "ebs volume $cluster-airflow-postgresql-0 deleted"

fi

