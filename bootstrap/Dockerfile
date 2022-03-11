FROM debian:buster-20220228-slim
SHELL ["/bin/bash", "-o", "pipefail", "-e", "-u", "-x", "-c"]

# Watch out https://docs.aws.amazon.com/eks/latest/userguide/dockershim-deprecation.html next upgrade.
# Fluent Bit installation and parser configuration could be impacted:
# - rbac.authorization.k8s.io/v1beta1 ClusterRole -> v1 in 1.22+
# - rbac.authorization.k8s.io/v1beta1 ClusterRoleBinding -> v1 in v1.22+
# - from k8s 1.23, change docker Parser to cri in input-kubernetes.conf of Fluent Bit configmap
ARG EKSCTL_VERSION=0.86.0
# Match k8s default version in eksctl with kubectl (one minor version difference with cluster tolerated).
# 1. look for "DefaultVersion" (pkg/apis/eksctl.io/v1alpha5/types.go file) in github eksctl release commit
# 2. pick matching kubectl version among tags https://github.com/kubernetes/kubectl/tags and set below
ARG KUBECTL_VERSION=1.21.10
ENV KUBECTL_VERSION $KUBECTL_VERSION

# gettext-base installs envsubst command
RUN apt-get update && apt-get install -y curl unzip gettext-base && rm -rf /var/lib/apt/lists/*

RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip && \
    unzip awscliv2.zip && ./aws/install && rm awscliv2.zip
ENV AWS_PAGER=

RUN curl -L https://github.com/weaveworks/eksctl/releases/download/v$EKSCTL_VERSION/eksctl_Linux_amd64.tar.gz | \
    tar xz -C /usr/local/bin

RUN curl -LO https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

