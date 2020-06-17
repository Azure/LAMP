#!/bin/bash

# Generates OpenSSL certificates.
# Moodle replication script will be replicating the Moodle folder to virtual machine scaleset
# Updates the nginx configuration

webroot=${2}
replica_path=/azlamp/html/${1}
replica_certs=/azlamp/certs/${1}
replica_data=/azlamp/data/${1}
replica_bin=/azlamp/bin
moodledata_path=/azlamp/datadir
wp_content=wp-content/uploads
default_permission=www-data

change_location() {
    sudo mkdir ${replica_path}
    sudo cp -rf ${webroot}/moodle/* ${replica_path}
    sudo chown -R www-data:www-data ${replica_path}
}
configuring_certs() {
    sudo mkdir ${replica_certs}
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${replica_certs}/nginx.key -out ${replica_certs}/nginx.crt -subj "/C=US/ST=WA/L=Redmond/O=IT/CN=${1}"
    sudo chown ${default_permission}:${default_permission} ${replica_certs}/nginx.*
    sudo chmod 400 ${replica_certs}/nginx.*
}
change_moodledata_permission() {
    sudo chown -R ${default_permission}:${default_permission} /azlamp/moodledata
}
update_nginx_configuration() {
    cd ${replica_bin}/
    sudo sed -i "s~#1)~1)~" ${replica_bin}/update-vmss-config
    sudo sed -i "s~#    . /azlamp/bin/utils.sh~   . /azlamp/bin/utils.sh~" ${replica_bin}/update-vmss-config
    sudo sed -i "s~#    reset_all_sites_on_vmss true VMSS~    reset_all_sites_on_vmss true VMSS~" ${replica_bin}/update-vmss-config
    sudo sed -i "s~#;;~;;~" ${replica_bin}/update-vmss-config
}
replication() {
    cd /usr/local/bin/
    sudo bash update_last_modified_time.azlamp.sh
}

# ${1} value is a domain name which will update in runtime
change_location
configuring_certs ${1} 
change_moodledata_permission
update_nginx_configuration
replication 