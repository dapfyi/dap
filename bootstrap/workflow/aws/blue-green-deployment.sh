#!/bin/bash
set -euo pipefail
source aws/lib/env.sh

ETHEREUM_CLIENT=blake-geth

subnets=`aws cloudformation list-exports \
    --query "Exports[?starts_with(Name, 'blake-network-subnet-')].[Name,Value]" \
    --output text`
subnet_a=`echo "$subnets" | awk '$1~/subnet-a$/{print $2}'`
subnet_b=`echo "$subnets" | awk '$1~/subnet-b$/{print $2}'`


## Determine new cluster color according to blue-green deployment workflow.
clusters=`eksctl get cluster`

if echo $clusters | egrep -q 'No clusters? found'; then

    echo "BLAKE ~ no cluster found"
    old=none
    export new=blue
    other=green

elif [ `echo "$clusters" | egrep 'blue-blake|green-blake' | wc -l` -gt 1 ]; then

    echo 'BLAKE ~ Skipping cluster creation: found more than a running colored cluster in region.'
    exit 1

elif echo $clusters | grep -q blue-blake; then

    echo "BLAKE ~ blue cluster found"
    old=blue
    export new=green
    other=$old

elif echo $clusters | grep -q green-blake; then

    echo "BLAKE ~ green cluster found"
    old=green
    export new=blue
    other=$old

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
        - arn:aws:iam::$ACCOUNT:policy/$new-blake-node
      withAddonPolicies:
        autoScaler: true

"

cluster_definition="

  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig  
  metadata:
    name: $new-blake
    region: $REGION
  iam:
    withOIDC: true

  vpc:
    subnets:
      public:
        subnet-a:
          id: $subnet_a
        subnet-b:
          id: $subnet_b

  managedNodeGroups:

  - name: large-spot-a
    subnets: [$subnet_a]
    # ARM64 architecture, e.g. m6g and m6gd instances, not supported in bitnami charts, yet: 
    # see https://github.com/bitnami/charts/issues/7040.
    instanceTypes: ['m5.large', 'm5d.large', 'm5n.large']
    # keep volumeSize > 8 to avoid NodeHasDiskPressure
    volumeSize: 16
    spot: true
    desiredCapacity: 1
    minSize: 0
    maxSize: 7
    iam: $policies

  - name: xlarge-spot-a
    subnets: [$subnet_a]
    instanceTypes: ['m5.xlarge', 'm5d.xlarge', 'm5n.xlarge']
    volumeSize: 24
    spot: true
    desiredCapacity: 0
    minSize: 0
    maxSize: 4
    tags:
      # trigger autoscaling from 0 with ephemeral storage request
      # https://github.com/weaveworks/eksctl/issues/1571#issuecomment-785789833
      # manual propagation to ASG still required: see after cluster creation
      k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage: 24Gi
    iam: $policies

  - name: rxlarge-spot-a
    subnets: [$subnet_a]
    instanceTypes: ['r5.xlarge', 'r5d.xlarge', 'r5n.xlarge']
    volumeSize: 24
    spot: true
    desiredCapacity: 0
    minSize: 0
    maxSize: 5
    tags:
      k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage: 24Gi
    iam: $policies

"

echo "$cluster_definition" | eksctl create cluster -f /dev/stdin --dry-run
echo "$cluster_definition" | eksctl create cluster -f /dev/stdin

echo "BLAKE ~ tag propagation to autoscaling groups"
# could be automatically handled by AWS at some point
asg_propagation_tags="
    k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage
"
nodegroups=`aws eks list-nodegroups --cluster-name $new-blake --no-paginate \
    --query nodegroups --output text`
for ng in $nodegroups; do
    asg=`aws eks describe-nodegroup --cluster-name $new-blake --nodegroup-name $ng \
        --query nodegroup.resources.autoScalingGroups --output text`
    ng_tags=`aws eks describe-nodegroup --cluster-name $new-blake --nodegroup-name $ng \
        --query nodegroup.tags --output table | tr -d ' '`
    for tag in $asg_propagation_tags; do
        value=`echo "$ng_tags" | awk -F'|' '$2=="'$tag'"{print $3}'`
        aws autoscaling create-or-update-tags --tags \
            ResourceId=$asg,ResourceType=auto-scaling-group,Key=$tag,Value=$value,PropagateAtLaunch=true
    done
done

# Create global variables.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: env
  namespace: default
data:
  ETHEREUM_CLIENT: $ETHEREUM_CLIENT
  SUBNET_A: $subnet_a
  REGISTRY: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$new-blake
  DATA_BUCKET: $new-blake-$REGION-data-$ACCOUNT
  OTHER_DATA_BUCKET: $other-blake-$REGION-data-$ACCOUNT
  DELTA_BUCKET: $new-blake-$REGION-delta-$ACCOUNT
  OTHER_DELTA_BUCKET: $other-blake-$REGION-delta-$ACCOUNT
  KUBECTL_VERSION: $KUBECTL_VERSION
EOF


## Deploy cluster autoscaler.
echo "BLAKE ~ autoscaler deployment"

aws iam create-policy \
    --policy-name $new-blake-cluster-autoscaler \
    --policy-document file://aws/iam/cluster-autoscaler-policy.json

eksctl create iamserviceaccount \
    --cluster=$new-blake \
    --namespace=kube-system \
    --name=cluster-autoscaler \
    --attach-policy-arn=arn:aws:iam::$ACCOUNT:policy/$new-blake-cluster-autoscaler \
    --override-existing-serviceaccounts \
    --approve

cluster_version=`kubectl version --short=true | grep -oP '(?<=Server Version: v)[0-9]+\.[0-9]+'`
autoscaler_version=`curl -s https://api.github.com/repos/kubernetes/autoscaler/tags?per_page=100 | \
    grep -oP "(?<=\"name\": \"cluster-autoscaler-)$cluster_version\.[0-9]+" | \
    head -1`

# Do not add in application layer, e.g. Argo CD.
# Autoscaler should be part of infrastructure layer for app dependencies on compute capacity.
helm install \
    --namespace kube-system \
    --set clusterName=$new-blake,imageVersion=$autoscaler_version \
    cluster-autoscaler ./aws/helm/cluster-autoscaler


## Deploy metrics server (enables kubectl top command)

echo "BLAKE ~ metrics server deployment"

# install before last version to avoid the edge case where latest tag release isn't available, yet
ms_version=`curl -s https://api.github.com/repos/kubernetes-sigs/metrics-server/tags | \
    grep -oP '(?<="name": "v)[0-9.]+' | \
    head -2 | tail -1`

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

# Back off and retry in case of failed client connection during large manifest configuration.
apply_argo || { sleep 5 && apply_argo; }

kubectl patch deploy argocd-server \
    -n argocd \
    -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]' \
    --type json

cat <<EOF | kubectl patch configmap/argocd-cm -n argocd --type merge --patch-file /dev/stdin
data:
  configManagementPlugins: |
    - name: kustomized-helm
      init:
        command: ["/bin/sh", "-c"]
        args: ["helm dependency build"]
      generate:
        command: ["/bin/sh", "-c"]
        args: ["helm template . --name-template \$ARGOCD_APP_NAME --namespace \$ARGOCD_APP_NAMESPACE \
            \$(for v in \$HELM_VALUES; do printf -- '--values '\$v' '; done) \
            --set \$PLUGIN_ENV > all.yaml && kustomize build"]
EOF


## Deploy Argo Workflows.
echo "BLAKE ~ Argo Workflows deployment"

helm repo add argo https://argoproj.github.io/argo-helm
helm install --namespace argo --create-namespace \
    --set server.extraArgs={--auth-mode=server} \
    --set workflow.serviceAccount.create=true wf argo/argo-workflows


## Delete previous cluster release, if any.
echo "BLAKE ~ Deleting previous cluster release, if any."
[ $old = none ] || aws/cleanup.sh $old-blake

