#!/bin/bash
source aws/lib/env.sh

if [ -z $1 ]; then
    cluster=`eksctl get cluster | egrep -o 'blue-dap|green-dap'`
    if [ `echo "$cluster" | wc -l` -ne 1 ]; then
        echo "Found more or less than a single DaP cluster running: skipping script due to ambiguous dependencies."
        echo "Alternatively, pass explicit cluster name to destroy as a single argument."
        exit 1
    fi
else
    cluster=$1
fi

eksctl delete cluster --name $cluster

aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT:policy/$cluster-node
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT:policy/$cluster-cluster-autoscaler

