#!/bin/bash
source init.sh

help () { echo "usage: ./install.sh --app <app name>";}

profile=default
while (( $# )); do
    case $1 in
        -a|--app) shift; app=${1///};;
        -p|--profile) shift; profile=$1;;
        -h|--help) shift; help; exit;;
        -*) echo "unknown $1 option" >&2; exit 1;;
    esac
    shift
done

gatekeeper='^(zeppelin|uniswap|sparkubi|kafka)$'
if [[ $app =~ $gatekeeper ]]; then
    case $app in
        zeppelin) 
            namespace=default
            tag=uniswap;;
        *) 
            namespace=spark
            tag=$app;;
    esac
else
    echo "unknown '"$app"' app" >&2
    help
    exit 1
fi

echo "BLAKE ~ installing $BRANCH branch $app in $CLUSTER $namespace namespace"

export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd app create $app \
    --repo $REPO \
    --revision $BRANCH \
    --path spark/$app \
    --values ../charts/profile/default.yaml \
    --values ../charts/profile/$profile.yaml \
    --values values.yaml \
    --dest-namespace $namespace \
    --dest-server https://kubernetes.default.svc \
    --sync-policy auto \
    --self-heal \
    --auto-prune \
    -p registry=$REGISTRY/spark \
    -p tag=$tag \
    -p buffer.registry=$REGISTRY/spark \
    -p build.registry=$REGISTRY/spark \
    -p build.tag=$tag \
    -p build.repo=$REPO \
    -p build.branch=$BRANCH \
    -p build.sparkVersion=$SPARK_VERSION

