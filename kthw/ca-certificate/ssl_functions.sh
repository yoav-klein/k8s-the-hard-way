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

gen_key() {
    if [ -z "$1" ]; then
        log_error "gen_key - didn't supply a name for the key"
    fi
    openssl genrsa -out $1
	
    log_success "generated key: $1"
}

generate_ca() {
    gen_key "ca.key"
    ca_cert_name="ca.crt"
    openssl req -new -x509 -days 365 -config ca.conf -key ca.key -out $ca_cert_name

    log_success  "generated CA certificate: $ca_cert_name"
}

gen_csr() {
    local key=$1
    local name=$2
    local config=$3

    if [ -z "$key" ] || [ -z "$name" ]; then
        log_error "gen_csr: Usage: gen_csr <key> <name> <config>"
        return
    fi

    openssl req -new -key $key -out $name -config $config

}

function sign_request() {
	csr=$1
	ca=$2
	ca_key=$3
	name=$4
	ext_file=$5
    extensions=$6

	if [ ! -f "$ca" ] || [ ! -f "$ca_key" ] || [ ! -f "$csr" ] || [ -z "$name" ]; then
		log_error "Usage: sign_request <csr> <ca_certificate> <ca_key> <certificate_name> [extension_file <extensions_section>] "
		return
	fi

	if [ -n "$ext_file" ]; then
		if [ ! -f $ext_file ] || [ -z "$extensions" ]; then
			echo "extension file wasn't found or extensions section is not specified !"
			return
		fi

		openssl x509 -req -days 365 -sha256 -in $csr -CA $ca -CAkey $ca_key \
		-CAcreateserial -out $name -extfile $ext_file -extensions $extensions
	else
		openssl x509 -req -days 365 -sha256 -in $csr -CA $ca -CAkey $ca_key \
		-CAcreateserial -out $name
	fi
}

generate_admin_cert() {
    gen_key "admin.key"
    gen_csr "admin.key" "admin.csr" "admin.conf"
    on_error stop "gen_csr failed!"
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
        gen_key "$node/kubelet.key"
        gen_csr "$node/kubelet.key" "tmp/$node.csr" "tmp/$node.conf"
        sign_request "tmp/$node.csr" ../ca.crt ../ca.key "$node/kubelet.crt" "tmp/$node.conf" "v3_ext"
        on_failure stop "generate_kubelet_client_certs: failed generating for $node"
        log_success "Generated PKI for $node"
    done

    rm -rf tmp
    popd
    log_success "SUCCESSFULLY generated PKI for kubelets!"
}


