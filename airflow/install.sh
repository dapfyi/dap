#!/bin/bash
source init.sh

argocd app create airflow \
    --repo $REPO \
    --revision $BRANCH \
    --path airflow \
    --dest-namespace airflow \
    --dest-server https://kubernetes.default.svc \
    --sync-policy auto \
    --self-heal \
    --auto-prune \
    -p airflow.airflowVersion=$AIRFLOW_VERSION \
    -p airflow.defaultAirflowRepository=$REGISTRY/airflow \
    -p airflow.dags.gitSync.repo=$REPO \
    -p airflow.dags.gitSync.branch=$BRANCH \
    -p airflow.config.logging.remote_base_log_folder=s3://$CLUSTER-$REGION-airflow-$ACCOUNT \
    -p airflow.postgresql.persistence.existingClaim=$PG_VOLUME

