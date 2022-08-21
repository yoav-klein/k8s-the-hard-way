#!/bin/bash

[ ! -f ../.env ] && { echo "run configure.sh first"; exit 1; }
source ../.env
source ../lib

source $LOG_LIB

set_log_level ${LOG_LEVEL:-DEBUG}
if ! $HUMAN; then unset_human; fi


#####
#   
#   create the files to be copied to the controllers
#   
#   kube-apiserver.service for each controller
#   one kube-controller-manager.service
#   one kube-scheduler.service and kube-scheduler.config for all
#
#

[ -f "$ROOT_DATA_FILE" ] || { log_error "root data file not found!"; exit 1 ;}

## global variables used by several functions
service_ip_range=$(jq -r ".serviceIpRange" $ROOT_DATA_FILE)
nodes=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
cp_home="$CP_HOME"
username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
agent_script="$CP_HOME/cp_agent.sh"


_compose_etcd_nodes_var() {
    local server_ips=($(jq -r ".controllers[].ip" $ROOT_DATA_FILE))
    etcd_nodes=""
    local num_controllers=${#server_ips[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        etcd_nodes="${etcd_nodes}https://${server_ips[i]}:2379"
        if ! (( $num_controllers == $(( i+1 )) )) ; then etcd_nodes="${etcd_nodes},"; fi 
    done
}

_generate_apiserver_service_files() {
    ## consturct the "etcd_nodes" variable 
    _compose_etcd_nodes_var
    
    local k8s_public_address=$(jq -r ".apiServerAddress.publicIp" $ROOT_DATA_FILE)
    local template=kube-apiserver.service.template
    for node in ${nodes[@]}; do
        ip=$(echo $node | jq -r ".ip")
        name=$(echo $node | jq -r ".name")
    
        sed "s/{{INTERNAL_IP}}/${ip}/" $template | \
            sed "s@{{ETCD_NODES}}@$etcd_nodes@" | \
            sed "s@{{SERVICE_IP_RANGE}}@${service_ip_range}@" | \
            sed "s/{{K8S_PUBLIC_ADDRESS}}/$k8s_public_address/" > $CP_DEPLOYMENT/$name.kube-apiserver.service
        
        if [ $? != 0 ]; then log_error "failed to generate service file for $name"; return 1; fi
        log_debug "control-plane:: generated $name.kube-apiserver.service"
    done

    log_debug "generated apiserver service files"
    
}

_generate_controller_manager_service_files() {
    local template=kube-controller-manager.service.template
    local cluster_cidr=$(jq -r ".clusterCidr" $ROOT_DATA_FILE)
    local cluster_name=$(jq -r ".clusterName" $ROOT_DATA_FILE)

    sed "s@{{CLUSTER_CIDR}}@${cluster_cidr}@" $template | \
       sed "s@{{SERVICE_IP_RANGE}}@${service_ip_range}@" | \
       sed "s/{{CLUSTER_NAME}}/${cluster_name}/" > $CP_DEPLOYMENT/kube-controller-manager.service

    if [ $? != 0 ]; then log_error "failed to generate kube-controller-manager service file"; return 1; fi
    log_info "control-plane:: generated kube-controller-manager.service"
}

_generate_encryption_config_file() {
    local secret=$(head -c 32 /dev/urandom | base64)
    template=encryption-config.yaml.template
    sed "s@{{SECRET}}@${secret}@"  $template > $CP_DEPLOYMENT/encryption-config.yaml
}

_patch_control_plane_agent_script() {
    k8s_version=$(jq -r ".versions.kubernetes" $ROOT_DATA_FILE)
    sed "s/{{K8S_VERSION}}/$k8s_version/" cp_agent.sh.template  | \
    sed "s@{{CP_HOME}}@$CP_HOME@" > $CP_DEPLOYMENT/cp_agent.sh
    chmod +x $CP_DEPLOYMENT/cp_agent.sh
}



_distribute_node() (
    ip=$1
    name=$2
    set -e 
    trap "log_error 'failed distributing to $name, cleaning..'; ssh -i $SSH_PRIVATE_KEY $username@$ip rm -rf $cp_home" ERR
    
    log_debug "distributing to $name"
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p $cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/ca.crt" "$userme@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/ca.key" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/kube-apiserver.crt" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/kube-apiserver.key" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-etcd-client.crt" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-etcd-client.key" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-kubelet-client.crt" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-kubelet-client.key" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/service-accounts.crt" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/service-accounts.key" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$KUBECONFIGS_OUTPUT/kube-scheduler.kubeconfig" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$KUBECONFIGS_OUTPUT/kube-controller-manager.kubeconfig" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/cp_agent.sh" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/encryption-config.yaml" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/kube-controller-manager.service" "$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/$name.kube-apiserver.service" "$username@$ip:$cp_home/kube-apiserver.service" > /dev/null
    scp -i $SSH_PRIVATE_KEY  "kube-scheduler.yaml" $"$username@$ip:$cp_home" > /dev/null
    scp -i $SSH_PRIVATE_KEY  "kube-scheduler.service" $"$username@$ip:$cp_home" > /dev/null

    log_info "distributed files to $name"
)

################################ commands functions ####################

build() {
    print_title "build: creating deployment"
    if [ ! -d "$CP_DEPLOYMENT" ]; then mkdir "$CP_DEPLOYMENT"; else rm $CP_DEPLOYMENT/*; fi
    _generate_apiserver_service_files || { log_error "failed to generate apiserver service files"; return 1;  } 
    _generate_controller_manager_service_files || { log_error "failed to generate controller-manager service files"; return 1; }
    _generate_encryption_config_file || { log_error "failed to generate encryption config file"; return 1; }
    _patch_control_plane_agent_script || { log_error "failed to generate agent script"; return 1;  }

    print_success "succeed to create deployment"
}


distribute() {
    print_title "distributing control plane files to nodes"
    _distribute && print_success "succeed to distribute control plane files to nodes"
}

clean_nodes() {
    print_title "cleaning nodes"
    for node in ${nodes[@]}; do
        name=$(echo $node | jq -r '.name')
        ip=$(echo $node | jq -r '.ip')

        local node_status
        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)

        # maybe agent script is not there
        if [ "$?" = 0 ]; then
           
            is_active=$(echo $node_status | jq -r ".active")
            is_installed=$(echo $node_status | jq -r ".installed")
            is_loaded=$(echo $node_status | jq -r ".loaded")
            
            if [ "$is_active" = "true" ] || [ "$is_installed" = "true" ] || [ "$is_loaded" = "true" ]; then
                log_error "cannot clean $name, control plane is either installed, loaded or active. moving to next node"
                continue
            fi
        fi
        
        # try to clean cp_home anyway
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" rm -rf $cp_home || { log_error "failed to clean $node"; continue; }

        log_info "cleaned node $name"
    done
}

install_binaries() {
    print_title "installing control plane binaries on  nodes"
    _execute_on_nodes "install_binaries" "stop" || { log_error "install binaries failed"; return 1; } 
    print_success "succeed to install control plane binaries on nodes"
}

uninstall_binaries() {
    print_title "uninstalling control plane binaries from nodes"
    _execute_on_nodes "uninstall_binaries" "cont" || { log_error "uninstall binaries failed"; return 1; } 
    print_success "succeed to uninstall control plane binaries from nodes"
}

install_services() {
    print_title "installing control plane services on nodes"
    _execute_on_nodes "install_services" "stop" || { log_error "install services failed"; return 1; } 
    print_success "uninstalling control plane services from nodes"
}

uninstall_services() {
    print_title "uninstalling services from nodes"
    _execute_on_nodes "uninstall_services" "cont" || { log_error "uninstall services failed"; return 1; } 
    print_success "succeed to uninstall control plane services from nodes"
}

start_services() {
    print_title "starting control plane services on nodes"
    _execute_on_nodes "start" "stop" || { log_error "start services failed"; return 1; } 
    print_success "succeed to start control plane services on nodes"
}

stop_services() {
    print_title "stopping control plane services on nodes"
    _execute_on_nodes "stop" "cont" || { log_error "stop services failed"; return 1; } 
    print_success "succeed to stop control plane services on nodes"
}


status() {    
    for node in ${nodes[@]}; do
        local name=$(echo $node | jq -r '.name')
        local ip=$(echo $node | jq -r '.ip')
        local node_status

         # check if agent script exist
        if ! ssh -i $SSH_PRIVATE_KEY $username@$ip [ -f $agent_script ]; then
            echo "$name: agent script doesn't exist"
            continue
        fi

        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)
        if [ $? != 0 ]; then echo "status of $name is unknown, running status command failed"; continue; fi
        echo "$name"
        echo $node_status
    done      
   
}

test_cp() {
    # right now, this is the best test we have
    # just run get componetstatuses and see that it returns without timeout

    timeout 20 kubectl --kubeconfig $KUBECONFIGS_OUTPUT/admin.kubeconfig get cs > /dev/null 2>&1
    if [ $? != 0 ]; then
        print_error  "!!! CONTROL PLANE TEST FAILED !!!"
        return 1;
    fi
    
    print_success "CONTROL PLANE IS UP AND RUNNING"
}

bootstrap() {
    build || { log_error "failed creating deployment"; return 1; }
    
    log_debug "distributing control plane files"
    distribute
    if [ $? != 0 ]; then
        log_error "distribution of control plane files failed"
        return 1
    fi
    
    log_debug "installing binaries on all nodes"
    install_binaries
    if [ $? != 0 ]; then
        log_error "installing control plane binaries failed"
        return 1
    fi

    log_debug "installing services on all nodes"
    install_services
    if [ $? != 0 ]; then
        log_error "installing services failed"
        return 1
    fi

    log_debug "starting control plane on all nodes"
    start_services
    if [ $? != 0 ]; then
        log_error "failed to start services"
        return 1
    fi
    
    test_cp
    if [ $? != 0 ]; then
        log_error "conrol plane failed !"
        return 1
    fi
    print_success "bootstraping control plane succeed"
}

reset() {
    local sc=0

    log_debug "stopping service on all nodes"
    stop_services || sc=1 

    log_debug "uninstalling service on all nodes"
    uninstall_services || sc=1

    log_debug "uninstalling binaries on all nodes"
    uninstall_binaries || sc=1

    log_debug "cleaning nodes"
    clean_nodes || sc=1

    [ $sc = 0 ] &&  print_success "reset control plane succeed" || log_info "reset failed on some operations"
}

 

#################################################

usage() {
    echo "Usage:"
    echo "cp_manager [build, distribute, run_on_nodes, clean_nodes, clean]"
    echo "Commands:"
    echo "build - Generate necessary files to run control plane on nodes"
    echo "distribute        - Distribute the files to the nodes"
    echo "install_binaries  - Install control plane binaries on all nodes"
    echo "uninstall_binaries- Uninstall control plane binaries on all nodes"
    echo "install_services  - Install control plane services (apiserver, scheduler and controller-manager)"
    echo "uninstall_services- Uninstall above services"
    echo "start             - Start the services"
    echo "stop              - Stop the services"
    echo "status            - See the status of control plane on nodes"
    echo "test              - Test to see if control plane is working"
    echo "bootstrap         - Run the control plane from scratch to end"
    echo "reset             - From end to scratch"
}

cmd=$1

case $cmd in
    build) build;;
    distribute) distribute;;
    install_binaries) install_binaries;;
    uninstall_binaries) uninstall_binaries;;
    install_services) install_services;;
    uninstall_services) uninstall_services;;
    start) start_services;;
    stop) stop_services;;
    status) status;; 
    bootstrap) bootstrap;;
    reset) reset;;
    clean_nodes) clean_nodes;;
    test) test_cp;;
    *) usage;;
esac

