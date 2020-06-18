#!/bin/bash

# Install ansible server, SVN and configure the host VM IP (controller VM IP) 
# It will update groups_var/all file in playbook with the user inputs dynamically
# It will execute ansible playbook for installing WordPress in host VM (controller VM)

log_path=/home/${3}/var.txt
home_path=/home/${3}
vars_path=/home/${3}/wordpress/group_vars/all
# wp_admin_password is the password for wordpress site
wp_admin_password=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
wp_db_user_pass=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)

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
  svn checkout https://github.com/Azure/LAMP/trunk/scripts/ansiblePlaybook/wordpress
  sudo sed -i "s~domain_name: domain~domain_name: ${5}~" ${vars_path}
  sudo sed -i "s~user_name: azusername~user_name: ${1}~" ${vars_path}  
  sudo sed -i "s~wp_db_server_name: wordpress~wp_db_server_name: ${2}~" ${vars_path} 
  sudo sed -i "s~wp_db_user: wordpress~wp_db_user: ${3}~" ${vars_path} 
  sudo sed -i "s~wp_db_password: password~wp_db_password: ${4}~" ${vars_path}
  sudo sed -i "s~vm_password: password~vm_password: ${6}~" ${vars_path}
  sudo sed -i "s~vm_ip: IP~vm_ip: ${7}~" ${vars_path}
  sudo sed -i "s~wp_db_name: wordpress~wp_db_name: ${8}~" ${vars_path}
  sudo sed -i "s~wp_admin_password: ~wp_admin_password: ${wp_admin_password}~" ${vars_path}
  sudo sed -i "s~wp_db_user_pass: ~wp_db_user_pass: ${wp_db_user_pass}~" ${vars_path}
  ansible-playbook /home/${1}/wordpress/playbook.yml -i /etc/ansible/hosts -u ${1}
}

# Disable strict host key checking to configure host VM IP  (controller VM IP)
sudo sed -i "s~#   StrictHostKeyChecking ask~   StrictHostKeyChecking no~" /etc/ssh/ssh_config 
sudo systemctl restart ssh
install_ansible >> ${log_path}
configure_ansible ${1} ${3} >> ${log_path}
install_svn
wordpress_install ${3} ${4} ${5} ${6} ${7} ${2} ${1} ${8} >> ${log_path}
# Enable strict host key checking
sudo sed -i "s~   StrictHostKeyChecking no~#   StrictHostKeyChecking ask~" /etc/ssh/ssh_config 
sudo systemctl restart ssh