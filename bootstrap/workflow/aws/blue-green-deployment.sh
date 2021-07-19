#!/bin/bash
set -e
source /opt/blake/tests.sh


# Determine new cluster color according to blue-green deployment workflow.
clusters=`eksctl get cluster`

if echo $clusters | egrep -q 'No clusters? found'; then

    echo "BLAKE ~ No cluster found."
    old=none
    new=blue

elif [ `echo "$clusters" | egrep 'blue-blake|green-blake' | wc -l` -gt 1 ]; then

    echo 'BLAKE ~ Skipping cluster creation: found more than a running colored cluster in region.'
    exit 1

elif echo $clusters | grep -q blue-blake; then

    echo "BLAKE ~ Blue cluster found."
    old=blue
    new=green

elif echo $clusters | grep -q green-blake; then

    echo "BLAKE ~ Green cluster found."
    old=green
    new=blue

elif [ -z $new ]; then

    echo "BLAKE ~ Issue encountered determining new cluster color: debug if statements in $0."
    exit 1

fi


# Create Kubernetes cluster.
echo "BLAKE ~ Creating $new cluster..."

region=`aws configure get region`

cluster_definition="
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig
  
  metadata:
    name: $new-blake
    region: $region
  availabilityZones: ["$region"a, "$region"b]
  iam:
    withOIDC: true

  managedNodeGroups:
  - name: large-spot-a
    availabilityZones: ["$region"a]
    instanceTypes: ['m6g.large', 'm6gd.large']
    spot: true
    desiredCapacity: 1
    minSize: 0
    maxSize: 3
    iam:
      withAddonPolicies:
        autoScaler: true
  - name: xlarge-spot-a
    availabilityZones: ["$region"a]
    instanceTypes: ['m6g.xlarge', 'm6gd.xlarge']
    spot: true
    desiredCapacity: 0
    minSize: 0
    maxSize: 2
    iam:
      withAddonPolicies:
        autoScaler: true
"

echo "$cluster_definition" | eksctl create cluster -f /dev/stdin --dry-run
echo "$cluster_definition" | eksctl create cluster -f /dev/stdin


# Deploy cluster autoscaler.
echo "BLAKE ~ Autoscaler Deployment."

aws_account=`aws sts get-caller-identity --query Account --output text`
autoscaler_policy=arn:aws:iam::$aws_account:policy/AmazonEKSClusterAutoscalerPolicy

aws iam get-policy --policy-arn $autoscaler_policy || \
    aws iam create-policy \
        --policy-name AmazonEKSClusterAutoscalerPolicy \
        --policy-document file://aws/iam/cluster-autoscaler-policy.json

eksctl create iamserviceaccount \
    --cluster=$new-blake \
    --namespace=kube-system \
    --name=cluster-autoscaler \
    --attach-policy-arn=$autoscaler_policy \
    --override-existing-serviceaccounts \
    --approve

cluster_version=`kubectl version --short=true | grep -oP '(?<=Server Version: v)[0-9]+\.[0-9]+'`
autoscaler_version=`curl https://api.github.com/repos/kubernetes/autoscaler/tags?per_page=100 | \
    grep -oP "(?<=\"name\": \"cluster-autoscaler-)$cluster_version\.[0-9]+" | \
    head -1`

helm install \
    --namespace=kube-system \
    --set clusterName=$new-blake,imageVersion=$autoscaler_version \
    cluster-autoscaler ./aws/helm/cluster-autoscaler

scale_out_test


# Deploy metrics-server.
echo "BLAKE ~ Metrics Server Deployment."

metrics_server_version=`curl https://api.github.com/repos/kubernetes-sigs/metrics-server/tags | \
    grep -oP '(?<="name": "v)[0-9.]+' | \
    head -1`

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v$metrics_server_version/components.yaml


# Delete previous cluster release.
echo "BLAKE ~ Deleting previous cluster release, if any."
[ $old = none ] || eksctl delete cluster --name $old-blake
