#!/bin/bash

authenticate_with_last_cluster_created () {

    local clusters=`aws eks list-clusters --query clusters --output text --no-paginate | \
        egrep -o '(blue|green)-blake'`

    local creation_times=`for cluster in $clusters; do 
        aws eks describe-cluster --name $cluster --query cluster.[name,createdAt] --output text; done`

    local last_cluster_created=`echo "$creation_times" | sort -V | tail -1 | cut -f1`

    aws eks update-kubeconfig --name $last_cluster_created 

}

