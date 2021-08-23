#!/bin/bash
source init.sh

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
    -p airflow.airflowVersion=$AIRFLOW_VERSION \
    -p airflow.defaultAirflowRepository=$REGISTRY/airflow \
    -p airflow.dags.gitSync.repo=$REPO \
    -p airflow.dags.gitSync.branch=$branch \
    -p airflow.config.logging.remote_base_log_folder=s3://$CLUSTER-$REGION-airflow-$ACCOUNT

