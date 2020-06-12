#!/bin/bash

# The following script will run at the time of template deployment and user input will be encoded.
# Script will download the moodle_script.sh as a raw content from GitHub.
# Encoded input will be decoded and appended to the moodle_script.sh for execution.
# The output of the script would be run.sh file at /home/azureadmin(username)/

decotext=`echo ${2} | base64 --decode`

wget_script(){
  cd /home/"${1}"/ 
  wget https://raw.githubusercontent.com/Azure/LAMP/master/scripts/moodle_script.sh
  sudo chown -R "${1}":"${1}" /home/"${1}"/moodle_script.sh
}
wget_script ${1}
  cat <<EOF > /home/"${1}"/run.sh
  #!/bin/bash
  bash /home/${1}/moodle_script.sh ${decotext}
EOF
sudo chown -R "${1}":"${1}" /home/"${1}"/run.sh
sudo -u ${1} bash /home/"${1}"/run.sh