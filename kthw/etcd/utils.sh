#!/bin/bash

source ../lib
source ../.env


######
#
#   creates the value passed to the initial_cluster option
#   should be of the form: 
#       controller1=https://10.0.1.2:2380,controller2=https://10.0.1.3:2380,...
#
#####


function compose_node_list_var() {
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

function generate_etcd_files() {
    compose_node_list_var

    template=etcd.service.template
    controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
    num_controllers=${#controllers[@]}

    for i in $(seq 0 $(( $num_controllers - 1 )) ); do
        ip=$(echo ${controllers[i]} | jq -r '.ip' )
        name=$(echo ${controllers[i]} | jq -r '.name')
        
        sed "s/{{ETCD_NAME}}/$name/" $template  \
            | sed "s/{{INTERNAL_IP}}/$ip/" \
            | sed "s@{{INITIAL_CLUSTER}}@$etcd_nodes@" - > $name.etcd.service
       
    done
}

patch_etcd_setup_script() {
    etcd_version=$(jq -r ".versions.etcd" $ROOT_DATA_FILE)
    sed "s/{{etcd_version}}/$etcd_version/" setup.sh.template > setup.sh
    chmod +x setup.sh
}


username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))

distribute_etcd_files() {
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        name=$(echo $controller | jq -r ".name")
        
        echo "ssh -i $SSH_PRIVATE_KEY \"$username@$ip\" \"mkdir -p ~/k8s/etcd\""
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p ~/k8s/etcd"
       
        run_scp $username $ip "$name.etcd.service" "~/k8s/etcd/etcd.service" $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/ca.crt" "~/k8s/etcd/"  $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/kube-apiserver.crt" "~/k8s/etcd/" $SSH_PRIVATE_KEY
        run_scp $username $ip "$CERTIFICATES_OUTPUT/kube-apiserver.key" "~/k8s/etcd/" $SSH_PRIVATE_KEY
        run_scp $username $ip "./setup.sh" "~/k8s/etcd/" $SSH_PRIVATE_KEY
        
        log_success "ETCD:: copied files to $name"
    done
}

run_setup_on_nodes() {
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        name=$(echo $controller | jq -r ".name")
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" ~/k8s/etcd/setup.sh

        log_success "ETCD:: ran ETCD on $name"
    done
}


test() {
   export ETCD_API=3
   output=$(etcdctl member list --write-out=json  \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=$CERTIFICATES_OUTPUT/ca.crt \
  --cert=$CERTIFICATES_OUTPUT/kube-apiserver.crt \
  --key=$CERTIFICATES_OUTPUT/kube-apiserver.key)
    
   num_members=$(echo $output | jq ".members | length")
   expected=$(jq ".controllers | length" $ROOT_DATA_FILE)

   if [ "$num_members" = "$expected" ]; then
       return 0
   else
       return 1
   fi
}


clean_etcd() {
    rm *.etcd.service  setup.sh
}


test_fail() {

    return 1
}
