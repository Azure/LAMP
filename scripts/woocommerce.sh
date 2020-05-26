#!/bin/bash

wooco_URL: ${1} 
wooco_path=/home/${2}
web_root=/var/www/html

echo "woocommerce url : ${wooco_URL} " >> ${wooco_path}/log.txt
echo "path : ${wooco_path}" >> ${wooco_path}/log.txt

downloadwoocommerce(){
  wget -p ${wooco_URL} ${wooco_path}/
}

extractfile(){
  sudo apt install unzip
  sudo unzip ${wooco_path}/downloads.wordpress.org/plugin/woocommerce.4.0.1.zip
  sudo cp -rf ${wooco_path}/woocommerce ${web_root}/wordpress/wp-content/plugins/
  sudo rm -rf ${wooco_path}/woocommerce
}
downloadwoocommerce
extractfile 
