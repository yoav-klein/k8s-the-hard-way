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
    cp kube-apiserver.conf.template kube-apiserver.conf
    apiserver_ips=$(jq -r '."apiserver-ips"[]' $config_json)
    i=0
    for ip in $apiserver_ips; do
        echo "IP.$i = $ip" >> kube-apiserver.conf
        (( i = $i + 1 ))
    done    
    gen_private_key "kube-apiserver.key"
    gen_sign_request "kube-apiserver.key" "kube-apiserver.csr" "kube-apiserver.conf"
    on_failure stop "Failed generating sign request for kube-apiserver"
    sign_request "kube-apiserver.csr" "ca.crt" "ca.key" "kube-apiserver.crt" "kube-apiserver.conf" "v3_ext"
    rm "kube-apiserver.csr"
}

generate_service_accounts_cert() {
    gen_private_key "service-accounts.key"
    gen_sign_request "service-accounts.key" "service-accounts.csr" "service-accounts.conf"
    on_failure stop "Failed generating sign_request for service-accounts"
    sign_request "service-accounts.csr" "ca.crt" "ca.key" "service-accounts.crt"
    on_failure stop "Generating certificate for service-accounts failed"
    rm "service-accounts.csr"
}

generate_kubelet_client_certs() {
############
#  
# generate_kubelet_client_certs
#
# DESCRIPTION: generates PKI for kubelet clients to communicate with the API server
# 
# USAGE:
#   fill in the workers section in the configuration file with names, IP addresses and hostnames
# 
# EXPLANATION:
#   this will generate a private key and certificate for each node kubelet,
#   with the subjectAltName field populated with IP and hostname.
#
###############

    workers=$(jq '.workers[]' $config_json -c)
    if [ -d kubelets_certs ]; then
        rm -rf kubelets_certs
    fi

    mkdir -p kubelet_certs/tmp; pushd kubelet_certs;
    for worker in $workers; do
        node_name=$(echo $worker | jq -r '.name')
        ip=$(echo $worker | jq -r '.ip')
        hostname=$(echo $worker | jq -r '.hostname')
        
        mkdir $node_name
        sed "s/<node>/$node_name/;s/<hostname>/$hostname/;s/<ip>/$ip/" ../kubelet.conf.template > "tmp/$node_name.conf"
        gen_private_key "$node_name/kubelet.key"
        gen_sign_request "$node_name/kubelet.key" "tmp/$node_name.csr" "tmp/$node_name.conf"
        sign_request "tmp/$node_name.csr" ../ca.crt ../ca.key "$node_name/kubelet.crt" "tmp/$node_name.conf" "v3_ext"
        on_failure stop "generate_kubelet_client_certs: failed generating for $node_name"
        log_success "Generated PKI for $node_name"
    done

    rm -rf tmp
    popd
    log_success "SUCCESSFULLY generated PKI for kubelets!"
}


config_json="machines.json"
ssl_commons="ssl/ssl_commons.sh"

source $ssl_commons
