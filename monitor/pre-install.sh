#!/bin/bash
source ../bootstrap/app-init.sh

echo 'BLAKE ~ running monitor pre-install'

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: monitor
EOF

# Create global environment variables in monitor namespace.
kubectl apply view-last-applied configmap -n default env -o yaml | \
    sed 's/namespace: default/namespace: monitor/' | \
    kubectl apply -f -

echo 'BLAKE ~ stateful monitor resources provisioned'

