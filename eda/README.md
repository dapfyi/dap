# Exploratory Data Analysis
environment and artifacts facilitating data mining from object storage
## Spark playground with Apache Zeppelin server on EMR
0. Make sure eda-persistence has been deployed, see cfn console; 

otherwise, run command below to create buckets storing notebooks and results: 

`./stack.sh -t eda-persistence.yaml -a create`.
1. Run `./stack.sh -a create -t mini-EMR.yaml` to create a single-node EMR cluster.
 
See `stack` script for options, most notably `--InstanceType` to scale up r5.xlarge default.

2. Install session manager plugin: [doc](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

3. Redirect ports to access UIs hosted on EMR. 

- `./port-forward.sh zeppelin` to access notebooks
- `./port-forward.sh ganglia` to monitor EMR resources

4. Decommission mini-EMR through cloudformation.

