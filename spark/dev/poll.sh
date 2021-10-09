#!/bin/bash
app=${1///}
labels=spark-role=executor,app=$app

pods () { kubectl top pod -n spark -l $labels --use-protocol-buffers;}

nodes () { 
    nodes=`kubectl get pod -n spark -l $labels \
        -o=jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq`

    for node in $nodes; do 
        kubectl top node $node --use-protocol-buffers
    done
}

while true; do 
    pods
    pods
    pods
    pods
    pods
    echo
    nodes
    echo
done

