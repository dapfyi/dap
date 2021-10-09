#!/bin/bash
app=${1///}
labels=spark-role=executor,app=$app

kubectl logs -f -n spark -l $labels

