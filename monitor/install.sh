#!/bin/bash
source ../bootstrap/app-init.sh

ETH_IP=`kubectl apply view-last-applied cm -n monitor env |
    awk '$1~/ETHEREUM_IP/{print $NF}'`

argocd app create monitor \
    --repo $REPO \
    --revision $BRANCH \
    --path monitor \
    --dest-namespace monitor \
    --dest-server https://kubernetes.default.svc \
    --sync-policy auto \
    --self-heal \
    --auto-prune \
    -p ethIp=$ETH_IP \
    --helm-set-file grafana.dashboards.default.kubernetes.json=dashboards/kubernetes.json \
    --helm-set-file grafana.dashboards.default.spark.json=dashboards/spark.json \
    --helm-set-file grafana.dashboards.default.geth.json=dashboards/geth.json

