#/bin/bash

generate_file() {
    SECRET=$(head -c 32 /dev/urandom | base64)
    
    cat > encryption-config.yaml <<- EOF
apiVersion: v1
kind: EncryptionConfig
resources:
- resources:
  - secrets
providers:
- aescbc:
    keys:
    - name: key1
      secret: $SECRET
- identity: {}
EOF
    
}
