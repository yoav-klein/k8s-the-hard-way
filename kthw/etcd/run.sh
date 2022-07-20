#!/bin/bash

set -e

source ../lib
source utils.sh


generate_etcd_files
patch_etcd_setup_script
log_success "ETCD:: generated files"
distribute_etcd_files
run_setup_on_nodes

if test; then 
    big_success "ETCD IS UP" 
else
    log_error "ETCD FAILED !"
fi 




