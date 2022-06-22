# Script to gather debug information for troubleshooting a rook-ceph cluster.

1. All the pod logs from rook-ceph namespace in individual files.
2. Ceph command outputs for debugging the current state of the cluster.
3. Output of `# kubectl version`
4. All the Deployment YAMLs : `kubectl get -n rook-ceph deployments --output yaml`
5. Configmaps : `kubectl get configmap -n rook-ceph -oyaml`
6. Node related information : `kubectl get nodes` and `kubectl get nodes -oyaml`
7. rook-config-override ConfigMap : `kubectl -n rook-ceph get ConfigMap rook-config-override -o yaml`

Usage : `sh gather-logs.sh <-D>`  
`-D` : Optional command line argument to crank up the debug logging for rook-ceph cluster.