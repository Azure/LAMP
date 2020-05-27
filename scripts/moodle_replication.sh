#!/bin/bash

#moodle replication script will replicating the moodle folder to virtual machine scaleset
#create a moodledata directory which is required for the moodle
#update the nginx configuration with the help of cron job

webroot=/var/www/html
replica_path=/azlamp/html/${1}
replica_certs=/azlamp/certs/${1}
replica_data=/azlamp/data/${1}
replica_bin=/azlamp/bin
moodledata_path=/azlamp/datadir
wp_content=wp-content/uploads

change_location() {
    sudo mkdir ${replica_path}
    sudo cp -rf ${webroot}/moodle/* ${replica_path}
}
configuring_certs() {
    sudo mkdir ${replica_certs}
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${replica_certs}/nginx.key -out ${replica_certs}/nginx.crt -subj "/C=US/ST=WA/L=Redmond/O=IT/CN=${1}"
    sudo chown www-data:www-data ${replica_certs}/nginx.*
    sudo chmod 400 ${replica_certs}/nginx.*
}
linking_data_location() {
    sudo mkdir -p ${replica_data}/${wp_content}
    sudo ln -s ${replica_data}/${wp_content} ${replica_path}/${wp_content}
    sudo chmod 0755 ${replica_data}/${wp_content}
}
update_nginx_configuration() {
    cd ${replica_bin}/
    sudo sed -i "s~#1)~1)~" ${replica_bin}/update-vmss-config
    sudo sed -i "s~#    . /azlamp/bin/utils.sh~   . /azlamp/bin/utils.sh~" ${replica_bin}/update-vmss-config
    sudo sed -i "s~#    reset_all_sites_on_vmss true VMSS~    reset_all_sites_on_vmss true VMSS~" ${replica_bin}/update-vmss-config
    sudo sed -i "s~#;;~;;~" ${replica_bin}/update-vmss-config
    sleep 30
}
create_moodledata(){
    sudo mkdir ${moodledata_path}
    sudo mkdir ${moodledata_path}/moodledata
    sudo chmod 755 ${moodledata_path}/
    sudo chown www-data:www-data -R ${moodledata_path}/
}
replication() {
    cd /usr/local/bin/
    sudo bash update_last_modified_time.azlamp.sh
}

# ${1} value is a domain name which will update in runtime
change_location
configuring_certs ${1}
linking_data_location 
update_nginx_configuration
create_moodledata
replication 
