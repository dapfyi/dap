#!/bin/bash
app=${1///}

# authenticate with cluster and export REGISTRY variable
source `git rev-parse --show-toplevel`/bootstrap/app-init.sh

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $app-sbt
  namespace: spark
spec:
  ttlSecondsAfterFinished: 0
  template:
    metadata:
      name: $app-sbt
    spec:
      restartPolicy: Never
      serviceAccountName: spark
      containers:
      - name: $app-sbt
        image: $REGISTRY/spark:$app-builder
        imagePullPolicy: Always
        workingDir: /opt/spark/work-dir/blake/spark 
        args:
        - /root/.sdkman/candidates/sbt/current/bin/sbt
        stdin: true
        tty: true
        resources:
          requests:
            memory: 6Gi
            cpu: 2900m
            ephemeral-storage: 1Gi
EOF

sbt_status () {
    local status=`kubectl get pod -n spark -l job-name=$app-sbt \
        -o custom-columns=":status.phase" --no-headers`
    echo sbt pod $status
    [ $status = Running ]
}
until sbt_status; do sleep 2; done

kubectl attach -itn spark job/$app-sbt ||
    echo "issue encountered while attaching sbt shell, retry:" &&
    echo "kubectl attach -itn spark job/$app-sbt"

