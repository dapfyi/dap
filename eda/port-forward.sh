#!/bin/bash

app=$1

if [[ ! $app =~ ^(zeppelin|ganglia|spark)$ ]]; then
  echo "single argument app must be one of: zeppelin, ganglia, spark"
  exit 1
fi

case $1 in
    zeppelin)
        portNumber=8890
        localPortNumber=8890
        log="Zeppelin available on localhost:8890"
        ;;
    ganglia)
        portNumber=80
        localPortNumber=8000
        log="Ganglia available on localhost:8000/ganglia"
        ;;
    spark)
        portNumber=18080
        localPortNumber=18080
        log="Spark HistoryServer available on localhost:18080"
        ;;
esac


instance_id=`aws ec2 describe-instances --output text \
    --filters Name=tag:Name,Values=mini-emr-default Name=instance-state-name,Values=running \
    --query Reservations[*].Instances[0].InstanceId`

echo
echo $log
aws ssm start-session --target $instance_id --document-name AWS-StartPortForwardingSession \
    --parameters portNumber=[$portNumber],localPortNumber=[$localPortNumber]

