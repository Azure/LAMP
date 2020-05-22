#!/bin/bash

wooco_URL: https://downloads.wordpress.org/plugin/woocommerce.4.0.1.zip
wooco_path=/home/${2}
echo "domain_name ${1}" >>${wooco_path}/log.txt
echo "user_name ${2}" >>${wooco_path}/log.txt

downloadwoocommerce(){
  wget -p ${wooco_URL} /home/${1}/
}

extractfile(){
  sudo apt install unzip
  sudo unzip ${wooco_path}/downloads.wordpress.org/plugin/woocommerce.4.0.1.zip
  sudo cp -rf ${wooco_path}/woocommerce /var/www/html/wordpress/wp-content/plugins/
  sudo rm -rf ${wooco_path}/woocommerce
}
downloadwoocommerce ${2}
extractfile ${1} ${2} 
