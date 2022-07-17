#!/bin/bash

set -e 

etcd_home=~/k8s/etcd
etcd_version=v3.5.4


clean() {
    echo "=== stop etcd if running"
    if systemctl list-units --full --all -t service | grep etcd; then
        sudo systemctl stop etcd
    fi
 
    echo "=== removing old etcd if exists"
    rm -f /tmp/etcd-${etcd_version}-linux-amd64.tar.gz
    rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test
    
    echo "=== removing old dierctories"
    sudo rm -rf /etc/etcd /var/lib/etcd
    
}

install_etcd() {
    # choose either URL
    local google_url=https://storage.googleapis.com/etcd
    local github_url=https://github.com/etcd-io/etcd/releases/download
    local download_url=${google_url}
   
    echo "=== downloading etcd"
    curl -L ${download_url}/${etcd_version}/etcd-${etcd_version}-linux-amd64.tar.gz -o /tmp/etcd-${etcd_version}-linux-amd64.tar.gz
    
    tar xzvf /tmp/etcd-${etcd_version}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
    rm -f /tmp/etcd-${etcd_version}-linux-amd64.tar.gz
    
    sudo cp /tmp/etcd-download-test/etcd /usr/local/bin
    sudo cp /tmp/etcd-download-test/etcdctl /usr/local/bin
    sudo cp /tmp/etcd-download-test/etcdutl /usr/local/bin
}

create_directories() {
    sudo mkdir -p /etc/etcd /var/lib/etcd
}

copy_certificates() {
    sudo cp $etcd_home/ca.crt /etc/etcd
    sudo cp $etcd_home/kube-apiserver.crt /etc/etcd
    sudo cp $etcd_home/kube-apiserver.key /etc/etcd
}

copy_unit_file() {
    sudo cp $etcd_home/etcd.service /etc/systemd/system    
}

test_installation() {
    if etcd --version; then echo "=== ETCD INSTALLED"; return 0; fi
}

start_service() {
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
}

test_service() {
    if ! sudo systemctl is-active etcd; then echo "=== ETCD INSTALLATION FAILED !"; return 1; fi
}

clean
install_etcd
if ! test_installation; then echo "ETCD INSTALLATION FAILED !"; exit 1; fi
create_directories
copy_certificates
copy_unit_file
start_service
test_service


