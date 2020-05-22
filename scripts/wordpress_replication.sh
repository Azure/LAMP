#!/bin/bash

webroot=/var/www/html
repli_path=/azlamp/html/${1}
repli_certs=/azlamp/certs/${1}
repli_data=/azlamp/data/${1}
repli_bin=/azlamp/bin

change_location() {
    echo "change locationfunction"
    sudo mkdir ${repli_path}
    sudo cp -rf ${webroot}/wordpress/* ${repli_path}
}
configuring_certs() {
    echo "certs func"
    sudo mkdir ${repli_certs}
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${repli_certs}/nginx.key -out ${repli_certs}/nginx.crt -subj "/C=US/ST=WA/L=Redmond/O=IT/CN=${1}"
    sudo chown www-data:www-data ${repli_certs}/nginx.*
    sudo chmod 400 ${repli_certs}/nginx.*

}
linking_data_location() {
    echo "linking func"
    sudo mkdir -p ${repli_data}/wp-content/uploads
    sudo ln -s ${repli_data}/wp-content/uploads ${repli_path}/wp-content/uploads
    sudo chmod 0777 ${repli_data}/wp-content/uploads
}
update_nginx_configuration() {
    echo "update nginx"
    cd ${repli_bin}/
    sudo sed -i "s~#1)~1)~" ${repli_bin}/update-vmss-config
    sudo sed -i "s~#    . /azlamp/bin/utils.sh~   . /azlamp/bin/utils.sh~" ${repli_bin}/update-vmss-config
    sudo sed -i "s~#    reset_all_sites_on_vmss true VMSS~    reset_all_sites_on_vmss true VMSS~" ${repli_bin}/update-vmss-config
    sudo sed -i "s~#;;~;;~" ${repli_bin}/update-vmss-config
    #echo "sleep for 30 seconds"
    sleep 30
}
replication() {
    echo "replication func"
    cd /usr/local/bin/
    sudo bash update_last_modified_time.azlamp.sh
}

# ${1} value is a domain name which will update in runtime
change_location
configuring_certs ${1}
linking_data_location
update_nginx_configuration
replication 
