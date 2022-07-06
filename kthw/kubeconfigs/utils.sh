#!/bin/bash

log_warning() {
    echo "WARNING: $1"
}

log_success() {
    echo -e "\e[32;1m=== $1 \e[0m"
}


log_error() {
    echo -e "\e[31;1m=== $1 \e[0m"
}

on_failure() {
    if [ $? = 0 ]; then
        return
    fi

    case "$1" in
       warn)
           log_warning "$2"
           ;;
       stop)
           log_error "$2"
           exit 1
           ;;
       *)
           log_error "$2"
           ;;
    esac
        
}

gen_kubeconfig() {
    cluster_name=$1
    user_name=$2
    apiserver_ip=$3
    kubeconfig_path=$4
    ca=$5
    client_cert=$6
    client_key=$7
    
    if [ -z "$cluster_name" ] || [ -z "$user_name" ] || \
       [ -z "$user_name" ] || [ -z "$apiserver_ip" ] || \
       [ -z "$kubeconfig_path" ] || [ -z "$ca" ] || \
       [ -z "$client_cert" ] || [ -z "$client_key" ]; then
           log_error "Usage: gen_kubeconfig <cluster_name> <user_name> <apiserver_ip> <kubeconfig_path> <ca> <client_cert> <client_key>"
           exit 1
    fi

    kubectl config set-cluster "$cluster_name" \
    --certificate-authority=$ca \
    --embed-certs=true \
    --server=https://$apiserver_ip:6443 \
    --kubeconfig=$kubeconfig_path
    on_failure stop "kubectl config set-cluster FAILED"

    kubectl config set-credentials $user_name \
    --client-certificate=$client_cert \
    --client-key=$client_key \
    --embed-certs=true \
    --kubeconfig=$kubeconfig_path
    on_failure stop "kubectl config set-credentials FAILED"

    kubectl config set-context default \
    --cluster=$cluster_name \
    --user=$user_name \
    --kubeconfig=$kubeconfig_path
    on_failure stop "kubectl config set-context FAILED"

    kubectl config use-context default --kubeconfig=$kubeconfig_path
    on_failure stop "kubectl config use-context FAILED"

    log_success "SUCCESSFULLY generated kubeconfig $kubeconfig_path"

}


