#!/bin/bash

[ ! -f ../.env ] && { echo "run configure.sh first"; exit 1; }
source ../.env
source ../lib

source $LOG_LIB

set_log_level DEBUG

[ -f "$ROOT_DATA_FILE" ] || { log_error "root data file not found!"; exit 1 ;}

## global variables used by several functions
service_ip_range=$(jq -r ".serviceIpRange" $ROOT_DATA_FILE)
workers=($(jq -c ".workers[]" $ROOT_DATA_FILE))
workers_home="$WORKERS_HOME"
username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
agent_script="$WORKERS_HOME/workers_agent.sh"


# TODO: check exactly what should be in that
# hostnameOverride
_generate_kubelet_service_files() {
    log_debug "generating kubelet service files"
    set -e
    local template=kubelet.service.template
    for worker in ${workers[@]}; do
        name=$(echo $worker | jq -r '.name') || return 1
        sed "s/{{HOSTNAME}}/$name/" $template > "$WORKERS_DEPLOYMENT/$name.kubelet.service" || return 1
    done
}

_generate_kubeproxy_config_file() {
    log_debug "generating kube-proxy config file"
    set -e
    local template=kube-proxy-config.yaml.template
    cluster_cidr=$(jq -r ".clusterCidr" $ROOT_DATA_FILE) || return 1
    sed "s@{{CLUSTER_CIDR}}@$cluster_cidr@" $template > $WORKERS_DEPLOYMENT/kube-proxy-config.yaml || return 1
}

_patch_workers_agent_script() {
    log_debug "patching workers agent script"
    set -e
    local template=workers_agent.sh.template
    k8s_version=$(jq -r ".versions.kubernetes" $ROOT_DATA_FILE)
    runc_version=$(jq -r ".versions.runc" $ROOT_DATA_FILE)
    containerd_version=$(jq -r ".versions.containerd" $ROOT_DATA_FILE)
    cni_plugins_version=$(jq -r ".versions.cni_plugins" $ROOT_DATA_FILE)

    sed "s/{{K8S_VERSION}}/$k8s_version/" $template | \
        sed "s/{{RUNC_VERSION}}/$runc_version/" | \
        sed "s/{{CONTAINERD_VERSION}}/$containerd_version/" | \
        sed "s/{{CNIPLUGINS_VERSION}}/$cni_plugins_version/" | \
        sed "s@{{WORKERS_HOME}}@$WORKERS_HOME@" > $WORKERS_DEPLOYMENT/workers_agent.sh || return 1
    chmod +x $WORKERS_DEPLOYMENT/workers_agent.sh
}

_distribute_node() (
    ip=$1
    name=$2
    set -e
    trap "log_error 'failed distributing to $name, cleaning..'; ssh -i $SSH_PRIVATE_KEY $username@$ip rm -rf $workers_home" ERR
    
    log_debug "distributing to $name"
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p $workers_home"

    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/ca.crt" "$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/$name/kubelet.crt" "$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/$name/kubelet.key" "$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY "$KUBECONFIGS_OUTPUT/kube-proxy.kubeconfig" "$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY "$KUBECONFIGS_OUTPUT/kubelet-$name.kubeconfig" "$username@$ip:$workers_home/kubelet.kubeconfig"

    scp -i $SSH_PRIVATE_KEY "$WORKERS_DEPLOYMENT/workers_agent.sh" "$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY "$WORKERS_DEPLOYMENT/kubelet-config.yaml" "$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY "$WORKERS_DEPLOYMENT/$name.kubelet.service" "$username@$ip:$workers_home/kubelet.service"
    scp -i $SSH_PRIVATE_KEY "$WORKERS_DEPLOYMENT/kube-proxy-config.yaml" "$username@$ip:$workers_home"
    
    scp -i $SSH_PRIVATE_KEY  "kube-proxy.service" $"$username@$ip:$workers_home"
    scp -i $SSH_PRIVATE_KEY  "config.toml" $"$username@$ip:$workers_home" # configuration of containerd
    scp -i $SSH_PRIVATE_KEY  "containerd.service" $"$username@$ip:$workers_home"
    
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "sudo DEBIAN_FRONTEND=noninteractive apt-get update"
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jq" 
    log_info "distributed files to $name"
)

## generic function to execute a function on all nodes
# status codes of agent script:
# 0 - success
# 1 - failure
# 2 - node is already ready
# 3 - node is not ready for this action
_execute_on_nodes() {
    function=$1
    
    log_debug "executing $function on workers"
    for worker in ${workers[@]}; do
        ip=$(echo $worker | jq -r '.ip')
        name=$(echo $worker | jq -r '.name')
        
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



##################### command functions #####################


build() {
    echo_title "creating deployment"
    if [ ! -d "$WORKERS_DEPLOYMENT" ]; then mkdir "$WORKERS_DEPLOYMENT"; else rm $WORKERS_DEPLOYMENT/*; fi

    _generate_kubelet_service_files || { log_error "failed generating kubelet service files"; return 1; }
    _generate_kubeproxy_config_file || { log_error "failed generating kube-proxy config file"; return 1; }
    _patch_workers_agent_script || { log_error "failed patching agent script"; return 1; }
    
    # take serviceIpRange from data file, and compose a x.y.z.10 address of it
    cluster_dns=$(cat $ROOT_DATA_FILE  | jq -r '.serviceIpRange' | sed -e 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1.10/')
    sed "s/{{CLUSTER_DNS}}/$cluster_dns/" kubelet-config.yaml.template > "$WORKERS_DEPLOYMENT/kubelet-config.yaml"

}

distribute() {
    echo_title "distributing to nodes"
    
    local sc=0
    for worker in ${workers[@]}; do
        local ip=$(echo $worker | jq -r ".ip")
        local name=$(echo $worker | jq -r ".name")
        echo "here"
        _distribute_node $ip $name
        [ $? != 0 ] && sc=1
    done
    
    [ $sc = 0 ] && print_success "distributed files to nodes"

    return $sc
}

clean_nodes() {
    echo_title "cleaning nodes"
    for worker in ${workers[@]}; do
        name=$(echo $worker | jq -r '.name')
        ip=$(echo $worker | jq -r '.ip')

        local node_status
        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)

        # maybe agent script is not there
        if [ "$?" = 0 ]; then 
            is_active=$(echo $node_status | jq -r ".active")
            is_prereqs_installed=$(echo $node_status | jq -r ".prerequisites_installed")
            is_installed=$(echo $node_status | jq -r ".installed")
            is_loaded=$(echo $node_status | jq -r ".loaded")
            
            if [ "$is_active" = "true" ] || [ "$is_installed" = "true" ] || \
                [ "$is_loaded" = "true" ] || [ "$is_prereqs_installed" = "true" ]; then
                log_error "cannot clean $name, worker is either installed, loaded or active. moving to next node"
                continue
            fi
        fi
        
        # try to clean workers_home anyway
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" rm -rf $workers_home || { log_error "failed to clean $node"; continue; }

        log_info "cleaned node $name"
    done
}

install_prerequisites() {
    _execute_on_nodes "install_prerequisites" || { log_error "install prerequisites failed"; return 1; } 
}

uninstall_prerequisites() {
    _execute_on_nodes "uninstall_prerequisites" || { log_error "uninstall prerequisites failed"; return 1; } 
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
    for worker in ${workers[@]}; do
        name=$(echo $worker | jq -r '.name')
        ip=$(echo $worker | jq -r '.ip')

        local node_status
        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)
        if [ $? != 0 ]; then echo "status of $name is unknown, running status command failed"; continue; fi
        echo "$name"
        echo $node_status
    done      
   
}

test_workers() {
    num_workers=$(timeout 10 kubectl get nodes -ojson | jq  '.items | length')
    num_expected=$(jq '.workers | length' $ROOT_DATA_FILE)
    
    if (( $num_workers != $num_expected )); then
        echo -e  "${COLOR_RED}!!! CONTROL PLANE TEST FAILED !!!${RESET}"
        return 1;
    fi
    
    big_success "ALL WORKERS ARE UP AND RUNNING"
}

bootstrap() {
    build || { log_error "failed creating deployment"; return 1; }
    
    log_debug "distributing worker files"
    distribute
    if [ $? != 0 ]; then
        log_error "distribution of worker files failed"
        return 1
    fi
    
    log_debug "installing prerequisites on all nodes"
    install_prerequisites
    if [ $? != 0 ]; then
        log_error "installing prerequisites failed"
        return 1 
    fi

    log_debug "installing binaries on all nodes"
    install_binaries
    if [ $? != 0 ]; then
        log_error "installing worker binaries failed"
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
    
    print_success "bootstraping worker nodes succeed"
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
    
    log_debug "uninstalling prerequisites on all nodes"
    uninstall_prerequisites
    if [ $? != 0 ]; then
        log_error "uninstalling prerequisites"
        return 1
    fi

    log_debug "cleaning nodes"
    clean_nodes
    if [ $? != 0 ]; then
        log_error "cleaning nodes failed"
        return 1
    fi

    print_success "reset worker nodes succeed"
}
 


#################################################

usage() {
    echo "Usage:"
    echo "cp_manager [build, distribute, run_on_nodes, clean_nodes, clean]"
    echo "Commands:"
    echo "build       - Generate necessary files to run control plane on nodes"
    echo "distribute              - Distribute the files to the nodes"
    echo "install_prerequisites   - Install containerd and rest of prerequisites"
    echo "uninstall_prerequisites - Uninstall containerd and prerequisites"
    echo "install_binaries        - Install worker binaries on all nodes"
    echo "uninstall_binaries      - Uninstall worker binaries on all nodes"
    echo "install_services        - Install worker services (apiserver, scheduler and worker-manager)"
    echo "uninstall_services      - Uninstall above services"
    echo "start                   - Start the services"
    echo "stop                    - Stop the services"
    echo "status                  -  See the workers statuses"
    echo "test                    - Test to see if all workers are up"
    echo "bootstrap               - Run all the workers from scratch to end"
    echo "reset                   - From end to scratch"
}

cmd=$1

case $cmd in
    build) build;;
    distribute) distribute;;
    install_prerequisites) install_prerequisites;;
    uninstall_prerequisites) uninstall_prerequisites;;
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
    test) test_workers;;
    *) usage;;
esac
