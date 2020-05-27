#!/bin/bash

#Woocommerce plugin will be downloaded and copied to plugins directory of wordpress

wooco_URL=${1} 
wooco_path=/home/${2}
web_root=/var/www/html
wooco_version=${3}
wooco_direc_name=downloads.wordpress.org
wooco_plugin_path=plugin/woocommerce

downloadwoocommerce(){
  wget -p ${wooco_URL} ${wooco_path}/
}

extractfile(){
  sudo apt install unzip
  sudo unzip ${wooco_path}/${wooco_direc_name}/${wooco_plugin_path}.${wooco_version}.zip
  sudo cp -rf ${wooco_path}/woocommerce ${web_root}/wordpress/wp-content/plugins/
  sudo rm -rf ${wooco_path}/woocommerce
  sudo rm -rf {wooco_path}/${wooco_direc_name}/
}

downloadwoocommerce 
extractfile 
