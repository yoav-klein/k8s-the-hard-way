#!/bin/bash

[ ! -f ../.env ] && { echo "run configure.sh first"; exit 1; }
source ../.env
source ../lib

source $LOG_LIB

set_log_level DEBUG

[ -f "$ROOT_DATA_FILE" ] || { log_error "root data file not found!"; exit 1 ;}

setup_coredns() {
    local template=coredns.yaml.template
    local cluster_ip=$(cat $ROOT_DATA_FILE | jq -r '.serviceIpRange' | sed -e 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1.10/')
    local version=$(jq '.versions.coredns' -r $ROOT_DATA_FILE)
    sed "s@{{CLUSTER_IP}}@$cluster_ip@" $template | \
       sed "s@{{VERSION}}@$version@" > coredns.yaml

    kubectl apply -f coredns.yaml
}

setup_weavenet() {
    cluster_cidr=$(jq -r ".clusterCidr" $ROOT_DATA_FILE)
    weavenet_url="https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=${cluster_cidr}"
    kubectl apply -f $weavenet_url
}

test_networking() { 
    res=$(kubectl get nodes -ojson | jq -r '.items[].status.conditions[] | select (.type=="Ready") | select(.status=="False")')
    if [ -n "$res" ]; then return 1; fi
    return 0
}

usage() {
    echo "Usage: ./networking.sh <command>"
    echo "Commands:"
    echo ""
    echo "weavenet        - Install weavenet network plugin in the cluster"
    echo "coredns         - Install CoreDNS in the cluster"
    echo "test_networking - Test to see if the nodes are in Ready state"
    echo "TODO test_dns        - Test if DNS is working properly"
}

cmd=$1
case $cmd in
    weavenet) setup_weavenet;;
    coredns) setup_coredns;;
    test_networking) test_networking;;
    *) usage; exit 1;;
esac

