#!/bin/bash

[ ! -f ../.env ] && { echo "run configure.sh first"; exit 1; }

source ../lib
source ../.env
source $LOG_LIB



# check data file exists
[ -f "$ROOT_DATA_FILE" ] || { log_error "$ROOT_DATA_FILE not found !"; exit 1; }

## globals
username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
agent_script="$ETCD_HOME/etcd_agent.sh"


######
#
#   creates the value passed to the initial_cluster option
#   should be of the form: 
#       controller1=https://10.0.1.2:2380,controller2=https://10.0.1.3:2380,...
#
#####

function _compose_node_list_var() {
    server_ips=($(jq -r ".controllers[].ip" $ROOT_DATA_FILE))
    controllers_names=($(jq -r ".controllers[].name" $ROOT_DATA_FILE))

    etcd_nodes=""
    num_controllers=${#server_ips[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        etcd_nodes="${etcd_nodes}${controllers_names[i]}=https://${server_ips[i]}:2380"
        if ! (( $num_controllers == $(( i+1 )) )) ; then etcd_nodes="${etcd_nodes},"; fi 
    done
}

##############
#
#   generates a etcd.service file for each
#   node in the etcd cluster.
#
#################

_generate_service_files() {
    _compose_node_list_var
    
    template=etcd.service.template
    [ -f "$template" ] || { log_error "$template file not found !"; return 1; }  
    
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r '.ip')
        name=$(echo $controller | jq -r '.name')

        log_debug "creating service file for $name"
        sed "s/{{ETCD_NAME}}/$name/" $template \
            | sed "s/{{INTERNAL_IP}}/$ip/" \
            | sed "s@{{INITIAL_CLUSTER}}@$etcd_nodes@" - > $ETCD_DEPLOYMENT/$name.etcd.service
    done
}

_patch_agent_script() {
    [ -f "etcd_agent.sh.template" ] || { log_error "etcd_agent.sh.template file not found !"; return 1; }

    etcd_version=$(jq -r ".versions.etcd" $ROOT_DATA_FILE)
    sed "s/{{etcd_version}}/$etcd_version/" etcd_agent.sh.template | \
        sed "s/{{NUM_CONTROLLERS}}/${#controllers[@]}/" | sed "s@{{etcd_home}}@${ETCD_HOME}@" > $ETCD_DEPLOYMENT/etcd_agent.sh
    chmod +x $ETCD_DEPLOYMENT/etcd_agent.sh
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


#################### commands functions ##########################

create_deployment() {
        if [ ! -d "$ETCD_DEPLOYMENT" ]; then mkdir "$ETCD_DEPLOYMENT"; else rm $ETCD_DEPLOYMENT/*; fi
        _generate_service_files || return 1
        _patch_agent_script || return 1

        print_success "created deployment"
}


distribute_etcd_files() {
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        name=$(echo $controller | jq -r ".name")
        
        log_debug "ssh -i $SSH_PRIVATE_KEY \"$username@$ip\" \"mkdir -p $ETCD_HOME\""
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p $ETCD_HOME"
       
        run_scp $username $ip "$ETCD_DEPLOYMENT/$name.etcd.service" "$ETCD_HOME/etcd.service" $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/ca-etcd.crt" "$ETCD_HOME/"  $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/etcd-server-${name}.crt" "$ETCD_HOME/etcd-server.crt" $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/etcd-server-${name}.key" "$ETCD_HOME/etcd-server.key" $SSH_PRIVATE_KEY
        run_scp $username $ip "$ETCD_DEPLOYMENT/etcd_agent.sh" "$ETCD_HOME/" $SSH_PRIVATE_KEY
        
        # install jq on nodes
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" "sudo apt-get update" > /dev/null
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jq" > /dev/null
        
        log_info "copied files to $name"
    done
}
## delete the etcd_home directory on all nodes
# if some node is in either installed, loaded or active state, abort
# and move to next node
clean_nodes() {
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
                log_error "cannot clean $name, etcd is either installed, loaded or active. moving to next node"
                continue
            fi
        fi
        
        # try to clean etcd_home anyway
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" rm -rf $ETCD_HOME || { log_error "failed to clean $node"; continue; }

        log_info "cleaned node $name"
    done
}


install_binaries() {
    _execute_on_nodes "install_binaries" || { log_error "install binaries failed"; return 1; } 
}

uninstall_binaries() {
    _execute_on_nodes "uninstall_binaries" || { log_error "uninstall binaries failed"; return 1; } 
}

install_service() {
    _execute_on_nodes "install_service" || { log_error "install service failed"; return 1; } 
}


uninstall_service() {
    _execute_on_nodes "uninstall_service" || { log_error "uninstall service failed"; return 1; } 
}

start_service() {
    _execute_on_nodes "start" || { log_error "start service failed"; return 1; } 
}

stop_service() {
    _execute_on_nodes "stop" || { log_error "stop service failed"; return 1; } 
}


test_etcd() {
    local first_controller_ip=$(echo ${controllers[0]} | jq -r ".ip")
    
    ssh -i $SSH_PRIVATE_KEY "$username@$first_controller_ip" "sudo $agent_script test"
    
    if [ $? = 0 ]; then
        big_success "ETCD IS UP AND RUNNING"
    else
        echo -e  "${COLOR_RED}!!! ETCD TEST FAILED !!!${RESET}"
        exit 1
    fi
}

status() {
    
    for controller in ${controllers[@]}; do
        name=$(echo $controller | jq -r '.name')
        ip=$(echo $controller | jq -r '.ip')

        local node_status
        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)
        if [ $? != 0 ]; then echo "status of $name is unkown, running status command failed"; continue; fi
        echo "$name"
        echo $node_status
    done      
   
}

bootstrap() {
    create_deployment
    
    log_debug "distributing etcd files"
    distribute_etcd_files
    if [ $? != 0 ]; then
        log_error "distribution of etcd files failed"
        return 1
    fi
    
    log_debug "installing binaries on all nodes"
    install_binaries
    if [ $? != 0 ]; then
        log_error "installing etcd binaries failed"
        return 1
    fi

    log_debug "installing etcd service on all nodes"
    install_service
    if [ $? != 0 ]; then
        log_error "installing etcd service failed"
        return 1
    fi

    log_debug "starting etcd on all nodes"
    start_service
    if [ $? != 0 ]; then
        log_error "failed to start service"
        return 1
    fi
    
    print_success "bootstraping etcd succeed"
}

reset() {
    log_debug "stopping service"
    stop_service
    if [ $? != 0 ]; then
        log_error "couldn't stop service"
        return 1
    fi

    log_debug "uninstalling service on all nodes"
    uninstall_service
    if [ $? != 0 ]; then
        log_error "uninstall service failed"
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

############################################################################
cmd=$1

usage() {
    echo "Usage:"
    echo "etcd_manager <command>"
    echo ""
    echo "Commands:"
    echo "create_deployment    - Generate necessary files to run etcd on nodes"
    echo "distribute           - Distribute the files to the nodes"
    echo "clean_nodes          - Clean etcd_home, may run only if etcd is uninstalled"
    echo "install_binaries     - Install etcd binaries on nodes"
    echo "uninstall_binaries   - Uninstall etcd binaries from nodes"
    echo "insatll_service      - Install service on nodes, including all required setup"
    echo "uninstall_service    - Uninstall serivce from nodes, including cleanup"
    echo "start                - Start etcd on nodes"
    echo "stop                 - Stop the service"
    echo "test                 - Test etcd"
    echo "status               - Check the status of etcd on nodes"
    echo "bootstrap            - Bootstrap the etcd cluster from scratch to end"
    echo "reset                - Leave no mark of etcd on nodes"
}



case $cmd in
    create_deployment) create_deployment ;;
    distribute) distribute_etcd_files ;;
    clean_nodes) clean_nodes ;;
    install_binaries) install_binaries ;;
    uninstall_binaries) uninstall_binaries ;;  
    install_service) install_service ;;
    uninstall_service) uninstall_service ;;
    start) start_service ;;
    stop) stop_service ;;
    test) test_etcd ;;
    status) status;;
    bootstrap) bootstrap;;
    reset) reset;;

    *) usage;;
esac

