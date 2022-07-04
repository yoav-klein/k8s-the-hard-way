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

gen_certificate_generic() {
    name=$1
    ca_cert=$2
    ca_key=$3
    conf=$4
    if [ -z "$name" ] || [ -z "$ca_cert" ] || [ -z "$ca_key" ]; then
        log_error "gen_certificate_regular: Usage: gen_certificate_regular <name> <ca_cert> <ca_key> [conf_file_path]"
        exit 1
    fi

    if [ -n "$conf" ]; then
        conf_file_path=$4
    else
        conf_file_path="$conf_files_base/$name.conf"
    fi
    gen_private_key "$name.key"
    gen_sign_request "$name.key" "$name.csr" "$conf_file_path"
    on_failure stop "Failed generating sign request for $name !"
    sign_request "$name.csr" $ca_cert $ca_key "$name.crt"
    on_failure stop "Generating certificate for $name failed !"
    rm "$name.csr"
}

generate_admin_cert() {
    gen_certificate_generic "admin" $ca_cert $ca_key
}

generate_kube_ctrl_mgr_cert() {
    gen_certificate_generic "kube-controller-manager" $ca_cert $ca_key
}

generate_kube_proxy_cert() {
    gen_certificate_generic "kube-proxy" $ca_cert $ca_key
}

generate_kube_scheduler_cert() {
    gen_certificate_generic "kube-scheduler" $ca_cert $ca_key
}

generate_kube_apiserver_cert() {
    if [ ! -d tmp ]; then mkdir tmp; fi
    cp "$conf_files_base/kube-apiserver.conf.template" "tmp/kube-apiserver.conf"
    apiserver_ips=$(jq -r '."apiserver-ips"[]' $config_json)
    i=0
    for ip in $apiserver_ips; do
        echo "IP.$i = $ip" >> kube-apiserver.conf
        (( i = $i + 1 ))
    done    
    
    gen_certificate_generic "kube-apiserver" $ca_cert $ca_key "tmp/kube-apiserver.conf"
    
}

generate_service_accounts_cert() {
    gen_certificate_generic "service-accounts" $ca_cert $ca_key
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

ca_cert="ca.crt"
ca_key="ca.key"
conf_files_base="cert-configs"
config_json="machines.json"
ssl_commons="ssl/ssl_commons.sh"

source $ssl_commons
