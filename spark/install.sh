#!/bin/bash
source init.sh

profile=default
while (( $# )); do
    case $1 in
        -a|--app) shift; app=${1///};;
        -p|--profile) shift; profile=$1;;
        -*) echo "unknown $1 option" >&2; exit 1;;
    esac
    shift
done

gatekeeper='^(zeppelin|uniswap|sparkubi)$'
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
    exit 1
fi

echo "DaP ~ installing $DaP_BRANCH branch $app in $CLUSTER $namespace namespace"

p1="global.registry=$REGISTRY/spark"
p2="build.tag=$tag"
p3="build.repo=$DaP_REPO"
p4="build.branch=$DaP_BRANCH"
p5="build.sparkVersion=$SPARK_VERSION"
p6="postgresql.persistence.existingClaim=$PG_VOLUME"

argocd app create $app \
    --repo $DaP_REPO \
    --revision $DaP_BRANCH \
    --path spark/$app \
    --dest-namespace $namespace \
    --dest-server https://kubernetes.default.svc \
    --sync-policy $DaP_SYNC \
    --self-heal \
    --auto-prune \
    --config-management-plugin kustomized-helm \
    --plugin-env HELM_VALUES="
        ../charts/profile/default.yaml 
        ../charts/profile/$profile.yaml 
        values.yaml" \
    --plugin-env DYNAMIC_VAR=$p1,$p2,$p3,$p4,$p5,$p6

# --set $DYNAMIC_VAR added to helm plugin command in argocd-cm, similarly for ordered $HELM_VALUES

