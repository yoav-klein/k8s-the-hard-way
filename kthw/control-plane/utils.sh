

source ../.env
source ../lib

#####
#   
#   create the files to be copied to the controllers
#   
#   kube-apiserver.service for each controller
#   one kube-controller-manager.service
#   one kube-scheduler.service and kube-scheduler.config for all
#
#######


## global variables used by several functions
service_ip_range=$(jq -r ".serviceIpRange" $ROOT_DATA_FILE)
controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
cp_home="~/k8s/control-plane"
username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)

on_failure stop "control-plane:: couldn't parse $ROOT_DATA_FILE"

generate_controller_manager_service_files() {
    local template=kube-controller-manager.service.template
    local cluster_cidr=$(jq -r ".clusterCidr" $ROOT_DATA_FILE)
    local cluster_name=$(jq -r ".clusterName" $ROOT_DATA_FILE)

    sed "s@{{CLUSTER_CIDR}}@${cluster_cidr}@" $template | \
       sed "s@{{SERVICE_IP_RANGE}}@${service_ip_range}@" | \
       sed "s/{{CLUSTER_NAME}}/${cluster_name}/"  > kube-controller-manager.service

    on_failure stop "control-plane:: failed generating kube-controller-manager.service"
    log_success "control-plane:: generated kube-controller-manager.service"    
}

compose_etcd_nodes_var() {
    server_ips=($(jq -r ".controllers[].ip" $ROOT_DATA_FILE))

    etcd_nodes=""
    num_controllers=${#server_ips[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        etcd_nodes="${etcd_nodes}https://${server_ips[i]}:2379"
        if ! (( $num_controllers == $(( i+1 )) )) ; then etcd_nodes="${etcd_nodes},"; fi 
    done
}


generate_apiserver_service_files() {
    ## consturct the "etcd_nodes" variable 
    compose_etcd_nodes_var
    
    local k8s_public_address=$(jq -r ".apiServerAddress.publicIp" $ROOT_DATA_FILE)
    local num_controllers=${#controllers[@]}
    local template=kube-apiserver.service.template
    for i in $(seq 0 $(( num_controllers - 1 )) ); do
        ip=$(echo ${controllers[i]} | jq -r ".ip")
        name=$(echo ${controllers[i]} | jq -r ".name")
    
        sed "s/{{INTERNAL_IP}}/${ip}/" $template | \
            sed "s@{{ETCD_NODES}}@$etcd_nodes@" | \
            sed "s@{{SERVICE_IP_RANGE}}@${service_ip_range}@" | \
            sed "s/{{K8S_PUBLIC_ADDRESS}}/$k8s_public_address/" > $name.kube-apiserver.service
                
        on_failure stop "control-plane:: failed generating kube-apiserver.service files"
        log_success "control-plane:: generated $name.kube-apiserver.service"
    done
    
}

patch_control_plane_setup_script() {
    k8s_version=$(jq -r ".versions.kubernetes" $ROOT_DATA_FILE)
    sed "s/{{K8S_VERSION}}/$k8s_version/" setup.sh.template > setup.sh
    chmod +x setup.sh
}


distribute_control_plane_files() {
    for controller in ${controllers[@]}; do
        local ip=$(echo $controller | jq -r ".ip")
        local name=$(echo $controller | jq -r ".name")

        ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p $cp_home"
        run_scp $username $ip "$CERTIFICATES_OUTPUT/ca.crt" $cp_home  $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/ca.key" $cp_home  $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/kube-apiserver.crt" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/kube-apiserver.key" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/apiserver-etcd-client.crt" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/apiserver-etcd-client.key" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/apiserver-kubelet-client.crt" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/apiserver-kubelet-client.key" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/service-accounts.crt" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/service-accounts.crt" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/service-accounts.key" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$ENCRYPTION_CONFIG_DIR/encryption-config.yaml" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$KUBECONFIGS_OUTPUT/kube-scheduler.kubeconfig" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$KUBECONFIGS_OUTPUT/kube-controller-manager.kubeconfig" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "$KUBECONFIGS_OUTPUT/admin.kubeconfig" $cp_home $SSH_PRIVATE_KEY

        run_scp $username $ip "$name.kube-apiserver.service" $cp_home/kube-apiserver.service $SSH_PRIVATE_KEY
        run_scp $username $ip "kube-controller-manager.service" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "kube-scheduler.yaml" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "kube-scheduler.service" $cp_home $SSH_PRIVATE_KEY
        run_scp $username $ip "setup.sh" $cp_home $SSH_PRIVATE_KEY

        log_success "control-plane:: distributed files to $name"
    done
}

run_setup_on_nodes() {
    for controller in ${controllers[@]}; do
        local ip=$(echo $controller | jq -r ".ip")
        local name=$(echo $controller | jq -r ".name")

        ssh -i $SSH_PRIVATE_KEY "$username@$ip" $cp_home/setup.sh install
        on_failure stop "control-plane:: failed installing control-plane services on $name"
        
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" $cp_home/setup.sh start
        on_failure stop "control-plane:: failed to start services on $name"

        log_success "control:plane:: services on $name up and running"
    done    
}

clean_nodes() {
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        name=$(echo $controller | jq -r ".name")
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" $cp_home/setup.sh reset

        log_success "control-plane:: clean up $name"
    done
}

clean_control_plane() {
    rm *.kube-apiserver.service
    rm kube-controller-manager.service
    rm setup.sh
}
