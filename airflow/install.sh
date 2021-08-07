#!/bin/bash
set -euo pipefail
source ../bootstrap/workflow/aws/lib/cluster-authentication.sh
branch=${1:-main}

REPO=https://github.com/d3centr/blake.git

authenticate_with_last_cluster_created
read REGION ACCOUNT CLUSTER <<< `kubectl config current-context | awk -F'[:/]' '{print $4,$5,$NF}'`

kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -

export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd repo add https://airflow.apache.org --type helm --name apache-airflow
argocd app create airflow \
    --repo $REPO \
    --revision $branch \
    --path airflow \
    --dest-namespace airflow \
    --dest-server https://kubernetes.default.svc \
    --sync-policy auto \
    --self-heal \
    --auto-prune \
    -p region=$REGION \
    -p clusterName=$CLUSTER \
    -p airflow.defaultAirflowRepository=$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$CLUSTER/airflow \
    -p airflow.dags.gitSync.repo=$REPO \
    -p airflow.dags.gitSync.branch=$branch \
    -p airflow.config.logging.remote_base_log_folder=s3://$CLUSTER-$REGION-airflow-$ACCOUNT

