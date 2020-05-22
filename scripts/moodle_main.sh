#!/bin/bash

decotext=`echo ${2} | base64 --decode`
echo "User ID is : ${1}" >> /home/"${1}"/log.txt
echo "encoded text : ${2}" >> /home/"${1}"/log.txt
echo "decoded text : ${decotext}" >> /home/"${1}"/log.txt

wget_script(){
  cd /home/"${1}"/ 
  wget https://raw.githubusercontent.com/ummadisudhakar/LAMP/ansible_playbook_mat32/scripts/moodle_script.sh
  sudo chown -R "${1}":"${1}" /home/"${1}"/moodle_script.sh
}

wget_script ${1} >> /home/"${1}"/log.txt

  cat <<EOF > /home/"${1}"/run.sh
  #!/bin/bash
  bash /home/${1}/moodle_script.sh ${decotext}
EOF
sudo chown -R "${1}":"${1}" /home/"${1}"/run.sh
