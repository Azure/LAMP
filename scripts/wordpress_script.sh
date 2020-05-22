#!/bin/bash

log_path=/home/${3}/var.txt
home_path=/home/${3}
vars_path=/home/${3}/wordpress_ansible_playbook/group_vars/all

echo "Public Ip is : ${1}" >> ${log_path}
echo "Password is : ${2}" >> ${log_path}
echo "username is : ${3}" >> ${log_path}
echo "dbservername is : ${4}" >> ${log_path}
echo "dbusername is : ${5}" >> ${log_path}
echo "dbPassword is : ${6}" >> ${log_path}
echo "domainname is : ${7}" >> ${log_path}

install_ansible() {
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt-get update
sudo apt-get install ansible -y
}

configure_ansible() {
sudo chown -R ${2}:${2} ${home_path}/.ansible/cp
echo "Configure ansible Ip is : ${1}" >> ${log_path}
sudo chmod 777 /etc/ansible/hosts
sudo echo -e "[webservers]\n${1}" >>/etc/ansible/hosts
}
install_svn() {
sudo apt-get update -y
sudo apt-get install -y subversion
}

wordpress_install() {
cd /home/${1}
# the below command will download ansible playbook folder form the github repo. 
# the ansible folder must be in master to download. 
svn checkout https://github.com/sayosh0512/playbook/trunk/MAT-32-wordpress/wordpress_ansible_playbook
echo "username is : ${1}" >> ${log_path}
echo "dbservername is : ${2}" ${log_path}
echo "dbusername is : ${3}" >> ${log_path}
echo "dbPassword is : ${4}" >> ${log_path}
echo "domain_name is : ${5}" >> ${log_path}
echo "VM_Password is : ${6}" >> ${log_path}
echo "VM_IP is : ${7}" >> ${log_path}


sudo sed -i "s~domain_name: domain~domain_name: ${5}~" ${vars_path}
sudo sed -i "s~user_name: azusername~user_name: ${1}~" ${vars_path}  
sudo sed -i "s~wp_db_server_name: wordpress~wp_db_server_name: ${2}~" ${vars_path} 
sudo sed -i "s~wp_db_user: wordpress~wp_db_user: ${3}~" ${vars_path} 
sudo sed -i "s~wp_db_password: password~wp_db_password: ${4}~" ${vars_path}
sudo sed -i "s~vm_password: password~vm_password: ${6}~" ${vars_path}
sudo sed -i "s~vm_ip: IP~vm_ip: ${7}~" ${vars_path}


ansible-playbook /home/${1}/wordpress_ansible_playbook/playbook.yml -i /etc/ansible/hosts -u ${1}
}

sudo sed -i "s~#   StrictHostKeyChecking ask~   StrictHostKeyChecking no~" /etc/ssh/ssh_config 
sudo systemctl restart ssh
install_ansible >> ${log_path}
configure_ansible ${1} ${3} >> ${log_path}
install_svn
wordpress_install ${3} ${4} ${5} ${6} ${7} ${2} ${1} >> ${log_path}
sudo sed -i "s~   StrictHostKeyChecking no~#   StrictHostKeyChecking ask~" /etc/ssh/ssh_config 
sudo systemctl restart ssh
