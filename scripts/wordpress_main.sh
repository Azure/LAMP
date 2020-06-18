#!/bin/bash

# The following script will run at the time of template deployment and user input will be encoded.
# Script will download the wordpress_script.sh as a raw content from GitHub.
# Encoded input will be decoded and appended to the wordpress_script.sh for execution.
# The output of the script would be written to run.sh file at /home/azureadmin(username)/

decotext=`echo ${2} | base64 --decode`

clonerepo(){
  cd /home/"${1}"/ 
  wget https://raw.githubusercontent.com/Azure/LAMP/master/scripts/wordpress_script.sh
  sudo chown -R "${1}":"${1}" /home/"${1}"/wordpress_script.sh
}
clonerepo ${1}
  cat <<EOF > /home/"${1}"/run.sh
  #!/bin/bash
  bash /home/${1}/wordpress_script.sh ${decotext}
EOF
sudo chown -R "${1}":"${1}" /home/"${1}"/run.sh
sudo -u ${1} bash /home/"${1}"/run.sh