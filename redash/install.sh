#!/bin/bash
source init.sh

param_1="redash.postgresql.persistence.existingClaim=$PG_VOLUME"
param_2="secretPlaceholder=${1:-`echo dummy | base64`}"
argocd app create redash \
    --repo $REPO \
    --revision $BRANCH \
    --path redash \
    --dest-namespace redash \
    --dest-server https://kubernetes.default.svc \
    --sync-policy auto \
    --self-heal \
    --auto-prune \
    --config-management-plugin kustomized-helm \
    --plugin-env PLUGIN_ENV=$param_1,$param_2

# --set $PLUGIN_ENV is then added to `helm template` plugin command in argocd-cm

