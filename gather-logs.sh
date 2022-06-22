#!/bin/sh

CLUSTER_NAMESPACE="${CLUSTER_NAMESPACE:-rook-ceph}"
OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-}"

gatherKubernetesPodLogs() {
    mkdir -p logs

    for p in $(kubectl -n "${CLUSTER_NAMESPACE}" get pods -o jsonpath='{.items[*].metadata.name}'); do
        for c in $(kubectl -n "${CLUSTER_NAMESPACE}" get pod "${p}" -o jsonpath='{.spec.containers[*].name}'); do
            echo "BEGIN logs from pod: ${p} ${c}"
            kubectl -n "${CLUSTER_NAMESPACE}" logs -c "${c}" "${p}" > "logs/${p}-${c}"
            echo "END logs from pod: ${p} ${c}"
        done
    done
}

gatherKubernetesObjects() {
    # shellcheck disable=SC2094
    kubectl get -n "${CLUSTER_NAMESPACE}" deployments --output yaml > deployments
    # Gather info from operator namespace if it is run separately
    [ "${CLUSTER_NAMESPACE}" != "${OPERATOR_NAMESPACE}" ] && \
        kubectl get -n "${OPERATOR_NAMESPACE}" deployments --output yaml > deployments-operator

    kubectl -n "${CLUSTER_NAMESPACE}" get configmap --output yaml > configmaps
    [ "${CLUSTER_NAMESPACE}" != "${OPERATOR_NAMESPACE}" ] && \
        kubectl -n "${OPERATOR_NAMESPACE}" get configmap --output yaml > configmaps

    kubectl -n "${CLUSTER_NAMESPACE}" get configmaps rook-config-override --output yaml > configmap_rook-config-override

    kubectl version > kubectl_version
    kubectl get nodes > kubectl_get-nodes
    kubectl get nodes --output yaml > kubectl_get-nodes-yaml

    # "all" is not "all" but it contains most of the other basic K8S resources we might be interested in
    kubectl -n "${CLUSTER_NAMESPACE}" get all > rook_ceph-get-all
}

gatherCephCommands() {
    mkdir -p ceph-commands

    # Ceph command outputs
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph -s > ceph-commands/ceph_status 
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph df > ceph-commands/ceph_df
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd df tree > ceph-commands/ceph_osd_df_tree
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph health detail > ceph-commands/ceph_health_detail
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph df detail > ceph-commands/ceph_df_detail
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd tree > ceph-commands/ceph_osd_tree
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd dump > ceph-commands/ceph_osd_dump
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd perf > ceph-commands/ceph_osd_perf
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd pool ls detail > ceph-commands/ceph_osd_pool_ls_detail
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd pool autoscale-status > ceph-commands/ceph_osd_pool_autoscale_status
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd numa-status > ceph-commands/ceph_osd_numa-status
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph osd blocked-by > ceph-commands/ceph_osd_blocked-by
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph mon dump > ceph-commands/ceph_mon_dump
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph mon stat > ceph-commands/ceph_mon_stat
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph pg stat > ceph-commands/ceph_pg_stat
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph pg dump > ceph-commands/ceph_pg_dump
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph fs ls > ceph-commands/ceph_fs_ls
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph fs dump > ceph-commands/ceph_fs_dump
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph mds stat > ceph-commands/ceph_mds_stat
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- ceph time-sync-status > ceph-commands/ceph_time_sync_status
}

enableDebugLog() {
    kubectl -n "${OPERATOR_NAMESPACE}" patch configmaps/rook-ceph-operator-config \
        --type merge \
        -p '{"data":{"CSI_LOG_LEVEL":"5", "ROOK_LOG_LEVEL": "DEBUG"}}'
}

showHelp() {
    echo ""
}

LOGS_TMP_DIR="$(mktemp -d -t gather-logs-XXXXXXXXXX)"

cd "${LOGS_TMP_DIR}" || { echo "Failed to cd to ${LOGS_TMP_DIR} dir."; exit 1; }

# Flag Parsing BEGIN
# Reset getopts index
OPTIND=1

# Initialize settings
enable_debug_log=0

while getopts "h?dno:" opt; do
  case "$opt" in
    h|\?)
        showHelp
        exit 0
        ;;
    d)
        enable_debug_log=1
        ;;
    n)
        CLUSTER_NAMESPACE="${OPTARG}"
        ;;
    o)
        OPERATOR_NAMESPACE="${OPTARG}"
        ;;
  esac
done

shift $(( OPTIND - 1 ))

[ "${1:-}" = "--" ] && shift
# Flag Parsing END

# Set the operator namespace to the cluster namespace if it is still empty after the flag parsing
[ -z "${OPERATOR_NAMESPACE}" ] && OPERATOR_NAMESPACE="${CLUSTER_NAMESPACE}"

if [ ${enable_debug_log} = 1 ]; then
    enableDebugLog
fi

gatherKubernetesPodLogs
gatherKubernetesObjects
gatherCephCommands
