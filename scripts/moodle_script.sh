#!/bin/bash

# Install ansible server, SVN and configure the host VM IP (controller VM IP) 
# It will update groups_var/all file in playbook with the user inputs dynamically
# It will execute ansible playbook for installing Moodle in host VM (controller VM)

log_path=/home/${3}/var.txt
vars_path=/home/${3}/moodle/group_vars/all
# moodle_pass is the moodle site password
moodle_pass=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
moodle_db_pass=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)

setup_ansible() {
    sudo apt-add-repository ppa:ansible/ansible -y
    sudo apt-get update
    sudo apt-get install ansible -y
}
configure_ansible_inventory() {
    sudo chmod 777 /etc/ansible/hosts
    echo -e "[webservers]\n${1}" >>/etc/ansible/hosts
    sudo chmod 755 /etc/ansible/hosts
}
install_svn() {
    sudo apt-get update -y
    sudo apt-get install -y subversion
}
run_moodle_playbook() {
    cd /home/${3}
    svn checkout https://github.com/Azure/LAMP/trunk/scripts/ansiblePlaybook/moodle
    sudo sed -i "s~vm_ip: IP~vm_ip: ${1}~" ${vars_path}
    sudo sed -i "s~vm_password: password~vm_password: ${2}~" ${vars_path}
    sudo sed -i "s~user_name: azusername~user_name: ${3}~" ${vars_path}
    sudo sed -i "s~dbservername: localhost~dbservername: ${4}~" ${vars_path}
    sudo sed -i "s~dbusername: dbname~dbusername: ${5}~" ${vars_path}
    sudo sed -i "s~dbpassword: dbpass~dbpassword: ${6}~" ${vars_path}
    sudo sed -i "s~domain_name: domain~domain_name: ${7}~" ${vars_path}
    sudo sed -i "s~moodle_db_name: moodle~moodle_db_name: ${8}~" ${vars_path}
    sudo sed -i "s~moodle_db_pass: ~moodle_db_pass: ${moodle_db_pass}~" ${vars_path}
    sudo sed -i "s~moodle_pass: ~moodle_pass: ${moodle_pass}~" ${vars_path}
    ansible-playbook /home/${3}/moodle/playbook.yml -i /etc/ansible/hosts -u ${3}
}

# Disable strict host key checking to configure host VM IP  (controller VM IP)
sudo sed -i "s~#   StrictHostKeyChecking ask~   StrictHostKeyChecking no~" /etc/ssh/ssh_config >>${log_path}
sudo systemctl restart ssh
setup_ansible
configure_ansible_inventory ${1} ${4}
install_svn
run_moodle_playbook ${1} ${2} ${3} ${4} ${5} ${6} ${7} ${8} >>${log_path}
# Enable strict host key checking
sudo sed -i "s~   StrictHostKeyChecking no~#   StrictHostKeyChecking ask~" /etc/ssh/ssh_config >>${log_path}
sudo systemctl restart ssh