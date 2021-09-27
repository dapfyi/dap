# Exploratory Data Analysis
environment and artifacts facilitating data mining from object storage
## Spark playground with Apache Zeppelin server on EMR
0. Make sure eda-persistence has been deployed, see cfn console; 

otherwise, run command below to create buckets storing notebooks and results: 

`./stack.sh -t eda-persistence.yaml -a create`.
1. Run `./stack.sh -a create -t mini-EMR.yaml` to create a single-node EMR cluster.
 
See `stack` script for options, most notably `--InstanceType` to scale up m5.xlarge default.

2. Install session manager plugin: [doc](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

3. Redirect ports to access any UI hosted on EMR. 

Note the instance id from ec2 console or cli and start a session to access on localhost, e.g. 
```
instance_id=`aws ec2 describe-instances --output text \
    --filters Name=tag:Name,Values=mini-emr-default Name=instance-state-name,Values=running \
    --query Reservations[*].Instances[0].InstanceId`

aws ssm start-session --target $instance_id --document-name AWS-StartPortForwardingSession \
    --parameters portNumber=[8890],localPortNumber=[8890]
``` 
to access Zeppelin at `localhost:8890`.

4. Decommission mini-EMR through cloudformation.
