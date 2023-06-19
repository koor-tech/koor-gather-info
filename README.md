# Script to gather debug information for troubleshooting a rook-ceph cluster.

It collects the following information:

1. All the pod logs from Rook Ceph cluster and if separate operator namespace in individual files.
2. Ceph command outputs for debugging the current state of the cluster.
3. Output of `kubectl version`
4. All the Deployment YAMLs: `kubectl get -n rook-ceph deployments --output yaml`
5. Configmaps: `kubectl get configmap -n rook-ceph -oyaml`
6. Node related information: `kubectl get nodes` and `kubectl get nodes -oyaml`
7. `rook-config-override` ConfigMap: `kubectl -n rook-ceph get ConfigMap rook-config-override -o yaml`

## Prerequisites

* Requires Bash
* Currently only works with Rook Ceph clusters
* [Toolbox pod](https://rook.io/docs/rook/latest-release/Troubleshooting/ceph-toolbox/) must be running to collect some of the information needed by the debug script
* `kubectl` configured with access to the Kubernetes clusters running the Rook Ceph clusters

## Usage

```console
$ ./gather-info.sh -h
Usage: ./gather-info.sh [FLAGS]
Flags:
  -h - Show help menu.
  -d - Set Rook Ceph Operator and CSI log level to debug/trace.
  -n NAMESPACE - Rook Ceph Cluster namespace, default: 'rook-ceph' (CLUSTER_NAMESPACE).
  -o NAMESPACE - If the operator is run separately from the cluster, specify the namespace (OPERATOR_NAMESPACE).
  -t - Disable tar-ing the collected info to the current working dir.
```

The script creates a temp directory (`mktemp`) on the system prefixed with `gather-logs-`.

## Contributing

We use [`shellcheck`](https://www.shellcheck.net/) for linting and checking the scripts in this repository.
`shellcheck` is run by our CI process for any code changes to ensure the scripts are formatted properly.

Please open a pull request with code changes you want to make, thanks!
