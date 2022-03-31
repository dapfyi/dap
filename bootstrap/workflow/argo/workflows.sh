#!/bin/bash

helm repo add argo https://argoproj.github.io/argo-helm
helm install --namespace argo --create-namespace \
    --set server.extraArgs={--auth-mode=server} \
    --set workflow.serviceAccount.create=true wf argo/argo-workflows

