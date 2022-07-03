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



generate_admin_cert() {
    gen_private_key "admin.key"
    gen_sign_request "admin.key" "admin.csr" "admin.conf"
    on_failure stop "Failed generating sign request for admin"
    sign_request "admin.csr" "ca.crt" "ca.key" "admin.crt"
    on_failure stop "Generating certificate for admin failed"
    rm "admin.csr"
}

generate_kube_ctrl_mgr_cert() {
    gen_private_key "kube-controller-manager.key"
    gen_sign_request "kube-controller-manager.key" "kube-controller-manager.csr" "kube-controller-manager.conf"
    on_failure stop "Failed generating sign request for kube-controller-manager"
    sign_request "kube-controller-manager.csr" "ca.crt" "ca.key" "kube-controller-manager.crt"
    on_failure stop "Generating certificate for kube-controller-manager failed"
    rm "kube-controller-manager.csr"
}

generate_kube_proxy_cert() {
    gen_private_key "kube-proxy.key"
    gen_sign_request "kube-proxy.key" "kube-proxy.csr" "kube-proxy.conf"
    on_failure stop "Failed generating sign request for kube-proxy"
    sign_request "kube-proxy.csr" "ca.crt" "ca.key" "kube-proxy.crt"
    on_failure stop "Generating certificate for kube-proxy failed"
    rm "kube-proxy.csr"
}

generate_kube_scheduler_cert() {
    gen_private_key "kube-scheduler.key"
    gen_sign_request "kube-scheduler.key" "kube-scheduler.csr" "kube-scheduler.conf"
    on_failure stop "Failed generating sign request for kube-scheduler"
    sign_request "kube-scheduler.csr" "ca.crt" "ca.key" "kube-scheduler.crt"
    on_failure stop "Generating certificate for kube-scheduler failed"
    rm "kube-scheduler.csr"
}

generate_kube_apiserver_cert() {
    apiserver_ip="172.31.38.58"
    gen_private_key "kube-apiserver.key"
    sed "s/<ip>/$apiserver_ip/" kube-apiserver.conf.template > kube-apiserver.conf
    gen_sign_request "kube-apiserver.key" "kube-apiserver.csr" "kube-apiserver.conf"
    on_failure stop "Failed generating sign request for kube-apiserver"
    sign_request "kube-apiserver.csr" "ca.crt" "ca.key" "kube-apiserver.crt" "kube-apiserver.conf" "v3_ext"
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

source ssl/ssl_commons.sh
