#!/bin/bash

# Provision persistent and idempotent volume in shorter-lived k8s clusters.
persistent_volume () {
    local volume=$1
    local volume_size=$2
    local namespace=$3

    local volume_id=`aws ec2 describe-volumes \
        --filters Name=tag:Name,Values=$volume --query Volumes[*].VolumeId --output text`
    
    local volume_count=`echo $volume_id | wc -w`
    
    if [ $volume_count -eq 0 ]; then
    
        local volume_id=`aws ec2 create-volume \
            --availability-zone "$REGION"a \
            --size $volume_size \
            --volume-type gp3 \
            --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$volume}]" \
            --query VolumeId \
            --output text`
    
    elif [ $volume_count -gt 1 ]; then
    
        echo "BLAKE ~ expected less than 2 ebs volumes named $volume" >&2
        exit 1
    
    fi

    cat <<- EOF | kubectl apply -f -
	apiVersion: v1
	kind: PersistentVolume
	metadata:
	  name: $volume
	spec:
	  capacity: 
	    storage: ${volume_size}Gi
	  accessModes:
	    - ReadWriteOnce
	  persistentVolumeReclaimPolicy: Retain
	  claimRef:
	    name: $volume
	    namespace: $namespace
	  awsElasticBlockStore:
	    volumeID: $volume_id
	    fsType: xfs
	---
	apiVersion: v1
	kind: PersistentVolumeClaim
	metadata:
	  name: $volume
	  namespace: $namespace
	spec:
	  accessModes:
	    - ReadWriteOnce
	  resources:
	    requests:
	      storage: ${volume_size}Gi
	  volumeName: $volume
	EOF

}

