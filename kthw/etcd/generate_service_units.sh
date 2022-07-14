#!/bin/bash

source ../.env


function create_initial_cluster_var() {
    server_ips=($(jq -r ".controllers[].ip" $ROOT_DATA_FILE))

    initial_cluster=""
    num_controllers=${#server_ips[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        initial_cluster="${initial_cluster}${server_ips[i]}:2380"
        if ! (( $num_controllers == $(( i+1 )) )) ; then INITIAL="${initial_cluster},"; fi 
    done
}

function generate_files() {
    template=etcd.service.template

    controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
    num_controllers=${#controllers[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        ip=$(echo ${controllers[i]} | jq -r '.ip' )
        name=$(echo ${controllers[i]} | jq -r '.name')
        
        sed "s/{{ETCD_NAME}}/$name/" $template  \
            | sed "s/{{INTERNAL_IP}}/$ip/" \
            | sed "s/{{INITIAL_CLUSTER}}/$initial_cluster/" - > $name.etcd.service
       
    done
}

create_initial_cluster_var
generate_files
