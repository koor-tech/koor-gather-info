#!/bin/sh

CLUSTER_NAMESPACE="${CLUSTER_NAMESPACE:-rook-ceph}"
OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-}"

gatherKubernetesPodLogs() {
    mkdir -p logs

    for p in $(kubectl -n "${CLUSTER_NAMESPACE}" get pods -o jsonpath='{.items[*].metadata.name}'); do
        for c in $(kubectl -n "${CLUSTER_NAMESPACE}" get pod "${p}" -o jsonpath='{.spec.containers[*].name}'); do
            echo "gather-info: BEGIN logs from pod: ${p} ${c}"
            kubectl -n "${CLUSTER_NAMESPACE}" logs -c "${c}" "${p}" > "logs/${p}-${c}"
            if [ -s "logs/${p}-${c}" ]; then
                echo "gather-info: END logs from pod: ${p} ${c}"
            else
                echo "WARN: No debug logs collected for ${p} ${c}"
            fi
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

    # Get Rook Ceph CRs as YAML
    for crd in $(kubectl get crd --no-headers -o custom-columns=":metadata.name" | grep ".ceph.rook.io"); do
        kubectl get -A "${crd}" --output yaml > "rook_ceph-get-cr-${crd}"
    done
}

runCommandInToolsPod() {
    command=$(echo "$*" | sed 's/ /_/g')
    command=$(echo "$command" | sed 's/-/_/g')
    kubectl -n "${CLUSTER_NAMESPACE}" exec -it deploy/rook-ceph-tools -- "${@}" > ceph-commands/"${command}"
}

gatherCephCommands() {
    mkdir -p ceph-commands

    # Ceph command outputs
    runCommandInToolsPod ceph versions
    runCommandInToolsPod ceph status
    runCommandInToolsPod ceph df
    runCommandInToolsPod ceph osd df tree
    runCommandInToolsPod ceph health detail
    runCommandInToolsPod ceph df detail
    runCommandInToolsPod ceph osd tree
    runCommandInToolsPod ceph osd dump
    runCommandInToolsPod ceph osd perf
    runCommandInToolsPod ceph osd pool ls detail
    runCommandInToolsPod ceph osd pool autoscale-status
    runCommandInToolsPod ceph osd numa-status
    runCommandInToolsPod ceph osd blocked-by
    runCommandInToolsPod ceph mon dump
    runCommandInToolsPod ceph mon stat
    runCommandInToolsPod ceph pg stat
    runCommandInToolsPod ceph pg dump
    runCommandInToolsPod ceph fs ls
    runCommandInToolsPod ceph fs dump
    runCommandInToolsPod ceph mds stat
    runCommandInToolsPod ceph time-sync-status
    runCommandInToolsPod ceph config dump
}

packInfo() {
    OLD_LC_ALL="$LC_ALL"
    # Override to make sure the date / time format isn't breaking the tar file name
    export LC_ALL="C"

    TAR_FILE="${CWD}/$(date +"%s-%Y-%m-%d")-koor-gather-info.tar.gz"

    tar cfvz "${TAR_FILE}" "${INFO_TMP_DIR}"
    echo "gather-info: Info dump tar available at: ${TAR_FILE}"
    LC_ALL="$OLD_LC_ALL"
}

enableDebugLog() {
    kubectl -n "${OPERATOR_NAMESPACE}" patch configmaps/rook-ceph-operator-config \
        --type merge \
        -p '{"data":{"CSI_LOG_LEVEL":"5", "ROOK_LOG_LEVEL": "DEBUG"}}'
}

showHelp() {
    echo "Usage: $0 [FLAGS]"
    echo "Flags:"
    echo "  -h - Show help menu."
    echo "  -d - Set Rook Ceph Operator and CSI log level to debug/trace."
    echo "  -n NAMESPACE - Rook Ceph Cluster namespace, default: 'rook-ceph' (CLUSTER_NAMESPACE)."
    echo "  -o NAMESPACE - If the operator is run separately from the cluster, specify the namespace (OPERATOR_NAMESPACE)."
    echo "  -t - Disable tar-ing the collected info to the current working dir."
}

# Save current working dir so we can later create the tar file there
CWD="$(pwd)"

INFO_TMP_DIR="$(mktemp -d -t gather-logs-XXXXXXXXXX)"
cd "${INFO_TMP_DIR}" || { echo "gather-info: Failed to cd to ${INFO_TMP_DIR} dir."; exit 1; }

# Flag Parsing BEGIN
# Reset getopts index
OPTIND=1

# Initialize settings
enable_debug_log=0
enable_pack_info=1

while getopts "h?dnot:" opt; do
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
    t)
        enable_pack_info=0
        ;;
  esac
done

shift $(( OPTIND - 1 ))

[ "${1:-}" = "--" ] && shift
# Flag Parsing END

# Set the operator namespace to the cluster namespace if it is still empty after the flag parsing
[ -z "${OPERATOR_NAMESPACE}" ] && OPERATOR_NAMESPACE="${CLUSTER_NAMESPACE}"

echo "gather-info: Starting at $(date +%s) ..."

if [ ${enable_debug_log} = 1 ]; then
    enableDebugLog
fi

gatherKubernetesPodLogs
gatherKubernetesObjects
gatherCephCommands

if [ ${enable_pack_info} = 1 ]; then
    packInfo
else
    echo "gather-info: Skipped tar packing of info dump."
fi

echo "gather-info: Done at $(date +%s)."
