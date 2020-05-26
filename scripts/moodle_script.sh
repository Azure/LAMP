#!/bin/bash
log_path=/home/${3}/var.txt
vars_path=/home/${3}/moodle/group_vars/all

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
moodle_install() {
    cd /home/${3}
    svn checkout https://github.com/ummadisudhakar/LAMP/trunk/scripts/ansiblePlaybook/moodle

    echo "vm_ip is : ${1}" >>${log_path}
    echo "vm_password is : ${2}" >>${log_path}
    echo "username is : ${3}" >>${log_path}
    echo "dbservername is : ${4}" >>${log_path}
    echo "dbusername is : ${5}" >>${log_path}
    echo "dbPassword is : ${6}" >>${log_path}
    echo "domain_name is : ${7}" >>${log_path}
    echo "load balancer ip : ${8}" >>${log_path}

    sudo sed -i "s~vm_ip: IP~vm_ip: ${1}~" ${vars_path}
    sudo sed -i "s~vm_password: password~vm_password: ${2}~" ${vars_path}
    sudo sed -i "s~user_name: azusername~user_name: ${3}~" ${vars_path}
    sudo sed -i "s~dbservername: localhost~dbservername: ${4}~" ${vars_path}
    sudo sed -i "s~dbusername: dbname~dbusername: ${5}~" ${vars_path}
    sudo sed -i "s~dbpassword: dbpass~dbpassword: ${6}~" ${vars_path}
    sudo sed -i "s~domain_name: domain~domain_name: ${7}~" ${vars_path}
    sudo sed -i "s~lbip: ip~lbip: ${8}~" ${vars_path}

    ansible-playbook /home/${3}/moodle/playbook.yml -i /etc/ansible/hosts -u ${3}
}

sudo sed -i "s~#   StrictHostKeyChecking ask~   StrictHostKeyChecking no~" /etc/ssh/ssh_config >>${log_path}
sudo systemctl restart ssh
setup_ansible
configure_ansible_inventory ${1} ${4}
install_svn
moodle_install ${1} ${2} ${3} ${4} ${5} ${6} ${7} ${8} ${log_path} >>${log_path}
sudo sed -i "s~   StrictHostKeyChecking no~#   StrictHostKeyChecking ask~" /etc/ssh/ssh_config >>${log_path}
sudo systemctl restart ssh
