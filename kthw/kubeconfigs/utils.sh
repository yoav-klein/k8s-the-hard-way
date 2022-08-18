#!/bin/bash

source ../lib
source ../.env
source $LOG_LIB


gen_kubeconfig() {
    cluster_name=$1
    user_name=$2
    apiserver_ip=$3
    kubeconfig_path=$4
    ca=$5
    client_cert=$6
    client_key=$7
     
    log_info "generating $kubeconfig_path"
    if [ -z "$cluster_name" ] || [ -z "$user_name" ] || \
       [ -z "$user_name" ] || [ -z "$apiserver_ip" ] || \
       [ -z "$kubeconfig_path" ] || [ -z "$ca" ] || \
       [ -z "$client_cert" ] || [ -z "$client_key" ]; then
           echo "Usage: gen_kubeconfig <cluster_name> <user_name> <apiserver_ip> <kubeconfig_path> <ca> <client_cert> <client_key>"
           exit 1
    fi

    > /dev/null kubectl config set-cluster "$cluster_name" \
    --certificate-authority=$ca \
    --embed-certs=true \
    --server=https://$apiserver_ip:6443 \
    --kubeconfig=$kubeconfig_path \
    || { log_error "kubectl config set-cluster failed"; return 1; }

    > /dev/null kubectl config set-credentials $user_name \
    --client-certificate=$client_cert \
    --client-key=$client_key \
    --embed-certs=true \
    --kubeconfig=$kubeconfig_path \
    || { log_error "kubectl config set-credentials failed"; return 1; }

    > /dev/null kubectl config set-context default \
    --cluster=$cluster_name \
    --user=$user_name \
    --kubeconfig=$kubeconfig_path \
    || { log_error "kubectl config set-cluster failed"; return 1; }

    > /dev/null kubectl config use-context default --kubeconfig=$kubeconfig_path \
    || { log_error "kubectl config use-context failed"; return 1; }


}


