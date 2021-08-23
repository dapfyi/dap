FROM debian:buster-20210621-slim
SHELL ["/bin/bash", "-o", "pipefail", "-e", "-u", "-x", "-c"]

ARG EKSCTL_VERSION=0.57.0
# See https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html + match k8s default version in eksctl with kubectl.
ARG KUBECTL_VERSION=1.20.4/2021-04-12

RUN apt-get update && apt-get install -y curl unzip gettext-base && rm -rf /var/lib/apt/lists/*

RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip && \
    unzip awscliv2.zip && ./aws/install && rm awscliv2.zip
ENV AWS_PAGER=

RUN curl -L https://github.com/weaveworks/eksctl/releases/download/$EKSCTL_VERSION/eksctl_`uname -s`_amd64.tar.gz | \
    tar xz -C /usr/local/bin

RUN curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/$KUBECTL_VERSION/bin/linux/amd64/kubectl && \
    curl -o kubectl.sha256 https://amazon-eks.s3.us-west-2.amazonaws.com/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256 && \
    [ `openssl sha1 -sha256 kubectl | awk '{print $2}'` = `awk '{print $1}' kubectl.sha256` ] && echo 'SHA-256 sums OK' || exit 1 && \
    chmod +x kubectl && mv kubectl /usr/local/bin

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

