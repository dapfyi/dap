# Blake

Blake is a platform to ingest, process and analyze DApp data.

- Built on aws as an integration between open-source projects: [K8s](https://github.com/kubernetes/kubernetes), [Geth](https://github.com/ethereum/go-ethereum), [Airflow](https://github.com/apache/airflow), [Spark](https://github.com/apache/spark) & [Redash](https://github.com/getredash/redash). 
- Fully automated with tools like [CloudFormation](https://aws.amazon.com/cloudformation/), [eksctl](https://github.com/weaveworks/eksctl), [Argo CD](https://github.com/argoproj/argo-cd), [Kaniko](https://github.com/GoogleContainerTools/kaniko) and good old bash.

Blake includes a [Uniswap](https://uniswap.org/) integration.
## Highlights
- **Infrastructure** - _You create or you delete, unless you develop._

In order to reduce maintenance, imperative configuration has been made immutable with system-wide blue-green deployment. It removes the need to manage state drift where declarative abstractions taking away some level of control do not work well, i.e. no time is spent handling updates. The system itself is immutable. Developement always happen on a clean slate and no environment is subpar.
- **Data Extraction** - _Scalable data lake feed._

Ingesting historical events from smart contracts scales with processors available to an integrated Ethereum client. Computing capacity is decoupled from blockchain state and can be resized on demand (`InstanceSize` parameter in Geth [template](./client/geth.yaml)). On the server side, Airflow workers required for orchestration and post-processing can be left entirely managed by K8s autoscaler.
- **Processing** - _Off-chain computation engine._

Apache Spark has been extended with a custom plugin enabling the seamless processing of big blockchain integers. The accurate valuation of transactions and tokens benefits from native Spark performance. See [SparkUBI](./spark/sparkubi/README.md) for more info.
- **Data Pipelines** - _coming soon_

## Deployment
WARNING: CICD is automatically active on main branch. To avoid hacks or unattended updates of processes with access to an Ethereum node, you are advised to fork this repo and change its URL in [app-init.sh](./bootstrap/app-init.sh), i.e. replace `REPO=https://github.com/d3centr/blake.git` by your own address before you deploy any app.

0. **Requirements**: admin rights in the cloud + a bash shell, docker and aws cli configured locally. Run `aws configure` and specify default region where Blake will be deployed.
1. Create **Network** and deploy **Geth** node in this order from [client](./client).
2. **K8s** provides computing capacity with autoscaling. Head to [bootstrap](./bootstrap) and run `./deploy.sh` to create a cluster ready for applications. Process should take a half hour. You can run `./destroy.sh` to delete the cluster when computation isn't required. As a rule of thumb, state is externalized but applications are expected to be re-installed on any new cluster.
3. **Applications** to be installed on top of k8s are found in other modules. 3 scripts help to manage a release lifecycle from each top-level application folder. Make it your working directory to execute scripts:
- `./pre-install.sh` sets up dependencies and plugs in stateful resources that outlive a cluster.
- `./install.sh` delegates the job to argocd where you can follow in the UI (`localhost:8081` when redirecting port with `kubectl port-forward svc/argocd-server -n argocd 8081:443`).
- `./cleanup.sh` is only called at your discretion to delete dependencies created by pre-install outside k8s.

