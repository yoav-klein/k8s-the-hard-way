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
    gen_private_key "$name.key" 
    gen_sign_request "$name.key" "$name.csr" "$conf_file_path" || return 1
    
    if [ -n "$extensions" ]; then 
        sign_request "$name.csr" $ca_cert $ca_key "$name.crt" $conf_file_path $extensions
    else 
        sign_request "$name.csr" $ca_cert $ca_key "$name.crt"
    fi
    
    rm "$name.csr"
}

## take the template configuration file and patch it with IPs of the API server
patch_apiserver_config() {
    template=$1
    destination=$2
    if [ -z "$template" ] || [ -z "$destination" ]; then log_error "patch_apiserver_config: not enought arguments"; return 1; fi
    cp $template $destination
    
    # take controllers in compact mode into an array
    controllers=$(jq -r -c '.controllers[]' $config_json)
    
    # ugly trick - starting from a high number since we already have a few in the configuration file
    # for each controller, add a DNS.<i> = <hostname> and IP.<i> = <ip> to the config file
    i=5
    for controller in $controllers; do
        ip=$(echo $controller | jq -r ".ip")
        hostname=$(echo $controller | jq -r ".hostname")
        echo "IP.$i = $ip" >> $destination
        echo "DNS.$i = $hostname" >> $destination
        (( i = $i + 1 ))
    done

    # add the IP and hostname of the api server. relevant in multi-controller clusters
    # where you have a load balancer
    # also, add the ClusterIP address of the apiserver
    apiserver_cluster_ip=$(jq -r ".apiServerAddress.clusterIP" $config_json)
    apiserver_ip=$(jq -r ".apiServerAddress.publicIp" $config_json)
    apiserver_hostname=$(jq -r ".apiServerAddress.hostname" $config_json)
    echo "IP.$i = $apiserver_ip" >> $destination
    echo "DNS.$i = $apiserver_hostname" >> $destination
    echo "IP.$((i + 1)) = $apiserver_cluster_ip" >> $destination
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
    
    sed "s/<node>/$node_name/;s/<hostname>/$hostname/;s/<ip>/$ip/" $conf_template > $destination
}

patch_etcd_config_file() {
    controller_name=$1
    template=$2
    destination=$3
    root_data_file=$4
    if [ -z "$controller_name" ] || [ -z "$template" ] || [ -z "$destination" ]; then log_error "patch_apiserver_config: not enought arguments"; return 1; fi
    
    # take controllers in compact mode into an array
    controller_data=$(jq -c ".controllers[] | select(.name | contains(\"$controller_name\"))" $root_data_file)
    
    ip=$(echo $controller_data | jq -r '.ip')
    hostname=$(echo $controller_data | jq -r '.hostname')

    sed "s/<ip>/$ip/;s/<hostname>/$hostname/" $template > $destination
}

conf_files_base=config_certs # not really necessary here
config_json=$ROOT_CONFIG_FILE # defined in the Makefile
ssl_commons=ssl/ssl_commons.sh

source $ssl_commons
source ../lib
