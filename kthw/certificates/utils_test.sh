#!/bin/bash

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
#######################################

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

    echo "=== generating private key $name.key"
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



patch_kubelet_config_file() {
    node_name=$1
    destination=$2
    conf_template=$3
    root_data_file=$4
    if [ -z "$node_name" ] || [ -z "$destination" ] || [ -z "$conf_template" ] || [ -z "$root_data_file" ]; then
        echo "Usage: patch_kubelet_config_file <node_name> <destination> <conf_template> <root_data_file>"
        exit 1
    fi

    node_data=$(jq -c  ".workers[] | select(.name | contains(\"$node_name\"))" $root_data_file)
    
    ip=$(echo $node_data | jq -r '.ip')
    hostname=$(echo $node_data | jq -r '.hostname')
    
    echo $ip $hostname
    sed "s/<node>/$node_name/;s/<hostname>/$hostname/;s/<ip>/$ip/" $conf_template > "$destination/$node_name.conf"
}

source ssl/ssl_commons.sh
source ../lib
