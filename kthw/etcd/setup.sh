
#!/bin/bash

ETCD_VER=v3.5.4

install_etcd() {
    # choose either URL
    local google_url=https://storage.googleapis.com/etcd
    local github_url=https://github.com/etcd-io/etcd/releases/download
    local download_url=${google_url}
    
    echo "=== removing old etcd"
    rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test
    
    echo "=== downloading etcd"
    curl -L ${download_url}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    echo "==== here"
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
    rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    
    sudo cp /tmp/etcd-download-test/etcd /usr/local/bin
    sudo cp /tmp/etcd-download-test/etcdctl /usr/local/bin
    sudo cp /tmp/etcd-download-test/etcdutl /usr/local/bin
}

test_etcd() {
    if etcd --version; then echo "=== ETCD SUCCEED"; return 0; fi
}



# 
# setup script that runs on each controller
#
#   1. copy certificates to appropriate place
#   2. download and install etcd
#   3. copy unit file to appropriatae place
#   4. run service
#
#

