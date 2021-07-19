#!/bin/bash

# Cloud provider agnostic tests sourced from deployment script:
# each test function returns its result in exit code propagating failure to parent script where -e has been set.

echo "BLAKE ~ loading infrastructure tests"

scale_out_test () {

    local live_nodes=`kubectl get nodes -o name | wc -l`
    
    local allocatable=`kubectl get nodes -o=jsonpath="{.items[*].status.allocatable.memory}" | \
        tr ' ' '\n' | sort -r | head -1`
    
    local free_mem_unit=`echo $allocatable | egrep -o '[a-zA-Z]+'`
    local free_mem_amount=`echo $allocatable | egrep -o '[0-9]+'`
   
    kubectl run \
        --requests="memory=$((free_mem_amount + 1))$free_mem_unit" \
        --image=busybox \
        --restart=Never \
        scale-out-test echo 'This pod requested memory beyond live node capacity.'
    echo "BLAKE ~ Autoscaler Test: scale-out-test pod requested memory beyond live node capacity." 

    timeout=0
    echo 'BLAKE ~ Autoscaler Test: 5mn timeout for cluster to scale out.'
    while [ `kubectl get pod scale-out-test -o jsonpath='{.status.phase}'` != Succeeded ] && [ $timeout -lt 300 ]; do
        sleep 10
        ((timeout+=10))
    done

    [ `kubectl get nodes -o name | wc -l` -gt $live_nodes ]
    local exit_status=$?
    echo "BLAKE ~ Autoscaler Test: $exit_status exit code in $timeout seconds."

    return $exit_status

}

