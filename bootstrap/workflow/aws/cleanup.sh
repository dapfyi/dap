#!/bin/bash
set -e

clusters=`eksctl get cluster | egrep -o 'blue-blake|green-blake'`
if [ `echo "$clusters" | wc -l` -ne 1 ]; then
    echo "Found more or less than a single blake cluster running: skipping script due to ambiguous dependencies."
    exit 1
fi
eksctl delete cluster --name $clusters

aws_account=`aws sts get-caller-identity --query Account --output text`
aws iam delete-policy --policy-arn arn:aws:iam::$aws_account:policy/AmazonEKSClusterAutoscalerPolicy
