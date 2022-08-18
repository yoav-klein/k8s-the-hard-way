#!/bin/bash

[ ! -f ../.env ] && { echo "run configure.sh first"; exit 1; }

source ../lib
source ../.env
source $LOG_LIB

set_log_level ${LOG_LEVEL:-DEBUG}
if ! $HUMAN; then unset_human; fi

# check data file exists
[ -f "$ROOT_DATA_FILE" ] || { log_error "$ROOT_DATA_FILE not found !"; exit 1; }

## globals
username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
nodes=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
agent_script="$ETCD_HOME/etcd_agent.sh"


######
#
#   creates the value passed to the initial_cluster option
#   should be of the form: 
#       controller1=https://10.0.1.2:2380,controller2=https://10.0.1.3:2380,...
#

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

_generate_service_files() {
    _compose_node_list_var
    
    template=etcd.service.template
    [ -f "$template" ] || { log_error "$template file not found !"; return 1; }  
    
    for node in ${nodes[@]}; do
        ip=$(echo $node | jq -r '.ip')
        name=$(echo $node | jq -r '.name')

        log_debug "creating service file for $name"
        sed "s/{{ETCD_NAME}}/$name/" $template \
            | sed "s/{{INTERNAL_IP}}/$ip/" \
            | sed "s@{{INITIAL_CLUSTER}}@$etcd_nodes@" - > $ETCD_DEPLOYMENT/$name.etcd.service
    done
}

_patch_agent_script() {
    [ -f "etcd_agent.sh.template" ] || { log_error "etcd_agent.sh.template file not found !"; return 1; }

    etcd_version=$(jq -r ".versions.etcd" $ROOT_DATA_FILE)
    num_controllers=${#nodes[@]}
    sed "s/{{ETCD_VERSION}}/$etcd_version/" etcd_agent.sh.template | \
        sed "s/{{NUM_CONTROLLERS}}/$num_controllers/" | sed "s@{{ETCD_HOME}}@${ETCD_HOME}@" > $ETCD_DEPLOYMENT/etcd_agent.sh
    chmod +x $ETCD_DEPLOYMENT/etcd_agent.sh
}

############
#
#   this function runs in a subshell, hence the ( )
#   this is so that we can use set -e and not terminate the whoel script
#   NOTE that it's not a good practice to use set -e, but we do it with caution here   
#
_distribute_node() (
    ip=$1
    name=$2
    set -e 
    trap "log_error 'failed distributing to $name, cleaning..'; ssh -i $SSH_PRIVATE_KEY $username@$ip rm -rf $etcd_home" ERR

    log_debug "distributing to $name"
    
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p $ETCD_HOME" > /dev/null

    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/ca-etcd.crt" "$username@$ip:$ETCD_HOME" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/etcd-server-${name}.crt" "$username@$ip:$ETCD_HOME/etcd-server.crt" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$CERTIFICATES_OUTPUT/etcd-server-${name}.key" "$username@$ip:$ETCD_HOME/etcd-server.key" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$ETCD_DEPLOYMENT/etcd_agent.sh" "$username@$ip:$ETCD_HOME" > /dev/null
    scp -i $SSH_PRIVATE_KEY "$ETCD_DEPLOYMENT/$name.etcd.service" "$username@$ip:$ETCD_HOME/etcd.service" > /dev/null
    
    # install jq on nodes
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "sudo apt-get update" > /dev/null
    ssh -i $SSH_PRIVATE_KEY "$username@$ip" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jq" > /dev/null
    
    log_info "distributed files to $name"
)



#################### commands functions ##########################

build() {
    print_title "build: creating deployment"
    if [ ! -d "$ETCD_DEPLOYMENT" ]; then mkdir "$ETCD_DEPLOYMENT"; else rm $ETCD_DEPLOYMENT/*; fi
    _generate_service_files || return 1
    _patch_agent_script || return 1

    print_success "created deployment"
}

distribute() {
    print_title "distributing etcd files to nodes"
    _distribute && print_success "succeed to distribute etcd files to nodes"
}


## delete the etcd_home directory on all nodes
# if some node is in either installed, loaded or active state, abort
# and move to next node
clean_nodes() {
    print_title "cleaning etcd home direcotry from nodes"

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
    print_title "installing etcd binaries on nodes"
    _execute_on_nodes "install_binaries" "stop" || { log_error "install binaries failed"; return 1; } 
    print_success "succeed to install etcd binaries on nodes"
}

uninstall_binaries() {
    print_title "uninstalling etcd binaries from nodes"
    _execute_on_nodes "uninstall_binaries" "cont" || { log_error "uninstall binaries failed"; return 1; }
    print_success "succeed to uninstall binaries from nodes"
}

install_service() {
    print_title "installing etcd service on nodes"
    _execute_on_nodes "install_service" "stop" || { log_error "install service failed"; return 1; }
    print_success "succeed to install etcd service on nodes"
}

uninstall_service() {
    print_title "uninstalling etcd service fro nodes"
    _execute_on_nodes "uninstall_service" "cont" || { log_error "uninstall service failed"; return 1; }
    print_success "succeed to uninstall etcd service from nodes"
}

start_service() {
    print_title "starting etcd service on nodes"
    _execute_on_nodes "start" "stop" || { log_error "start service failed"; return 1; } 
    print_success "succeed to start etcd service on nodes"
}

stop_service() {
    print_title "stopping etcd service on nodes"
    _execute_on_nodes "stop" "cont" || { log_error "stop service failed"; return 1; } 
    print_success "succeed to stop etcd service on nodes"
}


test_etcd() {
    local first_controller_ip=$(echo ${nodes[0]} | jq -r ".ip")
    
    ssh -i $SSH_PRIVATE_KEY "$username@$first_controller_ip" "sudo $agent_script test"
    
    if [ $? = 0 ]; then
        print_success "ETCD IS UP AND RUNNING"
    else
        print_error  "!!! ETCD TEST FAILED !!!"
        exit 1
    fi
}

status() {
    for node in ${nodes[@]}; do
        local name=$(echo $node | jq -r '.name')
        local ip=$(echo $node | jq -r '.ip')
        local node_status

        # check if agent script exist
        echo $agent_script

        if ! ssh -i $SSH_PRIVATE_KEY $username@$ip [ -f $agent_script ]; then
            echo "$name: agent script doesn't exist"
            continue
        fi
        node_status=$(ssh -i $SSH_PRIVATE_KEY $username@$ip sudo $agent_script status)
        if [ $? != 0 ]; then echo "status of $name is unkown, running status command failed"; continue; fi
        echo "$name"
        echo $node_status
    done      
   
}

###################
#
#   try running all the steps
#   from scratch to runnin service
#

bootstrap() {
    build || { log_error "failed creating deployment"; return 1; }
    
    print_title "distributing etcd files"
    distribute
    if [ $? != 0 ]; then
        log_error "distribution of etcd files failed"
        return 1
    fi
    
    install_binaries
    if [ $? != 0 ]; then
        log_error "installing etcd binaries failed"
        return 1
    fi

    install_service
    if [ $? != 0 ]; then
        log_error "installing etcd service failed"
        return 1
    fi

    start_service
    if [ $? != 0 ]; then
        log_error "failed to start service"
        return 1
    fi
    
    print_success "bootstraping etcd succeed"
}

reset() {
    local sc=0

    stop_service || sc=1 

    uninstall_service || sc=1

    uninstall_binaries || sc=1

    clean_nodes || sc=1

    [ $sc = 0 ] && print_success "reset etcd succeed" || log_info "reset failed on some operations"
}

############################################################################
cmd=$1

usage() {
    echo "Usage:"
    echo "etcd_manager <command>"
    echo ""
    echo "Commands:"
    echo "build    - Generate necessary files to run etcd on nodes"
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
    build) build ;;
    distribute) distribute ;;
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

