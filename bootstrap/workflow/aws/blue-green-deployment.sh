#!/bin/bash
set -euo pipefail

source aws/lib/env.sh
source tests.sh


## Determine new cluster color according to blue-green deployment workflow.
clusters=`eksctl get cluster`

if echo $clusters | egrep -q 'No clusters? found'; then

    echo "BLAKE ~ no cluster found"
    old=none
    export new=blue

elif [ `echo "$clusters" | egrep 'blue-blake|green-blake' | wc -l` -gt 1 ]; then

    echo 'BLAKE ~ Skipping cluster creation: found more than a running colored cluster in region.'
    exit 1

elif echo $clusters | grep -q blue-blake; then

    echo "BLAKE ~ blue cluster found"
    old=blue
    export new=green

elif echo $clusters | grep -q green-blake; then

    echo "BLAKE ~ green cluster found"
    old=green
    export new=blue

elif [ -z $new ]; then

    echo "BLAKE ~ Issue encountered determining new cluster color: debug if statements in $0."
    exit 1

fi


## Create Kubernetes cluster.
echo "BLAKE ~ creating $new cluster"

# Variables interpolated by envsubst in json policy must be exported beforehand, e.g. export new=color. 
cat aws/iam/node-policy.json | envsubst | 
    aws iam create-policy --policy-name $new-blake-node --policy-document file:///dev/stdin

policies="
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
        - arn:aws:iam::$AWS_ACCOUNT:policy/$new-blake-node
      withAddonPolicies:
        autoScaler: true
        imageBuilder: true
"

cluster_definition="
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig
  
  metadata:
    name: $new-blake
    region: $REGION
  availabilityZones: ["$REGION"a, "$REGION"b]
  iam:
    withOIDC: true

  managedNodeGroups:
  - name: large-spot-a
    availabilityZones: ["$REGION"a]
    # ARM64 architecture, e.g. m6g and m6gd instances, not supported in bitnami charts, yet: 
    # see https://github.com/bitnami/charts/issues/7040.
    instanceTypes: ['m5.large', 'm5d.large']
    spot: true
    desiredCapacity: 1
    minSize: 0
    maxSize: 3
    iam: $policies
    volumeSize: 8
  - name: xlarge-spot-a
    availabilityZones: ["$REGION"a]
    instanceTypes: ['m5.xlarge', 'm5d.xlarge']
    spot: true
    desiredCapacity: 0
    minSize: 0
    maxSize: 2
    iam: $policies
    volumeSize: 8
"

echo "$cluster_definition" | eksctl create cluster -f /dev/stdin --dry-run
echo "$cluster_definition" | eksctl create cluster -f /dev/stdin


## Deploy cluster autoscaler.
echo "BLAKE ~ autoscaler deployment"

aws iam create-policy \
    --policy-name $new-blake-cluster-autoscaler \
    --policy-document file://aws/iam/cluster-autoscaler-policy.json

eksctl create iamserviceaccount \
    --cluster=$new-blake \
    --namespace=kube-system \
    --name=cluster-autoscaler \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT:policy/$new-blake-cluster-autoscaler \
    --override-existing-serviceaccounts \
    --approve

cluster_version=`kubectl version --short=true | grep -oP '(?<=Server Version: v)[0-9]+\.[0-9]+'`
autoscaler_version=`curl https://api.github.com/repos/kubernetes/autoscaler/tags?per_page=100 | \
    grep -oP "(?<=\"name\": \"cluster-autoscaler-)$cluster_version\.[0-9]+" | \
    head -1`

# Do not add in application layer, e.g. Argo CD.
# Autoscaler should be part of infrastructure layer for app dependencies on compute capacity.
helm install \
    --namespace=kube-system \
    --set clusterName=$new-blake,imageVersion=$autoscaler_version \
    cluster-autoscaler ./aws/helm/cluster-autoscaler

scale_out_test


## Deploy metrics server.

# Metrics server enables kubectl top command. It can help to manage resources on cluster autoscaler.
# Example memory limit in autoscaler git repo was too tight at bootstrap: bumped up from 300 to 500Mi.

echo "BLAKE ~ metrics server deployment"

ms_version=`curl https://api.github.com/repos/kubernetes-sigs/metrics-server/tags | \
    grep -oP '(?<="name": "v)[0-9.]+' | \
    head -1`

kubectl apply \
    -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v$ms_version/components.yaml


## Deploy Argo CD.
echo "BLAKE ~ Argo CD deployment"
kubectl create namespace argocd

apply_argo () {

    kubectl apply \
        -n argocd \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

}

# retry in case of failed client connection on large k8s manifest
apply_argo || apply_argo

kubectl patch deploy argocd-server \
    -n argocd \
    -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]' \
    --type json


## Delete previous cluster release, if any.
echo "BLAKE ~ Deleting previous cluster release, if any."
[ $old = none ] || aws/cleanup.sh $old-blake

