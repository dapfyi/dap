#!/bin/bash
source init.sh

## Create stateful Airflow resources when not available.

# Idempotent Airflow components are synchronized by Argo CD.
# Resources below have their own lifecycle due to external parameters or historical data.
# See airflow/cleanup.sh to delete aws resources AND data (at your discretion).

echo 'BLAKE ~ running Airflow pre-install'

kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -


# Create global environment variables in airflow namespace.
kubectl apply view-last-applied configmap -n default env -o yaml | \
    sed 's/namespace: default/namespace: airflow/' | \
    kubectl apply -f -


# Provision volume for Airflow records outside shorter-lived k8s clusters.
source ../bootstrap/workflow/aws/lib/persistent_volume.sh
persistent_volume $PG_VOLUME 8 airflow


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
  name: airflow-base-build
  namespace: airflow
spec:
  template:
    metadata:
      name: airflow-base-build
    spec:
      restartPolicy: Never
      containers:
      - name: airflow-base-build
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
    RUN apt-get update && \
        apt-get install -y git gcc vim && \
        rm -rf /var/lib/apt/lists/*

    USER airflow
    RUN pip install web3 pyarrow s3fs mmh3
    RUN git clone --single-branch --depth 1 \
        --branch main https://github.com/Uniswap/uniswap-v3-subgraph.git
    RUN echo "AUTH_ROLE_PUBLIC = 'Admin'" >> /opt/airflow/webserver_config.py

    ENV AWS_DEFAULT_REGION $REGION
EOF

sleep 2
kubectl attach -n airflow job/airflow-base-build
kubectl delete job -n airflow airflow-base-build


echo 'BLAKE ~ stateful Airflow resources provisioned'

