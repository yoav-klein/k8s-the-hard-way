#/bin/bash


source ../.env
source ../lib

source $LOG_LIB

set_log_level DEBUG

#####
#   
#   create the files to be copied to the controllers
#   
#   kube-apiserver.service for each controller
#   one kube-controller-manager.service
#   one kube-scheduler.service and kube-scheduler.config for all
#
#######

[ -f "$ROOT_DATA_FILE" ] || { log_error "root data file not found!"; exit 1 ;}

## global variables used by several functions
service_ip_range=$(jq -r ".serviceIpRange" $ROOT_DATA_FILE)
controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
cp_home="$CP_HOME"
username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
agent_script="$CP_HOME/cp_agent.sh"

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

_compose_etcd_nodes_var() {
    server_ips=($(jq -r ".controllers[].ip" $ROOT_DATA_FILE))

    etcd_nodes=""
    num_controllers=${#server_ips[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        etcd_nodes="${etcd_nodes}https://${server_ips[i]}:2379"
        if ! (( $num_controllers == $(( i+1 )) )) ; then etcd_nodes="${etcd_nodes},"; fi 
    done
}

_generate_apiserver_service_files() {
    ## consturct the "etcd_nodes" variable 
    _compose_etcd_nodes_var
    
    local k8s_public_address=$(jq -r ".apiServerAddress.publicIp" $ROOT_DATA_FILE)
    local num_controllers=${#controllers[@]}
    local template=kube-apiserver.service.template
    for i in $(seq 0 $(( num_controllers - 1 )) ); do
        ip=$(echo ${controllers[i]} | jq -r ".ip")
        name=$(echo ${controllers[i]} | jq -r ".name")
    
        sed "s/{{INTERNAL_IP}}/${ip}/" $template | \
            sed "s@{{ETCD_NODES}}@$etcd_nodes@" | \
            sed "s@{{SERVICE_IP_RANGE}}@${service_ip_range}@" | \
            sed "s/{{K8S_PUBLIC_ADDRESS}}/$k8s_public_address/" > $CP_DEPLOYMENT/$name.kube-apiserver.service
        
        if [ $? != 0 ]; then log_error "failed to generate service file for $name"; return 1; fi
        log_debug "control-plane:: generated $name.kube-apiserver.service"
    done

    log_debug "generated apiserver service files"
    
}

_patch_control_plane_agent_script() {
    k8s_version=$(jq -r ".versions.kubernetes" $ROOT_DATA_FILE)
    sed "s/{{K8S_VERSION}}/$k8s_version/" cp_agent.sh.template  | \
    sed "s@{{CP_HOME}}@$CP_HOME@" > $CP_DEPLOYMENT/cp_agent.sh
    chmod +x $CP_DEPLOYMENT/cp_agent.sh
}


clean_nodes() {
    echo_title "cleaning nodes"
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        name=$(echo $controller | jq -r ".name")
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" $cp_home/setup.sh reset

        print_success "control-plane:: clean up $name"
    done
}

call_test() {
    test
    if [ $? = 0 ]; then
        big_success "ETCD IS UP AND RUNNING"
    else
        log_error "ETCD FAILED !"
        exit 1
    fi
}


## generic function to execute a function on all nodes
# status codes of agent script:
# 0 - success
# 1 - failure
# 2 - node is already ready
# 3 - node is not ready for this action
_execute_on_nodes() {
    function=$1
    
    log_debug "executing $function on controllers"
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r '.ip')
        name=$(echo $controller | jq -r '.name')
        
        ssh -i $SSH_PRIVATE_KEY "$username@$ip"  "sudo $agent_script $function"
        sc=$?
        log_debug "$name returned $sc"

        if [ $sc = 1 ]; then
            log_error "$function on $name failed !"
            return 1
        fi
        if [ $sc = 2 ]; then
            log_warning "$name is already after $function"
            continue
        fi
        if [ $sc = 3 ]; then
            log_error "$name is not ready for $function"
            return 1
        fi

        log_info "successfully executed $function on $name"
    done
}


################################ commands functions ####################

create_deployment() {
    if [ ! -d "$CP_DEPLOYMENT" ]; then mkdir "$CP_DEPLOYMENT"; else rm $CP_DEPLOYMENT/*; fi
    _generate_apiserver_service_files || { log_error "failed to generate apiserver service files"; return 1;  } 
    _generate_controller_manager_service_files || { log_error "failed to generate controller-manager service files"; return 1; }
    _patch_control_plane_agent_script || { log_error "failed to generate agent script"; return 1;  }
}

distribute_node() (
    ip=$1
    name=$2
    set -e 
    trap "log_error 'failed distributing to $name, cleaning..'; ssh -i $SSH_PRIVATE_KEY $username@$ip rm -rf $cp_home" ERR
    
    log_debug "distributing to $name"
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p $cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/ca.crt" "$userme@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/ca.key" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/kube-apiserver.crt" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/kube-apiserver.key" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-etcd-client.crt" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-etcd-client.key" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-kubelet-client.crt" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/apiserver-kubelet-client.key" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/service-accounts.crt" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/service-accounts.key" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$ENCRYPTION_CONFIG_DIR/encryption-config.yaml" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$KUBECONFIGS_OUTPUT/kube-scheduler.kubeconfig" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$KUBECONFIGS_OUTPUT/kube-controller-manager.kubeconfig" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/cp_agent.sh" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/kube-controller-manager.service" "$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY "$CP_DEPLOYMENT/$name.kube-apiserver.service" "$username@$ip:$cp_home/kube-apiserver.service"
    
    scp -i $SSH_PRIVATE_KEY  "kube-scheduler.yaml" $"$username@$ip:$cp_home"
    scp -i $SSH_PRIVATE_KEY  "kube-scheduler.service" $"$username@$ip:$cp_home"

    log_info "distributed files to $name"
)

distribute() {
    echo_title "distributing to nodes"
    
    local sc=0
    for controller in ${controllers[@]}; do
        local ip=$(echo $controller | jq -r ".ip")
        local name=$(echo $controller | jq -r ".name")

        distribute_node $ip $name
        [ $? != 0 ] && sc=1
    done
    
    [ $sc = 0 ] && print_success "distributed files to nodes"

    return $sc
}

clean_nodes() {
    echo_title "cleaning nodes"
    for controller in ${controllers[@]}; do
        name=$(echo $controller | jq -r '.name')
        ip=$(echo $controller | jq -r '.ip')

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
        
        # try to clean etcd_home anyway
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" rm -rf $cp_home || { log_error "failed to clean $node"; continue; }

        log_info "cleaned node $name"
    done
}

install_binaries() {
    _execute_on_nodes "install_binaries" || { log_error "install binaries failed"; return 1; } 
}

uninstall_binaries() {
    _execute_on_nodes "uninstall_binaries" || { log_error "uninstall binaries failed"; return 1; } 
}

install_services() {
    _execute_on_nodes "install_services" || { log_error "install services failed"; return 1; } 
}

uninstall_services() {
    _execute_on_nodes "uninstall_services" || { log_error "uninstall services failed"; return 1; } 
}

start_services() {
    _execute_on_nodes "start" || { log_error "start services failed"; return 1; } 
}

stop_services() {
    _execute_on_nodes "stop" || { log_error "stop services failed"; return 1; } 
}


status() {    
    for controller in ${controllers[@]}; do
        name=$(echo $controller | jq -r '.name')
        ip=$(echo $controller | jq -r '.ip')

        local node_status
        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)
        if [ $? != 0 ]; then echo "status of $name is unknown, running status command failed"; continue; fi
        echo "$name"
        echo $node_status
    done      
   
}

bootstrap() {
    create_deployment
    
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
    
    print_success "bootstraping control plane succeed"
}

reset() {
    log_debug "stopping services"
    stop_services
    if [ $? != 0 ]; then
        log_error "failed to stop service"
        return 1
    fi

    log_debug "uninstalling services on all nodes"
    uninstall_services
    if [ $? != 0 ]; then
        log_error "uninstall services failed"
        return 1
    fi

    log_debug "uninstalling binaries on all nodes"
    uninstall_binaries
    if [ $? != 0 ]; then
        log_error "uninstalling binaries failed"
        return 1
    fi

    log_debug "cleaning nodes"
    clean_nodes
    if [ $? != 0 ]; then
        log_error "cleaning nodes failed"
        return 1
    fi

    print_success "reset etcd succeed"
}

test_cp() {
    # right now, this is the best test we have
    # just run get componetstatuses and see that it returns without timeout

    timeout 10 kubectl --kubeconfig $KUBECONFIGS_OUTPUT/admin.kubeconfig get cs > /dev/null 2>&1
    if [ $? != 0 ]; then
        echo -e  "${COLOR_RED}!!! CONTROL PLANE TEST FAILED !!!${RESET}"
        return 1;
    fi
    
    big_success "CONTROL PLANE IS UP AND RUNNING"
}
 

#################################################

usage() {
    echo "Usage:"
    echo "cp_manager [create_deployment, distribute, run_on_nodes, clean_nodes, clean]"
    echo "Commands:"
    echo "create_deployment - Generate necessary files to run control plane on nodes"
    echo "distribute        - Distribute the files to the nodes"
    echo "install_binaries  - Install control plane binaries on all nodes"
    echo "uninstall_binaries- Uninstall control plane binaries on all nodes"
    echo "install_services  - Install control plane services (apiserver, scheduler and controller-manager)"
    echo "uninstall_services- Uninstall above services"
    echo "start             - Start the services"
    echo "stop              - Stop the services"
    echo "bootstrap         - Run the control plane from scratch to end"
    echo "reset             - From end to scratch"
    echo "test              - Test to see if control plane is working"
}

cmd=$1

case $cmd in
    create_deployment) create_deployment;;
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

