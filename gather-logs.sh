#!/bin/bash

mkdir /tmp/debug-data
cd /tmp/debug-data
mkdir logs
mkdir ceph-commands

if [ $1 = "-D" ]
then
kubectl -n rook-ceph get configmaps rook-ceph-operator-config -oyaml > op-configmap
sed -i '4i\ \ CSI_LOG_LEVEL: "5"' op-configmap
sed -i "s/^  ROOK_LOG_LEVEL: INFO/  ROOK_LOG_LEVEL: DEBUG/" op-configmap
kubectl apply -f op-configmap
fi

kubectl version > kubectl_version
kubectl get nodes > kubectl_get-nodes
kubectl get nodes -oyaml > kubectl_get-nodes-yaml

kubectl -n rook-ceph get all > rook_ceph-get-all

for p in $(kubectl -n rook-ceph get pods -o jsonpath='{.items[*].metadata.name}')
do
    for c in $(kubectl -n rook-ceph get pod ${p} -o jsonpath='{.spec.containers[*].name}')
    do
        echo "BEGIN logs from pod: ${p} ${c}"
        kubectl -n rook-ceph logs -c ${c} ${p} > logs/${p}_${c}
        echo "END logs from pod: ${p} ${c}"
    done
done

kubectl get -n rook-ceph deployments --output yaml > deployments

kubectl get configmap -n rook-ceph -oyaml > configmaps
kubectl -n rook-ceph get ConfigMap rook-config-override -o yaml > configmap_rook-config-override

# Ceph command outputs
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s > ceph-commands/ceph_status 
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph df > ceph-commands/ceph_df
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd df tree > ceph-commands/ceph_osd_df_tree
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail > ceph-commands/ceph_health_detail
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph df detail > ceph-commands/ceph_df_detail
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree > ceph-commands/ceph_osd_tree
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd dump > ceph-commands/ceph_osd_dump
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd perf > ceph-commands/ceph_osd_perf
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool ls detail > ceph-commands/ceph_osd_pool_ls_detail
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool autoscale-status > ceph-commands/ceph_osd_pool_autoscale_status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd numa-status > ceph-commands/ceph_osd_numa-status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd blocked-by > ceph-commands/ceph_osd_blocked-by
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph mon dump > ceph-commands/ceph_mon_dump
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph mon stat > ceph-commands/ceph_mon_stat
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg stat > ceph-commands/ceph_pg_stat
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump > ceph-commands/ceph_pg_dump
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph fs ls > ceph-commands/ceph_fs_ls
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph fs dump > ceph-commands/ceph_fs_dump
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph mds stat > ceph-commands/ceph_mds_stat
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph time-sync-status > ceph-commands/ceph_time_sync_status
