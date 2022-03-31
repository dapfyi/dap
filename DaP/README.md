# Configuration

**The selected set of configurations is under a single environment path defined by the ENV key.**

DaP supports three types of configuration in this order of precedence:
1. environment variable for transient configuration: export `DaP_<Key>`
2. local override outside version control:\
add value in a one-liner file called `var` under your configuration path (next to the `default` file to override)
3. edit `DaP/<Path>/<Key>/default` to commit a new default value in your fork

*example available below [Deployment](/README.md#deployment) warning in main README*

Path | Key | Values | Default | Description
--- | --- | --- | --- | ---
/ | ENV | `hack`, `demo` or `live` | `live` | configuration is read under the \<ENV> path of this variable
\<ENV> | BRANCH | remote branch name in REPO or `_local` to check the same branch as local git | `_local` | `argocd app create --revision` argument 
\<ENV> | REPO | URL of CD origin | `https://github.com/dapfyi/dap.git` | `argocd app create --repo` argument; a private repo requires a private SSH key and has a URL that typically starts with `git@` or `ssh://` rather than `https://`.
\<ENV>/REPO/private | PRIVATE | `true` or `false` | `false` | controls the configuration of private repo authentication at cluster bootstrap
\<ENV>/REPO/private | SSH_KEY_NAME | private key name in local `~/.dap` folder | `id_rsa` | SSH key to authenticate with private repo
\<ENV> | SYNC | `none` or `auto` | `auto` | `argocd app create --sync-policy` argument 

