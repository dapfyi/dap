#!/bin/bash
source init.sh

param_1="redash.postgresql.persistence.existingClaim=$PG_VOLUME"
param_2="secretPlaceholder=${1:-`echo dummy | base64`}"
argocd app create redash \
    --repo $DaP_REPO \
    --revision $DaP_BRANCH \
    --path redash \
    --dest-namespace redash \
    --dest-server https://kubernetes.default.svc \
    --sync-policy $DaP_SYNC \
    --self-heal \
    --auto-prune \
    --config-management-plugin kustomized-helm \
    --plugin-env DYNAMIC_VAR=$param_1,$param_2

# --set $DYNAMIC_VAR is then added to `helm template` plugin command in argocd-cm

