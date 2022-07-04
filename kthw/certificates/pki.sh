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

####################################
#
#   gen_certificate_generic
#
# SYNOPSIS:
#   $ gen_certificate_generic <path_to_cert_file> <ca_certificate> <ca_key> <configuration_file> <extensions>
#
# PARAMETERS:
#   path_to_cert_file - the path of the generated certificate and key, without extension. for example: 'output/kube-apiserver'
#   ca_certificate    - the CA certificate to sign with
#   ca_key            - the CA private key
#   configuration_file- configuraiton file with CN, O, etc.
#   extensions        - used by the signing operation. This is the extensions section within the configuraiton file
#
########################################

gen_certificate_generic() {
    name=$1
    ca_cert=$2
    ca_key=$3
    conf=$4
    extensions=$5
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

    if [ -n "$extensions" ]; then 
        sign_request "$name.csr" $ca_cert $ca_key "$name.crt" $conf_file_path $extensions
    else 
        sign_request "$name.csr" $ca_cert $ca_key "$name.crt"
    fi
    on_failure stop "Generating certificate for $name failed !"
    rm "$name.csr"
}

## take the template configuration file and patch it with IPs of the API server
patch_apiserver_config() {
    template=$1
    destination=$2
    if [ ! -d tmp ]; then mkdir tmp; fi
    cp $template $destination
    apiserver_ips=$(jq -r '."apiserver-ips"[]' $config_json)
    i=0
    for ip in $apiserver_ips; do
        echo "IP.$i = $ip" >> $destination
        (( i = $i + 1 ))
    done
    
}



############
#  
# generate_kubelet_client_certs
#
# DESCRIPTION: generates client certificates  for kubelets to communicate with the API server
# 
# USAGE:
#   first, you need to fill in the "workers" field in the JSON configuration file. this function
#   will read data from there. there, you need to specify for each worker node its IP and hostname
# 
#  then, you run
#   $ generate_kubelet_client_certs <ca_cert> <ca_key> <configuration_file_template> <destination>
#   
#   The 'destination' parameter specifies a directory in which all the directories will be created in
#
# OUTPUT:
#   the function creates a set of directories, one for each kubelet, 
#   in which it creates a kubelete.cert and kubelet.key files.
#
#
################
generate_kubelet_client_certs() {
    ca_cert=$1
    ca_key=$2
    conf_template=$3
    destination=$4
    workers=$(jq '.workers[]' $config_json -c)
    if [ ! -d $destination ]; then mkdir -p $destination; fi
    if [ ! -d tmp ]; then mkdir tmp; fi
    for worker in $workers; do
        node_name=$(echo $worker | jq -r '.name')
        ip=$(echo $worker | jq -r '.ip')
        hostname=$(echo $worker | jq -r '.hostname')
        
        mkdir $node_name
        sed "s/<node>/$node_name/;s/<hostname>/$hostname/;s/<ip>/$ip/" $conf_template > "tmp/$node_name.conf"
        gen_certificate_generic $node_name/kubelet $ca_cert $ca_key "tmp/$node_name.conf" "v3_ext"
        mv $node_name $destination
    done
    rm -rf tmp
    log_success "SUCCESSFULLY generated PKI for kubelets!"
}

conf_files_base="cert-configs"
config_json="machines.json"
ssl_commons="ssl/ssl_commons.sh"

source $ssl_commons
