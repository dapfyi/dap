#!/bin/bash
source init.sh

## Create stateful Airflow resources when not available.

# Idempotent Airflow components are synchronized by Argo CD.
# Resources below have their own lifecycle due to external parameters or historical data.
# See airflow/cleanup.sh to delete aws resources AND data (at your discretion).

echo 'BLAKE ~ running Airflow pre-install'


# Create global environment variables in airflow namespace.
kubectl apply view-last-applied configmap -n default env -o yaml | \
    sed 's/namespace: default/namespace: airflow/' | \
    kubectl apply -f -


# Provision volume for Airflow records outside shorter-lived k8s clusters.
postgresql_volume=$CLUSTER-airflow-postgresql-0
postgresql_volume_size=4

postgresql_volume_id=`aws ec2 describe-volumes \
    --filters Name=tag:Name,Values=$postgresql_volume --query Volumes[*].VolumeId --output text`

postgresql_volume_count=`echo $postgresql_volume_id | wc -w`

if [ $postgresql_volume_count -eq 0 ]; then

    postgresql_volume_id=`aws ec2 create-volume \
        --availability-zone "$REGION"a \
        --size $postgresql_volume_size \
        --volume-type gp3 \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$postgresql_volume}]" \
        --query VolumeId \
        --output text`

elif [ $postgresql_volume_count -gt 1 ]; then

    echo "BLAKE ~ expected less than 2 ebs volumes named $postgresql_volume"
    exit 1

fi

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgresql-0
spec:
  capacity: 
    storage: ${postgresql_volume_size}Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    name: postgresql-0
    namespace: airflow
  awsElasticBlockStore:
    volumeID: $postgresql_volume_id
    fsType: xfs
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-0
  namespace: airflow
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${postgresql_volume_size}Gi
  volumeName: postgresql-0
EOF


# Create docker registry and buckets.
airflow_repo=$CLUSTER/airflow
aws ecr describe-repositories --repository-names $airflow_repo ||
    aws ecr create-repository --repository-name $airflow_repo

airflow_bucket=$CLUSTER-$REGION-airflow-$ACCOUNT
aws s3api head-bucket --bucket $airflow_bucket || aws s3 mb s3://$airflow_bucket
echo "s3://$airflow_bucket"

data_bucket=$CLUSTER-$REGION-data-$ACCOUNT
aws s3api head-bucket --bucket $data_bucket || aws s3 mb s3://$data_bucket
echo "s3://$data_bucket"


# Build base Airflow image to decouple from dag updates in automated build.
# This will speed up development feedback loops through CICD.
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: airflow-base-image-build
  namespace: airflow
spec:
  template:
    metadata:
      name: airflow-base-image-build
    spec:
      restartPolicy: Never
      containers:
      - name: airflow-base-image-build
        image: gcr.io/kaniko-project/executor:latest
        args:
        - --context=/mnt
        - --destination=$REGISTRY/airflow:base
        volumeMounts:
        - name: dockerfile
          mountPath: /mnt
      volumes:
      - name: dockerfile
        configMap:
          name: airflow-base-dockerfile
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-base-dockerfile
  namespace: airflow
data:
  Dockerfile: |
    FROM apache/airflow:$AIRFLOW_VERSION

    USER root
    RUN apt-get update && apt-get install -y git gcc && rm -rf /var/lib/apt/lists/*

    USER airflow
    RUN pip install web3
    RUN echo "AUTH_ROLE_PUBLIC = 'Admin'" >> /opt/airflow/webserver_config.py

    ENV AWS_DEFAULT_REGION $REGION
EOF

build_status () { 

    kubectl get job -n airflow airflow-base-image-build \
        -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'

}

timeout=0
echo 'BLAKE ~ tracking base image build status'
until build_status | grep -q ^True$; do
    sleep 2
    ((timeout+=2))
    if [ $timeout -ge 180 ]; then
        echo 'BLAKE ~ base image build timed out'
        exit 1
    fi
done

echo 'BLAKE ~ base image build completed in '$timeout's'
kubectl delete job -n airflow airflow-base-image-build


echo 'BLAKE ~ stateful Airflow resources provisioned'

