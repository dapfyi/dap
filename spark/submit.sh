#!/bin/bash

## Runtime Configuration

# SparkUBI settings
PRECISION=200
SIMPLIFY=100
MIN_BITS=192
RESCALE=false  # overridden below in Aggregate class case
PROFILING=false

help () { echo "usage: ./submit.sh [-c config] <app name> <arg>";}

config=default
args=()  # positional arguments
while (( $# )); do
    case $1 in
        -c|--config) shift; config=$1;;
        -h|--help) shift; help; exit;;
        -*) echo "unknown $1 option" >&2; help; exit 1;;
        *) args+=( $1 );;
    esac
    shift
done

# make positional args the whole argument list to skip processed named args
set -- ${args[@]}

app=${1///}
source $app/config/$config
shell_jars="/opt/spark/work-dir/blake/spark/$app/target/scala-2.12/\*.jar"

if [ $2 = shell ]; then
    client=shell
    name=$app
    command=shell
    tag=$app-builder
    load="--jars $shell_jars"
elif [ $2 = script ]; then
    client=script
    name=$app-${3/_/-}
    command=shell
    tag=$app-builder
    load="-i /opt/spark/work-dir/blake/spark/$app/scripts/$3.scala --jars $shell_jars"
elif [ $2 = thrift ]; then
    client=thrift
    name=$app
    command=submit
    tag=$app
    load="--class org.apache.spark.sql.hive.thriftserver.HiveThriftServer2"
else
    client=submit
    command=submit
    tag=$app
    load="--class $class"

    if [[ $2 =~ ^[0-9]+$ ]]; then epoch=$2
    elif [[ $2 =~ ^[0-9]{4}(-[0-9]{2}){2}$ ]]; then agg_date=$2; fi

    case $class in
        blake.uniswap.Aggregate)
            name=$app-agg-${agg_date//-}
            RESCALE=true;;
        *) name=$app-$epoch;;
    esac    
fi

## Job

if [ -f /.dockerenv ]; then 
    echo "found /.dockerenv: submit will attempt to run on local k8s"
    stdin=false
else
    stdin=true
    echo "/.dockerenv wasn't found: authenticating with k8s outside container"
    # authenticate with cluster and export REGISTRY variable
    source `git rev-parse --show-toplevel`/bootstrap/app-init.sh
fi

DRIVER_PORT=35743
STATE_STORE=org.apache.spark.sql.execution.streaming.state.RocksDBStateStoreProvider
CATALOG=org.apache.spark.sql.delta.catalog.DeltaCatalog
env="
        - name: SPARKUBI_PRECISION
          value: \"$PRECISION\"
        - name: SPARKUBI_SIMPLIFY
          value: \"$SIMPLIFY\"
        - name: SPARKUBI_MIN_BITS
          value: \"$MIN_BITS\"
        - name: SPARKUBI_RESCALE
          value: \"$RESCALE\"
        - name: SPARKUBI_PROFILING
          value: \"$PROFILING\"
"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $name-$client
  namespace: spark
spec:
  clusterIP: None
  ports:
  - name: driver
    port: $DRIVER_PORT
    protocol: TCP
    targetPort: $DRIVER_PORT
  - name: ui
    port: 4040
    protocol: TCP
    targetPort: 4040
  - name: thrift
    port: 10000
    protocol: TCP
    targetPort: 10000
  selector:
    job-name: $name-$client
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $name-$client
  namespace: spark
data:
  submit.sh: |
    #!/bin/bash

    /opt/spark/bin/spark-$command \
        $load \
        --master k8s://https://kubernetes.default.svc.cluster.local:443 \
        --driver-memory $DRI_MEM \
        --num-executors $NUM_EXE \
        --executor-cores $EXE_COR \
        --executor-memory $EXE_MEM \
        --conf spark.driver.host=$name-$client.spark.svc.cluster.local \
        --conf spark.driver.port=35743 \
        --conf spark.kubernetes.namespace=spark \
        --conf spark.kubernetes.driver.pod.name=\$HOSTNAME \
        --conf spark.kubernetes.executor.label.app=$app \
        --conf spark.kubernetes.container.image=$REGISTRY/spark:$tag \
        --conf spark.kubernetes.container.image.pullPolicy=Always \
        --conf spark.hadoop.fs.s3.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
        --conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
        --conf spark.sql.catalog.spark_catalog=$CATALOG \
        --conf spark.sql.streaming.stateStore.providerClass=$STATE_STORE \
        --conf spark.kubernetes.executor.podTemplateFile=/mnt/pod-template.yaml \
        --conf spark.sql.extensions=d3centr.sparkubi.Extensions \
        --conf spark.sql.hive.thriftServer.singleSession=true \
        --conf spark.driver.blake.epoch=${epoch:-"-1"} \
        --conf spark.driver.blake.agg.date=${agg_date:-"0000-00-00"} \
        /opt/spark/jars/$app.jar

  pod-template.yaml: |
    spec:
      containers:
      - envFrom:
        - configMapRef:
            name: env
        env: $env
        resources:
          requests:
            ephemeral-storage: 6Gi
      tolerations:
      - key: spark
        operator: Equal
        value: exec
        effect: NoSchedule
---
apiVersion: batch/v1
kind: Job
metadata:
  name: $name-$client
  namespace: spark
spec:
  # 0 unless debugging
  ttlSecondsAfterFinished: 0
  template:
    metadata:
      name: $name-$client
    spec:
      restartPolicy: Never
      serviceAccountName: spark
      containers:
      - name: $name-$client
        image: $REGISTRY/spark:$tag
        imagePullPolicy: Always
        args:
        - /mnt/submit.sh
        volumeMounts:
        - name: command
          mountPath: /mnt
        - name: conf
          mountPath: /opt/spark/conf
        stdin: $stdin
        tty: $stdin
        envFrom:
        - configMapRef:
            name: env
        env: $env
        resources:
          requests:
            memory: 1Gi
            cpu: 1
      volumes:
      - name: command
        configMap:
          name: $name-$client
          defaultMode: 0777
      - name: conf
        configMap:
          name: sparkubi-hive-site
EOF

## Garbage Collection

uid=`kubectl get job -n spark $name-$client -o jsonpath='{.metadata.uid}'`
ref='{"apiVersion":"batch/v1","kind":"Job","name":"'$name-$client'","uid":"'$uid'"}'

# set owner reference on dependent objects
patch='{"metadata":{"ownerReferences":['$ref']}}'
kubectl patch svc $name-$client -n spark -p $patch
kubectl patch cm $name-$client -n spark -p $patch

## Status

client_status () {
    local status=`kubectl get pod -n spark -l job-name=$name-$client \
        -o custom-columns=":status.phase" --no-headers`
    echo client pod $status
    [[ $status =~ ^(Running|Succeeded)$ ]]
}
until client_status; do sleep 2; done

if [ -f /.dockerenv ]; then
    kubectl attach -n spark job/$name-$client
elif [[ $client =~ ^(shell|script)$  ]]; then
    kubectl attach -in spark job/$name-$client
elif [ $client = submit ]; then
    kubectl logs -n spark job/$name-$client -f
fi

