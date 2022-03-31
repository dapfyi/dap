#!/bin/bash
source init.sh

argocd app create airflow \
    --repo $DaP_REPO \
    --revision $DaP_BRANCH \
    --path airflow \
    --dest-namespace airflow \
    --dest-server https://kubernetes.default.svc \
    --sync-policy $DaP_SYNC \
    --self-heal \
    --auto-prune \
    -p airflow.airflowVersion=$AIRFLOW_VERSION \
    -p airflow.defaultAirflowRepository=$REGISTRY/airflow \
    -p airflow.dags.gitSync.repo=$DaP_REPO \
    -p airflow.dags.gitSync.branch=$DaP_BRANCH \
    -p airflow.config.logging.remote_base_log_folder=s3://$CLUSTER-$REGION-airflow-$ACCOUNT \
    -p airflow.postgresql.persistence.existingClaim=$PG_VOLUME

