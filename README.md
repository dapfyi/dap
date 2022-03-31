# DaP
DaP is an open platform to ingest, process and analyze Web3 data.

_Your launch base to engineer Web3 insights._

[ [Deployment](#deployment) ]

## Features
- __Tokenomics__ provided through built-in Uniswap integration. ([README](./spark/uniswap#dap-tokenomics) for explanation)
- __Embedded Blockchain__ makes DaP self-sufficient.
- __Data Pipeline__ from ingestion to vizualisation: you develop it, DaP builds and runs it.
- __SQL Analytics__ powered by [SparkUBI](./spark/sparkubi): precise off-chain calculations at scale on Spark engine.

*Next milestone*: deployment of Web3 data pipelines in a Paas fashion.

## Stack
DaP runs in AWS. It's been built on a Data Lakehouse architecture because distributed in-memory computations are faster and cheaper than RDBMS. Much of the development work has gone into the integration, specialization and automation of awesome open-source projects.

- DaP has been made possible by [K8s](https://github.com/kubernetes/kubernetes), [Geth](https://github.com/ethereum/go-ethereum), [Uniswap](https://uniswap.org/), [Airflow](https://github.com/apache/airflow), [Spark](https://github.com/apache/spark) & [Redash](https://github.com/getredash/redash). 

- It's been automated with tools like [CloudFormation](https://aws.amazon.com/cloudformation/), [eksctl](https://github.com/weaveworks/eksctl), [Argo CD](https://github.com/argoproj/argo-cd), [Kaniko](https://github.com/GoogleContainerTools/kaniko) & good old bash.

*Note*: all sources used under their own respective licenses.
> Should parts of this repo not already be covered by a parent project and despite significant exceptions (go-ethereum under GNU LGPLv3), DaP is governed by the Apache License 2.0 like most of its stack.
## Highlights
- **Infrastructure** - _You create or you delete, unless you develop._

In order to reduce maintenance, imperative configuration has been made immutable with system-wide blue-green deployment. It removes the need to manage state drift where declarative abstractions taking away some level of control do not work well, i.e. no time is spent handling updates. The system itself is immutable. Developement always happen on a clean slate and no environment is subpar.
- **Data Extraction** - _Scalable data lake feed._

Ingesting historical events from smart contracts scales with processors available to an integrated Ethereum client. Computing capacity is decoupled from blockchain state and can be resized on demand (`InstanceSize` parameter in Geth [template](./client/geth.yaml)). On the server side, Airflow workers required for orchestration and post-processing can be left entirely managed by K8s autoscaler.
- **Processing** - _Off-chain computation engine._

Apache Spark has been extended with a custom plugin enabling the seamless processing of big blockchain integers. The accurate valuation of transactions and tokens benefits from native Spark performance. See [SparkUBI](./spark/sparkubi/README.md) for more info.
- **Data Pipelines** - _coming soon_

## Deployment
WARNING: CICD is automatically active on main branch. To avoid hacks or unattended updates of processes with access to an Ethereum node, you are advised to fork this repo and change its reference URL with your own address before you deploy any app. You have several options in the given order of precedence: 
> 0) you can simply disable automated sync by exporting `DaP_SYNC`=`none` before install scripts;

Note: SYNC also supports _var_ and _default_ file configuration as described below for REPO; more info in [DaP](/DaP).
> 1) export `DaP_REPO`=`https://github.com/<my account>/dap.git` for transient configuration;
> 2) for local override outside version control: add your repo URL to a file called `var` in `DaP/live/REPO`;
> 3) edit DaP/live/REPO/[default](./DaP/live/REPO/default) to change the default repo in your fork.

By default, Argo CD will pull and apply live app changes from `https://github.com/dapfyi/dap.git`.

--------------------------------------------------------------------------------------------------

*Optional*: to set up app installs from a private repo before a cluster bootstrap,\
review configuration of `REPO/private/...` `PRIVATE` and `SSH_KEY_NAME` in [DaP](./DaP).\
You can always follow Argo CD [instructions](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/) to set up private repos later and manually.

0. **Requirements**: admin rights in the cloud + a bash shell with docker, argocd and aws clis configured locally.\
Run `aws configure` and specify region where DaP will be deployed or export `$AWS_PROFILE` to an existing configuration specified with `aws configure --profile <DaP AWS profile name>` if not default.

1. Create **Network** and deploy **Geth** node in this order from [client](./client) folder.

2. **K8s** provides computing capacity with autoscaling. Head to [bootstrap](./bootstrap) folder and run `./deploy.sh` to create a cluster ready for applications. Process should take around 20 minutes. You can run `./destroy.sh` to delete the cluster when computation isn't required. As a rule of thumb, state is externalized but applications are expected to be re-installed on any new cluster.

3. **Applications** to be installed on top of k8s are found in other modules. 3 scripts help to manage a release lifecycle from each top-level application folder. Make it your working directory to execute scripts:
- `./pre-install.sh` sets up dependencies and plugs in stateful resources that outlive a cluster.
- `./install.sh` delegates the job to Argo CD where you can follow in the UI (`localhost:8081` when redirecting port with `kubectl port-forward svc/argocd-server -n argocd 8081:443`).
- `./cleanup.sh` is only called at your discretion to delete dependencies created by pre-install outside k8s.

