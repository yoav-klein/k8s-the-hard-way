#!/bin/bash

source ../.env
source ../lib
source utils.sh

cmd=$1

usage() {
    echo "Usage:"
    echo "cp_manager [create_deployment, distribute, run_on_nodes, clean_nodes, clean]"
    echo "Commands:"
    echo "create_deployment - Generate necessary files to run control plane on nodes"
    echo "distribute        - Distribute the files to the nodes"
    echo "run_on_nodes      - Install and run control plane services on nodes"
    echo "clean_nodes       - Leave no mark of control plane on nodes"
    echo "clean             - Clean deployment files from this directory"
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

case $cmd in
    create_deployment) 
        generate_apiserver_service_files
        generate_controller_manager_service_files
        patch_control_plane_setup_script
        ;;
    distribute) 
        distribute_control_plane_files
        on_failure stop "control-plane:: failed distributing files to nodes"
        ;;
    run_on_nodes) 
        run_setup_on_nodes
        on_failure stop "control-plane:: failed running setup on nodes"
        ;;
    clean_nodes) 
        clean_nodes
        on_failure warn "control-plane:: failed cleaning nodes"
        ;;
    clean) clean_control_plane;;
    test) 
        call_test
        ;;
    *) usage;;
esac

