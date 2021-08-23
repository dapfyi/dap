### Blake is...
- a Blockchain Intelligence stack
- built on aws as an integration between open-sourced components
- made of k8s, geth, airflow, spark & superset
- fully automated with tools like cfn, eksctl, argocd, kaniko and good old bash
- the result of experiments and a playground for further experiments
- a R&D concept for demonstration purpose
### Blake isn't...
- a framework of new or planned features
### Deployment
WARNING: CICD is active by default on public main branch. To avoid any hack or unattended updates of processes with access to an Ethereum node, you are advised to fork this repo and change its URL in `bootstrap/app-init.sh`, i.e. replace `REPO=https://github.com/d3centr/blake.git` by your own address before you deploy any application.

_Do not hold the author responsible._

0. **Requirements**: admin rights in the cloud + a bash shell, docker and aws cli configured locally. Run `aws configure` and specify default region where Blake will be deployed.
1. **Network** and **Geth** have a common declarative interface: create before any other module from `client/geth.yaml`, see header comment for the cloudformation command. These components are either static or always running.
2. **K8s** provides computing capacity with autoscaling. Head to bootstrap module (top-level directory) and run `./deploy.sh` to create a cluster ready for applications. Process should take a half hour. You can run `./destroy.sh` to delete the cluster when computation isn't required anymore. As a rule of thumb, state is externalized but applications are expected to be re-installed on any new cluster.
3. **Applications** to be installed on top of k8s are found in other modules. 3 scripts help to manage a release lifecycle from each top-level application folder. Make it your working directory before you run local commands below.
- `./pre-install.sh` sets up missing dependencies and plugs in stateful resources that would typically outlive a cluster.
- `./install.sh` delegates the job to argocd where you can follow up in the UI (accessible on `localhost:8080` when redirecting port with `kubectl port-forward svc/argocd-server -n argocd 8080:443`).
- `./cleanup.sh` should only be called at your discretion to delete stateful dependencies created by pre-install outside k8s.
### Highlights
- **Infrastructure** - _You create or you delete, unless you develop._

Imperative configuration has been made immutable with system-wide blue-green deployment. This experiment attempts to reduce maintenance as it removes the need to manage state drift without declarative abstractions taking away some level of control, i.e. no time is spent handling updates across distributed systems and it's not outsourced either. The system itself is immutable. Developement always happen on a clean slate and no environment is subpar.
- **Ethereum client** - _Optimized node for low running costs._

Geth leverages spot instances and cold storage for ancient blocks.

