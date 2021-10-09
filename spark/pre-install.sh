#!/bin/bash
source init.sh
build_base_image=${1:-false}

echo 'BLAKE ~ running Spark pre-install'

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: spark
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark
  namespace: spark
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spark
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: spark
  namespace: spark
EOF


# Create global environment variables in spark namespace.
kubectl apply view-last-applied configmap -n default env -o yaml | \
    sed 's/namespace: default/namespace: spark/' | \
    kubectl apply -f -


# Create docker registry and sink bucket.
spark_repo=$CLUSTER/spark
aws ecr describe-repositories --repository-names $spark_repo ||
    aws ecr create-repository --repository-name $spark_repo

delta_bucket=$CLUSTER-$REGION-delta-$ACCOUNT
aws s3api head-bucket --bucket $delta_bucket || aws s3 mb s3://$delta_bucket
echo "s3://$delta_bucket"


# Build base Spark image.
if [ $build_base_image = true ]; then
    spark_path=/tmp/spark-$SPARK_VERSION

    kubectl delete -n spark job/spark-base-build --ignore-not-found
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: spark-base-build
  namespace: spark
spec:
  template:
    metadata:
      name: spark-base-build
    spec:
      restartPolicy: Never
      containers:
      - name: spark-base-build
        image: gcr.io/kaniko-project/executor:latest
        args:
        - --context=/mnt
        - --destination=$REGISTRY/spark:base
        volumeMounts:
        - name: dockerfile
          mountPath: /mnt
      volumes:
      - name: dockerfile
        configMap:
          name: base-dockerfile
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: base-dockerfile
  namespace: spark
data:
  Dockerfile: |
    # build Spark distribution from source
    FROM openjdk:11-jdk-slim AS dist

    RUN apt update && apt install -y curl && rm -rf /var/cache/apt/*

    RUN curl -L -o $spark_path.tar.gz https://github.com/apache/spark/archive/v$SPARK_VERSION.tar.gz && \
        tar xzvf $spark_path.tar.gz -C /tmp

    RUN export MAVEN_OPTS="-Xss64m -Xmx2g -XX:ReservedCodeCacheSize=1g" && \
        $spark_path/dev/make-distribution.sh --name blake-dist \
            -Phive \
            -Phive-thriftserver \
            -Pkubernetes

    # base Spark image referencing artefacts built above
    FROM openjdk:11-jre-slim

    RUN set -ex && \
        sed -i 's/http:\/\/deb.\(.*\)/https:\/\/deb.\1/g' /etc/apt/sources.list && \
        apt-get update && \
        ln -s /lib /lib64 && \
        apt install -y bash tini libc6 libpam-modules krb5-user libnss3 procps && \
        mkdir -p /opt/spark && \
        mkdir -p /opt/spark/examples && \
        mkdir -p /opt/spark/work-dir && \
        touch /opt/spark/RELEASE && \
        rm /bin/sh && \
        ln -sv /bin/bash /bin/sh && \
        echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
        chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
        rm -rf /var/cache/apt/*

    COPY --from=dist $spark_path/dist/jars /opt/spark/jars
    COPY --from=dist $spark_path/dist/bin /opt/spark/bin
    COPY --from=dist $spark_path/dist/sbin /opt/spark/sbin
    COPY --from=dist $spark_path/dist/kubernetes/dockerfiles/spark/entrypoint.sh /opt/
    COPY --from=dist $spark_path/dist/kubernetes/dockerfiles/spark/decom.sh /opt/
    COPY --from=dist $spark_path/dist/kubernetes/tests /opt/spark/tests
    
    ENV SPARK_HOME /opt/spark
    
    WORKDIR /opt/spark/work-dir
    RUN chmod g+w /opt/spark/work-dir
    RUN chmod a+x /opt/decom.sh
    
    ENTRYPOINT [ "/opt/entrypoint.sh" ]
    
    USER 185
EOF

    sleep 5
    kubectl attach -n spark job/spark-base-build

else 
    echo "BLAKE ~ skipping Spark base build: run './pre-install.sh true' to update"
fi


echo 'BLAKE ~ stateful Spark resources provisioned'

