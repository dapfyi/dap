#!/bin/bash
source ../bootstrap/app-init.sh

AIRFLOW_VERSION=2.1.2
kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -

