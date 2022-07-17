
source ../lib
source utils.sh

generate_files
patch_setup_script
log_success "ETCD:: generated files"
copy_files_to_controllers
run_setup_on_nodes

if test; then big_success "ETCD IS UP"; fi 




