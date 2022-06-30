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
           return
           ;;
       *)
           log_error "$2"
           ;;
    esac
        
}



generate_admin_cert() {
    gen_private_key "admin.key"
    gen_sign_request "admin.key" "admin.csr" "admin.conf"
    sign_request "admin.csr" "ca.crt" "ca.key" "admin.crt"
    on_failure stop "gen_csr failed!"
}


generate_kubelet_client_certs() {
############
#  
# generate_kubelet_client_certs
#
# DESCRIPTION: generates PKI for kubelet clients to communicate with the API server
# 
# USAGE:
#   fill in the nodes, ips and hostnames arrays. 
# 
# EXPANATION:
#   this will generate a private key and certificate for each node kubelet,
#   with the subjectAltName field populated with IP and hostname.
#
###############
    nodes=("node1" "node2")
    ips=("1.2.3.4" "2.3.4.5")
    hostnames=("node1.example.com" "node2.example.com")
    if [ -d kubelets_certs ]; then
        rm -rf kubelets_certs
    fi

    mkdir -p kubelet_certs/tmp; pushd kubelet_certs;
    for node in ${nodes[@]}; do
        mkdir $node;
        sed "s/<node>/$node/;s/<hostname>/${hostnames[$node]}/;s/<ip>/${ips[$node]}/" ../kubelet.conf.template > "tmp/$node.conf"
        gen_private_key "$node/kubelet.key"
        gen_sign_request "$node/kubelet.key" "tmp/$node.csr" "tmp/$node.conf"
        sign_request "tmp/$node.csr" ../ca.crt ../ca.key "$node/kubelet.crt" "tmp/$node.conf" "v3_ext"
        on_failure stop "generate_kubelet_client_certs: failed generating for $node"
        log_success "Generated PKI for $node"
    done

    rm -rf tmp
    popd
    log_success "SUCCESSFULLY generated PKI for kubelets!"
}

source ssl/ssl_functions.sh
