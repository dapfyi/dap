#!/bin/bash
#
# Manual run:
# lib_path=workflow/aws/lib
# source $lib_path/profile-configuration.sh
# source $lib_path/runtime.sh
# run_workflow dap-bootstrap 'argo/CD.sh blue'
color=$1
aws eks update-kubeconfig --name $color-dap

kubectl apply -f argo/namespace.yaml
kubectl apply -k argo

# detect eventual authentication for private repository of applications
source ../DaP/load_ENV.sh
: ${DaP_REPO:=`env_path DaP/$DaP_ENV/REPO`}
: ${DaP_PRIVATE:=`env_path DaP/$DaP_ENV/REPO/private/PRIVATE`}
: ${DaP_SSH_KEY_NAME:=`env_path DaP/$DaP_ENV/REPO/private/SSH_KEY_NAME`}
printf "\nDaP ~ CICD origin $DaP_REPO configured; private? $DaP_PRIVATE.\n\n"

[ $DaP_PRIVATE = false ] ||
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $DaP_REPO
  sshPrivateKey: |
    `cat /root/.dap/$DaP_SSH_KEY_NAME`
EOF

