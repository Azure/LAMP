#!/bin/bash

log_path=/home/${3}/var.txt
home_path=/home/${3}
vars_path=/home/${3}/wordpress/group_vars/all

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
  sudo chmod 755 /etc/ansible/hosts
}
install_svn() {
  sudo apt-get update -y
  sudo apt-get install -y subversion
}

wordpress_install() {
  cd /home/${1}
  svn checkout https://github.com/ummadisudhakar/LAMP/trunk/scripts/ansiblePlaybook/wordpress

  sudo sed -i "s~domain_name: domain~domain_name: ${5}~" ${vars_path}
  sudo sed -i "s~user_name: azusername~user_name: ${1}~" ${vars_path}  
  sudo sed -i "s~wp_db_server_name: wordpress~wp_db_server_name: ${2}~" ${vars_path} 
  sudo sed -i "s~wp_db_user: wordpress~wp_db_user: ${3}~" ${vars_path} 
  sudo sed -i "s~wp_db_password: password~wp_db_password: ${4}~" ${vars_path}
  sudo sed -i "s~vm_password: password~vm_password: ${6}~" ${vars_path}
  sudo sed -i "s~vm_ip: IP~vm_ip: ${7}~" ${vars_path}

  ansible-playbook /home/${1}/wordpress/playbook.yml -i /etc/ansible/hosts -u ${1}
}

sudo sed -i "s~#   StrictHostKeyChecking ask~   StrictHostKeyChecking no~" /etc/ssh/ssh_config 
sudo systemctl restart ssh
install_ansible >> ${log_path}
configure_ansible ${1} ${3} >> ${log_path}
install_svn
wordpress_install ${3} ${4} ${5} ${6} ${7} ${2} ${1} >> ${log_path}
sudo sed -i "s~   StrictHostKeyChecking no~#   StrictHostKeyChecking ask~" /etc/ssh/ssh_config 
sudo systemctl restart ssh
