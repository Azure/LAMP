#!/bin/bash

# Install ansible server, SVN and configure the host VM IP (controller VM IP) 
# It will update groups_var/all file in playbook with the user inputs dynamically
# It will execute ansible playbook for installing WordPress in host VM (controller VM)

log_path=/home/${1}/var.txt
home_path=/home/${1}
vars_path=/home/${1}/wordpress/group_vars/all
# wp_admin_password is the password for wordpress site
wp_admin_password=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
wp_db_user_pass=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)


wordpress_install() {
  cd /home/${1}
  svn checkout https://github.com/Azure/LAMP/trunk/scripts/ansiblePlaybook/wordpress
  sudo sed -i "s~domain_name: domain~domain_name: ${5}~" ${vars_path}
  sudo sed -i "s~user_name: azusername~user_name: ${1}~" ${vars_path}  
  sudo sed -i "s~wp_db_server_name: wordpress~wp_db_server_name: ${2}~" ${vars_path} 
  sudo sed -i "s~wp_db_user: wordpress~wp_db_user: ${3}~" ${vars_path} 
  sudo sed -i "s~wp_db_password: password~wp_db_password: ${4}~" ${vars_path}
  sudo sed -i "s~wp_db_name: wordpress~wp_db_name: ${6}~" ${vars_path}
  sudo sed -i "s~wp_admin_password: ~wp_admin_password: ${wp_admin_password}~" ${vars_path}
  sudo sed -i "s~wp_db_user_pass: ~wp_db_user_pass: ${wp_db_user_pass}~" ${vars_path}
  ansible-playbook /home/${1}/wordpress/playbook.yml -i /etc/ansible/hosts -u ${1}
}



wordpress_install ${1} ${2} ${3} ${4} ${5} ${6} >> ${log_path}
