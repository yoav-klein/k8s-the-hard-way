#!/bin/bash


set -e

cp_home=~/k8s/control-plane
k8s_version=v1.24.3
create_directories() {
    sudo mkdir -p /etc/kubernetes/config
    sudo mkdir -p /var/lib/kubernetes
}

install_binaries() {
# download binaries and install them
    local kube_scheduler_url="https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-scheduler"
    local kube_apiserver_url="https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-apiserver"
    local kube_controller_manager_url="https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-controller-manager"
    local kubectl_url="https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kubectl"
    
   
    curl -sSfL $kube_scheduler_url -o kube-scheduler
    curl -sSfL $kube_apiserver_url -o kube-apiserver
    curl -sSfL $kube_controller_manager_url -o kube-controller-manager
    curl -sSfL $kubectl_url -o kubectl

    chmod +x kube-scheduler kube-apiserver kube-controller-manager kubectl

    sudo mv kube-scheduler kube-apiserver kube-controller-manager kubectl /usr/local/bin

    echo "=== Successfully installed control plane binaries"
}


install_kube_apiserver() {
    sudo cp ${cp_home}/ca.crt /var/lib/kubernetes
    sudo cp ${cp_home}/ca.key /var/lib/kubernetes
    sudo cp ${cp_home}/kube-apiserver.crt /var/lib/kubernetes
    sudo cp ${cp_home}/kube-apiserver.key /var/lib/kubernetes
    sudo cp ${cp_home}/service-accounts.crt /var/lib/kubernetes
    sudo cp ${cp_home}/service-accounts.key /var/lib/kubernetes
    sudo cp ${cp_home}/encryption-config.yaml /var/lib/kubernetes
    sudo cp ${cp_home}/kube-apiserver.service /etc/systemd/system

    echo "=== installed kube-apiserver"
}

install_kube_scheduler() {
    sudo cp ${cp_home}/kube-scheduler.kubeconfig /var/lib/kubernetes
    sudo cp ${cp_home}/kube-scheduler.yaml /etc/kubernetes/config
    sudo cp ${cp_home}/kube-scheduler.service /etc/systemd/system

    echo "=== installed kube-scheduler"

}

install_kube_controller_manager() {
    sudo cp ${cp_home}/kube-controller-manager.kubeconfig /var/lib/kubernetes
    sudo cp ${cp_home}/kube-controller-manager.service /etc/systemd/system

    echo "=== installed kube-controller-manager"
}

enable_services() {
    sudo systemctl daemon-reload
    sudo systemctl enable kube-apiserver kube-scheduler kube-controller-manager
    sudo systemctl start kube-apiserver kube-scheduler kube-controller-manager

}


create_directories
install_binaries
install_kube_apiserver
install_kube_controller_manager
install_kube_scheduler
enable_services


