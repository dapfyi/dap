#!/bin/bash
source ../bootstrap/app-init.sh

url=https://raw.githubusercontent.com/fluent/fluent-bit-kubernetes-logging/master
kubectl apply -f $url/fluent-bit-service-account.yaml
kubectl apply -f $url/fluent-bit-role.yaml
kubectl apply -f $url/fluent-bit-role-binding.yaml

export LOG_BUCKET=`kubectl apply view-last-applied cm -n logging env |
    awk '$1~/LOG_BUCKET/{print $NF}'`

envsubst '$LOG_BUCKET $REGION' < configmap.yaml | kubectl apply -f -

export IMAGE=`aws ssm get-parameters-by-path \
    --path /aws/service/aws-for-fluent-bit \
    --query "Parameters[?Name=='/aws/service/aws-for-fluent-bit/stable'].Value" \
    --output text`

envsubst '$IMAGE' < daemonset.yaml | kubectl apply -f -

