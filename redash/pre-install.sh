#!/bin/bash
source init.sh

echo 'BLAKE ~ running Redash pre-install'

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: redash
EOF

# Create global environment variables in redash namespace.
kubectl apply view-last-applied configmap -n default env -o yaml | \
    sed 's/namespace: default/namespace: redash/' | \
    kubectl apply -f -

# Provision volume for Redash persistence outside shorter-lived k8s clusters.
source ../bootstrap/workflow/aws/lib/persistent_volume.sh
persistent_volume $PG_VOLUME 8 redash

echo 'BLAKE ~ stateful Redash resources provisioned'

