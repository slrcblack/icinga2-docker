icinga2 pki new-cert --cn $1 --key $1.key --csr $1.csr
icinga2 pki sign-csr --csr $1.csr --cert $1.crt
