#!/bin/bash
source ../bootstrap/app-init.sh

# Versions must be revised in 3 source files upon Spark upgrade:
# - charts/profile/default.yaml to adjust scala + hadoop packaged with Spark and corresponding aws sdk
# - charts/build/templates/dependencies.yaml for generic dependencies
# - charts/build/templates/build.yaml for uniswap spark-sql-kafka dependency
SPARK_VERSION=3.2.0
PG_VOLUME=$CLUSTER-metastore-postgresql-0

