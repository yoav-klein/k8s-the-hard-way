#!/bin/bash

log_warning() {
    echo "WARNING: $1"
}

log_success() {
    echo -e "\e[32;1m=== $1 \e[0m"
}


log_error() {
    echo -e "\e[31;1m=== $1 \e[0m"
}

on_error() {
    if [ $? = 0 ]; then
        return
    fi

    case "$1" in
       warn)
           log_warning "$2"
           ;;
       stop)
           log_error "$2"
           return
           ;;
       *)
           log_error "$2"
           ;;
    esac
        
}

gen_key() {
    if [ -z "$1" ]; then
        log_error "gen_key - didn't supply a name for the key"
    fi
    openssl genrsa -out $1
	
    log_success "generated key: $1"
}

generate_ca() {
    gen_key "ca.key"
    ca_cert_name="ca.crt"
    openssl req -new -x509 -days 365 -config ca.conf -key ca.key -out $ca_cert_name

    log_success  "generated CA certificate: $ca_cert_name"
}

gen_csr() {
    local key=$1
    local name=$2
    local config=$3

    if [ -z "$key" ] || [ -z "$name" ]; then
        log_error "gen_csr: Usage: gen_csr <key> <name> <config>"
        return
    fi

    openssl req -new -key $key -out $name -config $config

}

generate_admin_cert() {
    gen_key "admin.key"
    gen_csr "admin.key" "admin.csr" "admin.conf"
    on_error stop "gen_csr failed!"
}

