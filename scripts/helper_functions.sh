#!/bin/bash

# Common functions definitions

function get_setup_params_from_configs_json
{
    local configs_json_path=${1}    # E.g., /var/lib/cloud/instance/moodle_on_azure_configs.json

    (dpkg -l jq &> /dev/null) || (apt -y update; apt -y install jq)

    # Wait for the cloud-init write-files user data file to be generated (just in case)
    local wait_time_sec=0
    while [ ! -f "$configs_json_path" ]; do
        sleep 15
        let "wait_time_sec += 15"
        if [ "$wait_time_sec" -ge "1800" ]; then
            echo "Error: Cloud-init write-files didn't complete in 30 minutes!"
            return 1
        fi
    done

    local json=$(cat $configs_json_path)
    export moodleVersion=$(echo $json | jq -r .moodleProfile.version)
    export glusterNode=$(echo $json | jq -r .fileServerProfile.glusterVmName)
    export glusterVolume=$(echo $json | jq -r .fileServerProfile.glusterVolName)
    export siteFQDN=$(echo $json | jq -r .siteProfile.siteURL)
    export httpsTermination=$(echo $json | jq -r .siteProfile.httpsTermination)
    export dbIP=$(echo $json | jq -r .dbServerProfile.fqdn)
    export moodledbname=$(echo $json | jq -r .moodleProfile.dbName)
    export moodledbuser=$(echo $json | jq -r .moodleProfile.dbUser)
    export moodledbpass=$(echo $json | jq -r .moodleProfile.dbPassword)
    export adminpass=$(echo $json | jq -r .moodleProfile.adminPassword)
    export dbadminlogin=$(echo $json | jq -r .dbServerProfile.adminLogin)
    export dbadminloginazure=$(echo $json | jq -r .dbServerProfile.adminLoginAzure)
    export dbadminpass=$(echo $json | jq -r .dbServerProfile.adminPassword)
    export storageAccountName=$(echo $json | jq -r .moodleProfile.storageAccountName)
    export storageAccountKey=$(echo $json | jq -r .moodleProfile.storageAccountKey)
    export azuremoodledbuser=$(echo $json | jq -r .moodleProfile.dbUserAzure)
    export redisDns=$(echo $json | jq -r .moodleProfile.redisDns)
    export redisAuth=$(echo $json | jq -r .moodleProfile.redisKey)
    export elasticVm1IP=$(echo $json | jq -r .moodleProfile.elasticVm1IP)
    export installO365pluginsSwitch=$(echo $json | jq -r .moodleProfile.installO365pluginsSwitch)
    export dbServerType=$(echo $json | jq -r .dbServerProfile.type)
    export fileServerType=$(echo $json | jq -r .fileServerProfile.type)
    export mssqlDbServiceObjectiveName=$(echo $json | jq -r .dbServerProfile.mssqlDbServiceObjectiveName)
    export mssqlDbEdition=$(echo $json | jq -r .dbServerProfile.mssqlDbEdition)
    export mssqlDbSize=$(echo $json | jq -r .dbServerProfile.mssqlDbSize)
    export installObjectFsSwitch=$(echo $json | jq -r .moodleProfile.installObjectFsSwitch)
    export installGdprPluginsSwitch=$(echo $json | jq -r .moodleProfile.installGdprPluginsSwitch)
    export thumbprintSslCert=$(echo $json | jq -r .siteProfile.thumbprintSslCert)
    export thumbprintCaCert=$(echo $json | jq -r .siteProfile.thumbprintCaCert)
    export searchType=$(echo $json | jq -r .moodleProfile.searchType)
    export azureSearchKey=$(echo $json | jq -r .moodleProfile.azureSearchKey)
    export azureSearchNameHost=$(echo $json | jq -r .moodleProfile.azureSearchNameHost)
    export tikaVmIP=$(echo $json | jq -r .moodleProfile.tikaVmIP)
    export syslogServer=$(echo $json | jq -r .moodleProfile.syslogServer)
    export webServerType=$(echo $json | jq -r .moodleProfile.webServerType)
    export htmlLocalCopySwitch=$(echo $json | jq -r .moodleProfile.htmlLocalCopySwitch)
    export nfsVmName=$(echo $json | jq -r .fileServerProfile.nfsVmName)
    export nfsHaLbIP=$(echo $json | jq -r .fileServerProfile.nfsHaLbIP)
    export nfsHaExportPath=$(echo $json | jq -r .fileServerProfile.nfsHaExportPath)
    export nfsByoIpExportPath=$(echo $json | jq -r .fileServerProfile.nfsByoIpExportPath)
}

function get_php_version {
# Returns current PHP version, in the form of x.x, eg 7.0 or 7.2
    if [ -z "$_PHPVER" ]; then
        _PHPVER=`/usr/bin/php -r "echo PHP_VERSION;" | /usr/bin/cut -c 1,2,3`
    fi
    echo $_PHPVER
}

function install_php_mssql_driver
{
    # Download and build php/mssql driver
    /usr/bin/curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    /usr/bin/curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
    sudo apt-get update
    sudo ACCEPT_EULA=Y apt-get install msodbcsql mssql-tools unixodbc-dev -y
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
    source ~/.bashrc

    #Build mssql driver
    /usr/bin/pear config-set php_ini `php --ini | grep "Loaded Configuration" | sed -e "s|.*:\s*||"` system
    /usr/bin/pecl install sqlsrv
    /usr/bin/pecl install pdo_sqlsrv
    PHPVER=$(get_php_version)
    echo "extension=sqlsrv.so" >> /etc/php/$PHPVER/fpm/php.ini
    echo "extension=pdo_sqlsrv.so" >> /etc/php/$PHPVER/fpm/php.ini
    echo "extension=sqlsrv.so" >> /etc/php/$PHPVER/apache2/php.ini
    echo "extension=pdo_sqlsrv.so" >> /etc/php/$PHPVER/apache2/php.ini
    echo "extension=sqlsrv.so" >> /etc/php/$PHPVER/cli/php.ini
    echo "extension=pdo_sqlsrv.so" >> /etc/php/$PHPVER/cli/php.ini
}

function check_fileServerType_param
{
    local fileServerType=$1
    if [ "$fileServerType" != "gluster" -a "$fileServerType" != "azurefiles" -a "$fileServerType" != "nfs" -a "$fileServerType" != "nfs-ha" -a "$fileServerType" != "nfs-byo" ]; then
        echo "Invalid fileServerType ($fileServerType) given. Only 'gluster', 'azurefiles', 'nfs', 'nfs-ha' or 'nfs-byo' are allowed. Exiting"
        exit 1
    fi
}

function create_azure_files_share
{
    local shareName=$1
    local storageAccountName=$2
    local storageAccountKey=$3
    local logFilePath=$4

    az storage share create \
        --name $shareName \
        --account-name $storageAccountName \
        --account-key $storageAccountKey \
        --fail-on-exist >> $logFilePath
}

function setup_and_mount_gluster_share
{
    local glusterNode=$1
    local glusterVolume=$2
    local mountPoint=$3     # E.g., /azlamp

    grep -q "${mountPoint}.*glusterfs" /etc/fstab || echo -e $glusterNode':/'$glusterVolume'   '$mountPoint'         glusterfs       defaults,_netdev,log-level=WARNING,log-file=/var/log/gluster.log 0 0' >> /etc/fstab
    mount $mountPoint
}

function setup_and_mount_azure_files_share
{
    local shareName=$1
    local storageAccountName=$2
    local storageAccountKey=$3

    cat <<EOF > /etc/azlamp_azure_files.credential
username=$storageAccountName
password=$storageAccountKey
EOF
    chmod 600 /etc/azlamp_azure_files.credential
    
    grep -q -s "^//$storageAccountName.file.core.windows.net/azlamp\s\s*/azlamp\s\s*cifs" /etc/fstab && _RET=$? || _RET=$?
    if [ $_RET != "0" ]; then
        echo -e "\n//$storageAccountName.file.core.windows.net/azlamp   /azlamp cifs    credentials=/etc/azlamp_azure_files.credential,uid=www-data,gid=www-data,nofail,vers=3.0,dir_mode=0770,file_mode=0660,serverino,mfsymlinks" >> /etc/fstab
    fi
    mkdir -p /azlamp
    mount /azlamp
}

function setup_azlamp_mount_dependency_for_systemd_service
{
  local serviceName=$1 # E.g., nginx, apache2
  if [ -z "$serviceName" ]; then
    return 1
  fi

  local systemdSvcOverrideFileDir="/etc/systemd/system/${serviceName}.service.d"
  local systemdSvcOverrideFilePath="${systemdSvcOverrideFileDir}/azlamp_override.conf"

  grep -q -s "After=azlamp.mount" $systemdSvcOverrideFilePath && _RET=$? || _RET=$?
  if [ $_RET != "0" ]; then
    mkdir -p $systemdSvcOverrideFileDir
    cat <<EOF > $systemdSvcOverrideFilePath
[Unit]
After=azlamp.mount
EOF
    systemctl daemon-reload
  fi
}

# Functions for making NFS share available
# TODO refactor these functions with the same ones in install_gluster.sh
function scan_for_new_disks
{
    local BLACKLIST=${1}    # E.g., /dev/sda|/dev/sdb
    declare -a RET
    local DEVS=$(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$")
    for DEV in ${DEVS};
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

function create_raid0_ubuntu {
    local RAIDDISK=${1}       # E.g., /dev/md1
    local RAIDCHUNKSIZE=${2}  # E.g., 128
    local DISKCOUNT=${3}      # E.g., 4
    shift
    shift
    shift
    local DISKS="$@"

    dpkg -s mdadm && _RET=$? || _RET=$?
    if [ $_RET -eq 1 ];
    then 
        echo "installing mdadm"
        sudo apt-get -y -q install mdadm
    fi
    echo "Creating raid0"
    udevadm control --stop-exec-queue
    echo "yes" | mdadm --create $RAIDDISK --name=data --level=0 --chunk=$RAIDCHUNKSIZE --raid-devices=$DISKCOUNT $DISKS
    udevadm control --start-exec-queue
    mdadm --detail --verbose --scan > /etc/mdadm/mdadm.conf
}

function do_partition {
    # This function creates one (1) primary partition on the
    # disk device, using all available space
    local DISK=${1}   # E.g., /dev/sdc

    echo "Partitioning disk $DISK"
    echo -ne "n\np\n1\n\n\nw\n" | fdisk "${DISK}" 
    #> /dev/null 2>&1

    #
    # Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
    # from fdisk and not from echo
    if [ ${PIPESTATUS[1]} -ne 0 ];
    then
        echo "An error occurred partitioning ${DISK}" >&2
        echo "I cannot continue" >&2
        exit 2
    fi
}

function add_local_filesystem_to_fstab {
    local UUID=${1}
    local MOUNTPOINT=${2}   # E.g., /azlamp

    grep -q -s "${UUID}" /etc/fstab && _RET=$? || _RET=$?
    if [ $_RET -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="\nUUID=${UUID} ${MOUNTPOINT} ext4 defaults,noatime 0 0"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

function setup_raid_disk_and_filesystem {
    local MOUNTPOINT=${1}     # E.g., /azlamp
    local RAIDDISK=${2}       # E.g., /dev/md1
    local RAIDPARTITION=${3}  # E.g., /dev/md1p1
    local CREATE_FILESYSTEM=${4}  # E.g., "" (true) or any non-empty string (false)

    local DISKS=$(scan_for_new_disks "/dev/sda|/dev/sdb")
    echo "Disks are ${DISKS}"
    declare -i DISKCOUNT
    local DISKCOUNT=$(echo "$DISKS" | wc -w) 
    echo "Disk count is $DISKCOUNT"
    if [ $DISKCOUNT = "0" ]; then
        echo "No new (unpartitioned) disks available... Returning non-zero..."
        return 1
    fi

    if [ $DISKCOUNT -gt 1 ]; then
        create_raid0_ubuntu ${RAIDDISK} 128 $DISKCOUNT $DISKS
        AZMDL_DISK=$RAIDDISK
        if [ -z "$CREATE_FILESYSTEM" ]; then
          do_partition ${RAIDDISK}
          local PARTITION="${RAIDPARTITION}"
        fi
    else # Just one unpartitioned disk
        AZMDL_DISK=$DISKS
        if [ -z "$CREATE_FILESYSTEM" ]; then
          do_partition ${DISKS}
          local PARTITION=$(fdisk -l ${DISKS}|grep -A 1 Device|tail -n 1|awk '{print $1}')
        fi
    fi

    echo "Disk (RAID if multiple unpartitioned disks, or as is if only one unpartitioned disk) is set up, and env var AZMDL_DISK is set to '$AZMDL_DISK' for later reference"

    if [ -z "$CREATE_FILESYSTEM" ]; then
      echo "Creating filesystem on ${PARTITION}."
      mkfs -t ext4 ${PARTITION}
      mkdir -p "${MOUNTPOINT}"
      local UUID=$(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3}'|tr -d "\"")
      add_local_filesystem_to_fstab "${UUID}" "${MOUNTPOINT}"
      echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
      mount "${MOUNTPOINT}"
    fi
}

function configure_nfs_server_and_export {
    local MOUNTPOINT=${1}     # E.g., /azlamp

    echo "Installing nfs server..."
    apt install -y nfs-kernel-server

    echo "Exporting ${MOUNTPOINT}..."
    grep -q -s "^${MOUNTPOINT}" /etc/exports && _RET=$? || _RET=$?
    if [ $_RET = "0" ]; then
        echo "${MOUNTPOINT} is already exported. Returning..."
    else
        echo -e "\n${MOUNTPOINT}   *(rw,sync,no_root_squash)" >> /etc/exports
        systemctl restart nfs-kernel-server.service
    fi
}

function configure_nfs_client_and_mount0 {
    local NFS_HOST_EXPORT_PATH=${1}   # E.g., controller-vm-ab12cd:/azlamp or 172.16.3.100:/drbd/data
    local MOUNTPOINT=${2}             # E.g., /azlamp

    apt install -y nfs-common
    mkdir -p ${MOUNTPOINT}

    grep -q -s "^${NFS_HOST_EXPORT_PATH}" /etc/fstab && _RET=$? || _RET=$?
    if [ $_RET = "0" ]; then
        echo "${NFS_HOST_EXPORT_PATH} already in /etc/fstab... skipping to add"
    else
        echo -e "\n${NFS_HOST_EXPORT_PATH}    ${MOUNTPOINT}    nfs    auto    0    0" >> /etc/fstab
    fi
    mount ${MOUNTPOINT}
}

function configure_nfs_client_and_mount {
    local NFS_SERVER=${1}     # E.g., controller-vm-ab12cd or IP (NFS-HA LB)
    local NFS_DIR=${2}        # E.g., /azlamp or /drbd/data
    local MOUNTPOINT=${3}     # E.g., /azlamp

    configure_nfs_client_and_mount0 "${NFS_SERVER}:${NFS_DIR}" ${MOUNTPOINT}
}

SERVER_TIMESTAMP_FULLPATH="/azlamp/html/.last_modified_time.azlamp"
LOCAL_TIMESTAMP_FULLPATH="/var/www/html/.last_modified_time.azlamp"

# Create a script to sync /azlamp/html (gluster/NFS) and /var/www/html (local) and set up a minutely cron job
# Should be called by root and only on a VMSS web frontend VM
function setup_html_local_copy_cron_job {
  if [ "$(whoami)" != "root" ]; then
    echo "${0}: Must be run as root!"
    return 1
  fi

  local SYNC_SCRIPT_FULLPATH="/usr/local/bin/sync_azlamp_html_local_copy_if_modified.sh"
  mkdir -p $(dirname ${SYNC_SCRIPT_FULLPATH})

  local SYNC_LOG_FULLPATH="/var/log/azlamp-html-sync.log"

  cat <<EOF > ${SYNC_SCRIPT_FULLPATH}
#!/bin/bash

sleep \$((\$RANDOM%30))

if [ -f "$SERVER_TIMESTAMP_FULLPATH" ]; then
  SERVER_TIMESTAMP=\$(cat $SERVER_TIMESTAMP_FULLPATH)
  if [ -f "$LOCAL_TIMESTAMP_FULLPATH" ]; then
    LOCAL_TIMESTAMP=\$(cat $LOCAL_TIMESTAMP_FULLPATH)
  else
    logger -p local2.notice -t azlamp "Local timestamp file ($LOCAL_TIMESTAMP_FULLPATH) does not exist. Probably first time syncing? Continuing to sync."
    mkdir -p /var/www/html
  fi
  if [ "\$SERVER_TIMESTAMP" != "\$LOCAL_TIMESTAMP" ]; then
    logger -p local2.notice -t moodle "Server time stamp (\$SERVER_TIMESTAMP) is different from local time stamp (\$LOCAL_TIMESTAMP). Start syncing..."
    if [[ \$(find $SYNC_LOG_FULLPATH -type f -size +20M 2> /dev/null) ]]; then
      truncate -s 0 $SYNC_LOG_FULLPATH
    fi
    echo \$(date +%Y%m%d%H%M%S) >> $SYNC_LOG_FULLPATH
    rsync -av --delete /azlamp/html/. /var/www/html >> $SYNC_LOG_FULLPATH
  fi
else
  logger -p local2.notice -t azlamp "Remote timestamp file ($SERVER_TIMESTAMP_FULLPATH) does not exist. Is /azlamp mounted? Exiting with error."
  exit 1
fi
EOF
  chmod 500 ${SYNC_SCRIPT_FULLPATH}

  local CRON_DESC_FULLPATH="/etc/cron.d/sync-azlamp-html-local-copy"
  cat <<EOF > ${CRON_DESC_FULLPATH}
* * * * * root ${SYNC_SCRIPT_FULLPATH}
EOF
  chmod 644 ${CRON_DESC_FULLPATH}

  # Addition of a hook for custom script run on VMSS from shared mount to allow customised configuration of the VMSS as required
  local CRON_DESC_FULLPATH2="/etc/cron.d/update-vmss-config"
  cat <<EOF > ${CRON_DESC_FULLPATH2}
* * * * * root [ -f /azlamp/bin/update-vmss-config ] && /bin/bash /azlamp/bin/update-vmss-config
EOF
  chmod 644 ${CRON_DESC_FULLPATH2}
}

LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH="/usr/local/bin/update_last_modified_time.azlamp.sh"

# Create a script to modify the last modified timestamp file (/azlamp/html/.last_modified_time.azlamp)
# Should be called by root and only on the controller VM.
# The moodle admin should run the generated script everytime the /azlamp/html directory content is updated (e.g., moodle upgrade, config change or plugin install/upgrade)
function create_last_modified_time_update_script {
  if [ "$(whoami)" != "root" ]; then
    echo "${0}: Must be run as root!"
    return 1
  fi

  mkdir -p $(dirname $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH)
  cat <<EOF > $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH
#!/bin/bash
echo \$(date +%Y%m%d%H%M%S) > $SERVER_TIMESTAMP_FULLPATH
EOF

  chmod +x $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH
}

function run_once_last_modified_time_update_script {
  $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH
}

# O365 plugins are released only for 'MOODLE_xy_STABLE',
# whereas we want to support the Moodle tagged versions (e.g., 'v3.4.2').
# This function helps getting the stable version # (for O365 plugin ver.)
# from a Moodle version tag. This utility function recognizes tag names
# of the form 'vx.y.z' only.
function get_o365plugin_version_from_moodle_version {
  local moodleVersion=${1}
  if [[ "$moodleVersion" =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    echo "MOODLE_${BASH_REMATCH[1]}${BASH_REMATCH[2]}_STABLE"
  else
    echo $moodleVersion
  fi
}

# For Moodle tags (e.g., "v3.4.2"), the unzipped Moodle dir is no longer
# "moodle-$moodleVersion", because for tags, it's without "v". That is,
# it's "moodle-3.4.2". Therefore, we need a separate helper function for that...
function get_moodle_unzip_dir_from_moodle_version {
  local moodleVersion=${1}
  if [[ "$moodleVersion" =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    echo "moodle-${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  else
    echo "moodle-$moodleVersion"
  fi
}

function config_one_site_on_vmss
{
  local siteFQDN=${1}             # E.g., "moodle.univ1.edu". Will be used as the site's HTML subdirectory name in /azlamp/html (as /azlamp/html/$siteFQDN)
  local htmlLocalCopySwitch=${2}  # "true" or anything else (don't care)
  local httpsTermination=${3}     # "VMSS" or "None"
  local webServerType=${4}        # "apache" or "nginx"

  # Find the correct htmlRootDir depending on the htmlLocalCopySwitch
  if [ "$htmlLocalCopySwitch" = "true" ]; then
    local htmlRootDir="/var/www/html/$siteFQDN"
  else
    local htmlRootDir="/azlamp/html/$siteFQDN"
  fi

  local certsDir="/azlamp/certs/$siteFQDN"

  if [ "$httpsTermination" = "VMSS" ]; then
    # Configure nginx/https
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
        listen 443 ssl;
        root ${htmlRootDir};
        index index.php index.html index.htm;
        server_name ${siteFQDN};

        ssl on;
        ssl_certificate ${certsDir}/nginx.crt;
        ssl_certificate_key ${certsDir}/nginx.key;

        # Log to syslog
        error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
        access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

        # Log XFF IP instead of varnish
        set_real_ip_from    10.0.0.0/8;
        set_real_ip_from    127.0.0.1;
        set_real_ip_from    172.16.0.0/12;
        set_real_ip_from    192.168.0.0/16;
        real_ip_header      X-Forwarded-For;
        real_ip_recursive   on;

        location / {
          proxy_set_header Host \$host;
          proxy_set_header HTTP_REFERER \$http_referer;
          proxy_set_header X-Forwarded-Host \$host;
          proxy_set_header X-Forwarded-Server \$host;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_pass http://localhost:80;

          proxy_connect_timeout       3600;
          proxy_send_timeout          3600;
          proxy_read_timeout          3600;
          send_timeout                3600;
        }
}
EOF
  fi

  if [ "$webServerType" = "nginx" ]; then
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
        listen 81 default;
        server_name ${siteFQDN};
        root ${htmlRootDir};
	      index index.php index.html index.htm;

        # Log to syslog
        error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
        access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

        # Log XFF IP instead of varnish
        set_real_ip_from    10.0.0.0/8;
        set_real_ip_from    127.0.0.1;
        set_real_ip_from    172.16.0.0/12;
        set_real_ip_from    192.168.0.0/16;
        real_ip_header      X-Forwarded-For;
        real_ip_recursive   on;
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
        # Redirect to https
        if (\$http_x_forwarded_proto != https) {
                return 301 https://\$server_name\$request_uri;
        }
        rewrite ^/(.*\.php)(/)(.*)$ /\$1?file=/\$3 last;
EOF
    fi
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
        # Filter out php-fpm status page
        location ~ ^/server-status {
            return 404;
        }

        location / {
          try_files \$uri \$uri/index.php?\$query_string;
        }
 
        location ~ [^/]\.php(/|$) {
          fastcgi_split_path_info ^(.+?\.php)(/.*)$;
          if (!-f \$document_root\$fastcgi_script_name) {
                  return 404;
          }
 
          fastcgi_buffers 16 16k;
          fastcgi_buffer_size 32k;
          fastcgi_param   SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          fastcgi_pass unix:/run/php/php${PhpVer}-fpm.sock;
          fastcgi_read_timeout 3600;
          fastcgi_index index.php;
          include fastcgi_params;
        }
}

EOF
  fi # if [ "$webServerType" = "nginx" ];

  if [ "$webServerType" = "apache" ]; then
    # Configure Apache/php
    cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
<VirtualHost *:81>
	ServerName ${siteFQDN}

	ServerAdmin webmaster@localhost
	DocumentRoot ${htmlRootDir}

	<Directory ${htmlRootDir}>
		Options FollowSymLinks
		AllowOverride All
		Require all granted
	</Directory>
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
    # Redirect unencrypted direct connections to HTTPS
    <IfModule mod_rewrite.c>
      RewriteEngine on
      RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]
      RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [L,R=301]
    </IFModule>
EOF
    fi
    cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
    # Log X-Forwarded-For IP address instead of varnish (127.0.0.1)
    SetEnvIf X-Forwarded-For "^.*\..*\..*\..*" forwarded
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" forwarded
	  ErrorLog "|/usr/bin/logger -t azlamp -p local1.error"
    CustomLog "|/usr/bin/logger -t azlamp -p local1.notice" combined env=!forwarded
    CustomLog "|/usr/bin/logger -t azlamp -p local1.notice" forwarded env=forwarded

</VirtualHost>
EOF
  fi # if [ "$webServerType" = "apache" ];
} # function config_one_site_on_vmss

function config_all_sites_on_vmss
{
  local htmlLocalCopySwitch=${1}  # "true" or anything else (don't care)
  local httpsTermination=${2}     # "VMSS" or "None"
  local webServerType=${3}        # "apache" or "nginx"

  local allSites=$(ls /azlamp/html)
  for site in $allSites; do
    config_one_site_on_vmss $site $htmlLocalCopySwitch $httpsTermination $webServerType
  done
}

# To be used after the initial deployment on any site addition/deletion
function reset_all_sites_on_vmss
{
  local htmlLocalCopySwitch=${1}  # "true" or anything else (don't care)
  local httpsTermination=${2}     # "VMSS" or "None"
  local webServerType=${3}        # "apache" or "nginx"

  if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
    rm /etc/nginx/sites-enabled/*
  fi
  if [ "$webServerType" = "apache" ]; then
    rm /etc/apache2/sites-enabled/*
  fi

  config_all_sites_on_vmss $htmlLocalCopySwitch $httpsTermination $webServerType

  if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
    sudo service nginx restart 
  fi
  if [ "$webServerType" = "apache" ]; then
    sudo service apache2 restart
  fi
}

function create_main_nginx_conf_on_controller
{
    local httpsTermination=${1} # "None" or anything else

    cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes 2;
pid /run/nginx.pid;

events {
	worker_connections 768;
}

http {

  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  client_max_body_size 0;
  proxy_max_temp_file_size 0;
  server_names_hash_bucket_size  128;
  fastcgi_buffers 16 16k;
  fastcgi_buffer_size 32k;
  proxy_buffering off;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  set_real_ip_from   127.0.0.1;
  real_ip_header      X-Forwarded-For;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
  ssl_prefer_server_ciphers on;

  gzip on;
  gzip_disable "msie6";
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
EOF

    if [ "$httpsTermination" != "None" ]; then
        cat <<EOF >> /etc/nginx/nginx.conf
  map \$http_x_forwarded_proto \$fastcgi_https {
    default \$https;
    http '';
    https on;
  }
EOF
    fi

    cat <<EOF >> /etc/nginx/nginx.conf
  log_format moodle_combined '\$remote_addr - \$upstream_http_x_moodleuser [\$time_local] '
                             '"\$request" \$status \$body_bytes_sent '
                             '"\$http_referer" "\$http_user_agent"';


  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF
}

function create_per_site_nginx_conf_on_controller
{
    local siteFQDN=${1}
    local httpsTermination=${2} # "None", "VMSS", etc
    local htmlDir=${3}          # E.g., /azlamp/html/site1.org
    local certsDir=${4}         # E.g., /azlamp/certs/site1.org

    cat <<EOF > /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
    listen 81 default;
    server_name ${siteFQDN};
    root ${moodleHtmlDir};
    index index.php index.html index.htm;

    # Log to syslog
    error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
    access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

    # Log XFF IP instead of varnish
    set_real_ip_from    10.0.0.0/8;
    set_real_ip_from    127.0.0.1;
    set_real_ip_from    172.16.0.0/12;
    set_real_ip_from    192.168.0.0/16;
    real_ip_header      X-Forwarded-For;
    real_ip_recursive   on;
EOF
    if [ "$httpsTermination" != "None" ]; then
        cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
    # Redirect to https
    if (\$http_x_forwarded_proto != https) {
            return 301 https://\$server_name\$request_uri;
    }
    rewrite ^/(.*\.php)(/)(.*)$ /\$1?file=/\$3 last;
EOF
    fi

    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
    # Filter out php-fpm status page
    location ~ ^/server-status {
        return 404;
    }

    location / {
        try_files \$uri \$uri/index.php?\$query_string;
    }

    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        if (!-f \$document_root\$fastcgi_script_name) {
                return 404;
        }

        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_param   SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php${PhpVer}-fpm.sock;
        fastcgi_read_timeout 3600;
        fastcgi_index index.php;
        include fastcgi_params;
    }
}
EOF
    if [ "$httpsTermination" = "VMSS" ]; then
        cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
    listen 443 ssl;
    root ${htmlDir};
    index index.php index.html index.htm;

    ssl on;
    ssl_certificate ${certsDir}/nginx.crt;
    ssl_certificate_key ${certsDir}/nginx.key;

    # Log to syslog
    error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
    access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

    # Log XFF IP instead of varnish
    set_real_ip_from    10.0.0.0/8;
    set_real_ip_from    127.0.0.1;
    set_real_ip_from    172.16.0.0/12;
    set_real_ip_from    192.168.0.0/16;
    real_ip_header      X-Forwarded-For;
    real_ip_recursive   on;

    location / {
      proxy_set_header Host \$host;
      proxy_set_header HTTP_REFERER \$http_referer;
      proxy_set_header X-Forwarded-Host \$host;
      proxy_set_header X-Forwarded-Server \$host;
      proxy_set_header X-Forwarded-Proto https;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_pass http://localhost:80;
    }
}
EOF
    fi
}

function create_per_site_nginx_ssl_certs_on_controller
{
    local siteFQDN=${1}
    local certsDir=${2}
    local httpsTermination=${3}
    local thumbprintSslCert=${4}
    local thumbprintCaCert=${5}

    if [ "$httpsTermination" = "VMSS" ]; then
        ### SSL cert ###
        if [ "$thumbprintSslCert" != "None" ]; then
            echo "Using VM's cert (/var/lib/waagent/$thumbprintSslCert.*) for SSL..."
            cat /var/lib/waagent/$thumbprintSslCert.prv > $certsDir/nginx.key
            cat /var/lib/waagent/$thumbprintSslCert.crt > $certsDir/nginx.crt
            if [ "$thumbprintCaCert" != "None" ]; then
                echo "CA cert was specified (/var/lib/waagent/$thumbprintCaCert.crt), so append it to nginx.crt..."
                cat /var/lib/waagent/$thumbprintCaCert.crt >> $certsDir/nginx.crt
            fi
        else
            echo -e "Generating SSL self-signed certificate"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $certsDir/nginx.key -out $certsDir/nginx.crt -subj "/C=US/ST=WA/L=Redmond/O=IT/CN=$siteFQDN"
        fi
        chown -R www-data:www-data $certsDir
        chmod 0400 $certsDir/*
    fi
}

function download_and_place_per_site_moodle_and_plugins_on_controller
{
    local moodleVersion=${1}
    local moodleHtmlDir=${2}
    local installGdprPluginsSwitch=${3}
    local installO365pluginsSwitch=${4}
    local searchType=${5}
    local installObjectFsSwitch=${6}

    local o365pluginVersion=$(get_o365plugin_version_from_moodle_version $moodleVersion)
    local moodleStableVersion=$o365pluginVersion  # Need Moodle stable version for GDPR plugins, and o365pluginVersion is just Moodle stable version, so reuse it.
    local moodleUnzipDir=$(get_moodle_unzip_dir_from_moodle_version $moodleVersion)

    mkdir -p /azlamp/tmp
    cd /azlamp/tmp

    if [ ! -d $moodleHtmlDir ]; then
        # downloading moodle only if $moodleHtmlDir does not exist -- if it exists, user should populate it in advance correctly as below. This is to reduce template deployment time.
        /usr/bin/curl -k --max-redirs 10 https://github.com/moodle/moodle/archive/$moodleVersion.zip -L -o moodle.zip
        /usr/bin/unzip -q moodle.zip
        /bin/mv $moodleUnzipDir $moodleHtmlDir
    fi

    if [ "$installGdprPluginsSwitch" = "true" ]; then
        # install Moodle GDPR plugins (Note: This is only for Moodle versions 3.4.2+ or 3.3.5+ and will be included in Moodle 3.5, so no need for 3.5)
        curl -k --max-redirs 10 https://github.com/moodlehq/moodle-tool_policy/archive/$moodleStableVersion.zip -L -o plugin-policy.zip
        unzip -q plugin-policy.zip
        mv moodle-tool_policy-$moodleStableVersion $moodleHtmlDir/admin/tool/policy

        curl -k --max-redirs 10 https://github.com/moodlehq/moodle-tool_dataprivacy/archive/$moodleStableVersion.zip -L -o plugin-dataprivacy.zip
        unzip -q plugin-dataprivacy.zip
        mv moodle-tool_dataprivacy-$moodleStableVersion $moodleHtmlDir/admin/tool/dataprivacy
    fi

    if [ "$installO365pluginsSwitch" = "true" ]; then
        # install Office 365 plugins
        curl -k --max-redirs 10 https://github.com/Microsoft/o365-moodle/archive/$o365pluginVersion.zip -L -o o365.zip
        unzip -q o365.zip
        cp -r o365-moodle-$o365pluginVersion/* $moodleHtmlDir
        rm -rf o365-moodle-$o365pluginVersion
    fi

    if [ "$searchType" = "elastic" ]; then
        # Install ElasticSearch plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-search_elastic/archive/master.zip -L -o plugin-elastic.zip
        /usr/bin/unzip -q plugin-elastic.zip
        /bin/mv moodle-search_elastic-master $moodleHtmlDir/search/engine/elastic

        # Install ElasticSearch plugin dependency
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-local_aws/archive/master.zip -L -o local-aws.zip
        /usr/bin/unzip -q local-aws.zip
        /bin/mv moodle-local_aws-master $moodleHtmlDir/local/aws

    elif [ "$searchType" = "azure" ]; then
        # Install Azure Search service plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-search_azure/archive/master.zip -L -o plugin-azure-search.zip
        /usr/bin/unzip -q plugin-azure-search.zip
        /bin/mv moodle-search_azure-master $moodleHtmlDir/search/engine/azure
    fi

    if [ "$installObjectFsSwitch" = "true" ]; then
        # Install the ObjectFS plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-tool_objectfs/archive/master.zip -L -o plugin-objectfs.zip
        /usr/bin/unzip -q plugin-objectfs.zip
        /bin/mv moodle-tool_objectfs-master $moodleHtmlDir/admin/tool/objectfs

        # Install the ObjectFS Azure library
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-local_azure_storage/archive/master.zip -L -o plugin-azurelibrary.zip
        /usr/bin/unzip -q plugin-azurelibrary.zip
        /bin/mv moodle-local_azure_storage-master $moodleHtmlDir/local/azure_storage
    fi
    cd /azlamp
    rm -rf /azlamp/tmp
}

function setup_and_config_per_site_moodle_on_controller
{
    local httpsTermination=${1}
    local siteFQDN=${2}
    local dbServerType=${3}
    local moodleHtmlDir=${4}
    local moodleDataDir=${5}
    local dbIP=${6}
    local moodledbname=${7}
    local azuremoodledbuser=${8}
    local moodledbpass=${9}
    local adminpass=${10}

    if [ "$httpsTermination" = "None" ]; then
        local siteProtocol="http"
    else
        local siteProtocol="https"
    fi
    if [ $dbServerType = "mysql" ]; then
        local dbtype="mysqli"
    elif [ $dbServerType = "mssql" ]; then
        local dbtype="sqlsrv"
    else # $dbServerType = "postgres"
        local dbtype="pgsql"
    fi
    cd /tmp; /usr/bin/php $moodleHtmlDir/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=$siteProtocol://$siteFQDN   --dataroot=$moodleDataDir --dbhost=$dbIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=$dbtype --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

    echo -e "\n\rDone! Installation completed!\n\r"

    local configPhpPath="$moodleHtmlDir/config.php"

    if [ "$httpsTermination" != "None" ]; then
        # We proxy ssl, so moodle needs to know this
        sed -i "23 a \$CFG->sslproxy  = 'true';" $configPhpPath
    fi

    # Make sure the config.php is readable for web server process (www-data). The initial permission might be readable only for creator (root in our case).
    chmod +r $configPhpPath
    # Also make sure to update moodleDataDir's owner (to be writable for www-data web server process)
    chown -R www-data.www-data $moodleDataDir
}

function setup_per_site_moodle_cron_jobs
{
    local moodleHtmlDir=${1}
    local siteFQDN=${2}
    local dbServerType=${3}
    local dbIP=${4}
    local moodledbname=${5}
    local azuremoodledbuser=${6}
    local moodledbpass=${7}

    # create cron entry
    # It is scheduled for once per minute. It can be changed as needed.
    echo '* * * * * www-data /usr/bin/php '$moodleHtmlDir'/admin/cli/cron.php 2>&1 | /usr/bin/logger -p local2.notice -t moodle' > /etc/cron.d/moodle-cron-$siteFQDN

    # Set up cronned sql dump
    sqlBackupCronDefPath="/etc/cron.d/moodle-sql-backup-$siteFQDN"
    if [ "$dbServerType" = "mysql" ]; then
        cat <<EOF > $sqlBackupCronDefPath
  22 02 * * * root /usr/bin/mysqldump -h $dbIP -u ${azuremoodledbuser} -p'${moodledbpass}' --databases ${moodledbname} | gzip > /azlamp/data/$siteFQDN/db-backup.sql.gz
EOF
    elif [ "$dbServerType" = "postgres" ]; then
        cat <<EOF > $sqlBackupCronDefPath
  22 02 * * * root /usr/bin/pg_dump -Fc -h $dbIP -U ${azuremoodledbuser} ${moodledbname} > /azlamp/data/$siteFQDN/db-backup.sql
EOF
    #else # mssql. TODO It's missed earlier! Complete this!
    fi
}

function update_php_config_on_controller
{
    # php config
    PhpVer=$(get_php_version)
    PhpIni=/etc/php/${PhpVer}/fpm/php.ini
    sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
    sed -i "s/max_execution_time.*/max_execution_time = 18000/" $PhpIni
    sed -i "s/max_input_vars.*/max_input_vars = 100000/" $PhpIni
    sed -i "s/max_input_time.*/max_input_time = 600/" $PhpIni
    sed -i "s/upload_max_filesize.*/upload_max_filesize = 1024M/" $PhpIni
    sed -i "s/post_max_size.*/post_max_size = 1056M/" $PhpIni
    sed -i "s/;opcache.use_cwd.*/opcache.use_cwd = 1/" $PhpIni
    sed -i "s/;opcache.validate_timestamps.*/opcache.validate_timestamps = 1/" $PhpIni
    sed -i "s/;opcache.save_comments.*/opcache.save_comments = 1/" $PhpIni
    sed -i "s/;opcache.enable_file_override.*/opcache.enable_file_override = 0/" $PhpIni
    sed -i "s/;opcache.enable.*/opcache.enable = 1/" $PhpIni
    sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 256/" $PhpIni
    sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 8000/" $PhpIni

    # fpm config - overload this
    cat <<EOF > /etc/php/${PhpVer}/fpm/pool.d/www.conf
[www]
user = www-data
group = www-data
listen = /run/php/php${PhpVer}-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 3000
pm.start_servers = 20
pm.min_spare_servers = 22
pm.max_spare_servers = 30
EOF
}

function configure_varnish_on_controller
{
    # Configure varnish startup for 16.04
    VARNISHSTART="ExecStart=\/usr\/sbin\/varnishd -j unix,user=vcache -F -a :80 -T localhost:6082 -f \/etc\/varnish\/moodle.vcl -S \/etc\/varnish\/secret -s malloc,1024m -p thread_pool_min=200 -p thread_pool_max=4000 -p thread_pool_add_delay=2 -p timeout_linger=100 -p timeout_idle=30 -p send_timeout=1800 -p thread_pools=4 -p http_max_hdr=512 -p workspace_backend=512k"
    sed -i "s/^ExecStart.*/${VARNISHSTART}/" /lib/systemd/system/varnish.service

    # Configure varnish VCL for moodle
    cat <<EOF >> /etc/varnish/moodle.vcl
vcl 4.0;

import std;
import directors;
backend default {
    .host = "localhost";
    .port = "81";
    .first_byte_timeout = 3600s;
    .connect_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_recv {
    # Varnish does not support SPDY or HTTP/2.0 untill we upgrade to Varnish 5.0
    if (req.method == "PRI") {
        return (synth(405));
    }

    if (req.restarts == 0) {
      if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
      } else {
        set req.http.X-Forwarded-For = client.ip;
      }
    }

    # Non-RFC2616 or CONNECT HTTP requests methods filtered. Pipe requests directly to backend
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {
      return (pipe);
    }

    # Varnish don't mess with healthchecks
    if (req.url ~ "^/admin/tool/heartbeat" || req.url ~ "^/healthcheck.php")
    {
        return (pass);
    }

    # Pipe requests to backup.php straight to backend - prevents problem with progress bar long polling 503 problem
    # This is here because backup.php is POSTing to itself - Filter before !GET&&!HEAD
    if (req.url ~ "^/backup/backup.php")
    {
        return (pipe);
    }

    # Varnish only deals with GET and HEAD by default. If request method is not GET or HEAD, pass request to backend
    if (req.method != "GET" && req.method != "HEAD") {
      return (pass);
    }

    ### Rules for Moodle and Totara sites ###
    # Moodle doesn't require Cookie to serve following assets. Remove Cookie header from request, so it will be looked up.
    if ( req.url ~ "^/altlogin/.+/.+\.(png|jpg|jpeg|gif|css|js|webp)$" ||
         req.url ~ "^/pix/.+\.(png|jpg|jpeg|gif)$" ||
         req.url ~ "^/theme/font.php" ||
         req.url ~ "^/theme/image.php" ||
         req.url ~ "^/theme/javascript.php" ||
         req.url ~ "^/theme/jquery.php" ||
         req.url ~ "^/theme/styles.php" ||
         req.url ~ "^/theme/yui" ||
         req.url ~ "^/lib/javascript.php/-1/" ||
         req.url ~ "^/lib/requirejs.php/-1/"
        )
    {
        set req.http.X-Long-TTL = "86400";
        unset req.http.Cookie;
        return(hash);
    }

    # Perform lookup for selected assets that we know are static but Moodle still needs a Cookie
    if(  req.url ~ "^/theme/.+\.(png|jpg|jpeg|gif|css|js|webp)" ||
         req.url ~ "^/lib/.+\.(png|jpg|jpeg|gif|css|js|webp)" ||
         req.url ~ "^/pluginfile.php/[0-9]+/course/overviewfiles/.+\.(?i)(png|jpg)$"
      )
    {
         # Set internal temporary header, based on which we will do things in vcl_backend_response
         set req.http.X-Long-TTL = "86400";
         return (hash);
    }

    # Serve requests to SCORM checknet.txt from varnish. Have to remove get parameters. Response body always contains "1"
    if ( req.url ~ "^/lib/yui/build/moodle-core-checknet/assets/checknet.txt" )
    {
        set req.url = regsub(req.url, "(.*)\?.*", "\1");
        unset req.http.Cookie; # Will go to hash anyway at the end of vcl_recv
        set req.http.X-Long-TTL = "86400";
        return(hash);
    }

    # Requests containing "Cookie" or "Authorization" headers will not be cached
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    # Almost everything in Moodle correctly serves Cache-Control headers, if
    # needed, which varnish will honor, but there are some which don't. Rather
    # than explicitly finding them all and listing them here we just fail safe
    # and don't cache unknown urls that get this far.
    return (pass);
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    # 
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # We know these assest are static, let's set TTL >0 and allow client caching
    if ( beresp.http.Cache-Control && bereq.http.X-Long-TTL && beresp.ttl < std.duration(bereq.http.X-Long-TTL + "s", 1s) && !beresp.http.WWW-Authenticate )
    { # If max-age < defined in X-Long-TTL header
        set beresp.http.X-Orig-Pragma = beresp.http.Pragma; unset beresp.http.Pragma;
        set beresp.http.X-Orig-Cache-Control = beresp.http.Cache-Control;
        set beresp.http.Cache-Control = "public, max-age="+bereq.http.X-Long-TTL+", no-transform";
        set beresp.ttl = std.duration(bereq.http.X-Long-TTL + "s", 1s);
        unset bereq.http.X-Long-TTL;
    }
    else if( !beresp.http.Cache-Control && bereq.http.X-Long-TTL && !beresp.http.WWW-Authenticate ) {
        set beresp.http.X-Orig-Pragma = beresp.http.Pragma; unset beresp.http.Pragma;
        set beresp.http.Cache-Control = "public, max-age="+bereq.http.X-Long-TTL+", no-transform";
        set beresp.ttl = std.duration(bereq.http.X-Long-TTL + "s", 1s);
        unset bereq.http.X-Long-TTL;
    }
    else { # Don't touch headers if max-age > defined in X-Long-TTL header
        unset bereq.http.X-Long-TTL;
    }

    # Here we set X-Trace header, prepending it to X-Trace header received from backend. Useful for troubleshooting
    if(beresp.http.x-trace && !beresp.was_304) {
        set beresp.http.X-Trace = regsub(server.identity, "^([^.]+),?.*$", "\1")+"->"+regsub(beresp.backend.name, "^(.+)\((?:[0-9]{1,3}\.){3}([0-9]{1,3})\)","\1(\2)")+"->"+beresp.http.X-Trace;
    }
    else {
        set beresp.http.X-Trace = regsub(server.identity, "^([^.]+),?.*$", "\1")+"->"+regsub(beresp.backend.name, "^(.+)\((?:[0-9]{1,3}\.){3}([0-9]{1,3})\)","\1(\2)");
    }

    # Gzip JS, CSS is done at the ngnix level doing it here dosen't respect the no buffer requsets
    # if (beresp.http.content-type ~ "application/javascript.*" || beresp.http.content-type ~ "text") {
    #    set beresp.do_gzip = true;
    #}
}

sub vcl_deliver {

    # Revert back to original Cache-Control header before delivery to client
    if (resp.http.X-Orig-Cache-Control)
    {
        set resp.http.Cache-Control = resp.http.X-Orig-Cache-Control;
        unset resp.http.X-Orig-Cache-Control;
    }

    # Revert back to original Pragma header before delivery to client
    if (resp.http.X-Orig-Pragma)
    {
        set resp.http.Pragma = resp.http.X-Orig-Pragma;
        unset resp.http.X-Orig-Pragma;
    }

    # (Optional) X-Cache HTTP header will be added to responce, indicating whether object was retrieved from backend, or served from cache
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # Set X-AuthOK header when totara/varnsih authentication succeeded
    if (req.http.X-AuthOK) {
        set resp.http.X-AuthOK = req.http.X-AuthOK;
    }

    # If desired "Via: 1.1 Varnish-v4" response header can be removed from response
    unset resp.http.Via;
    unset resp.http.Server;

    return(deliver);
}

sub vcl_backend_error {
    # More comprehensive varnish error page. Display time, instance hostname, host header, url for easier troubleshooting.
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    set beresp.http.Retry-After = "5";
    synthetic( {"
  <!DOCTYPE html>
  <html>
    <head>
      <title>"} + beresp.status + " " + beresp.reason + {"</title>
    </head>
    <body>
      <h1>Error "} + beresp.status + " " + beresp.reason + {"</h1>
      <p>"} + beresp.reason + {"</p>
      <h3>Guru Meditation:</h3>
      <p>Time: "} + now + {"</p>
      <p>Node: "} + server.hostname + {"</p>
      <p>Host: "} + bereq.http.host + {"</p>
      <p>URL: "} + bereq.url + {"</p>
      <p>XID: "} + bereq.xid + {"</p>
      <hr>
      <p>Varnish cache server
    </body>
  </html>
  "} );
   return (deliver);
}

sub vcl_synth {

    #Redirect using '301 - Permanent Redirect', permanent redirect
    if (resp.status == 851) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 301;
        return (deliver);
    }

    #Redirect using '302 - Found', temporary redirect
    if (resp.status == 852) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 302;
        return (deliver);
    }

    #Redirect using '307 - Temporary Redirect', !GET&&!HEAD requests, dont change method on redirected requests
    if (resp.status == 857) {
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 307;
        return (deliver);
    }

    #Respond with 403 - Forbidden
    if (resp.status == 863) {
        set resp.http.X-Varnish-Error = true;
        set resp.status = 403;
        return (deliver);
    }
}
EOF
}

function create_per_site_sql_db_from_controller
{
    local dbServerType=${1}
    local dbIP=${2}
    local dbadminloginazure=${3}
    local dbadminpass=${4}
    local azlampdbname=${5}
    local azlampdbuser=${6}
    local azlampdbpass=${7}
    local mssqlDbSize=${8}
    local mssqlDbEdition=${9}
    local mssqlDbServiceObjectiveName=${10}

    if [ $dbServerType = "mysql" ]; then
        mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} -e "CREATE DATABASE ${azlampdbname} CHARACTER SET utf8;"
        mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} -e "GRANT ALL ON ${azlampdbname}.* TO ${azlampdbuser} IDENTIFIED BY '${azlampdbpass}';"

        echo "mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} -e \"CREATE DATABASE ${azlampdbname};\"" >> /tmp/debug
        echo "mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} -e \"GRANT ALL ON ${azlampdbname}.* TO ${azlampdbuser} IDENTIFIED BY '${azlampdbpass}';\"" >> /tmp/debug
    elif [ $dbServerType = "mssql" ]; then
        /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -Q "CREATE DATABASE ${azlampdbname} ( MAXSIZE = $mssqlDbSize, EDITION = '$mssqlDbEdition', SERVICE_OBJECTIVE = '$mssqlDbServiceObjectiveName' )"
        /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -Q "CREATE LOGIN ${azlampdbuser} with password = '${azlampdbpass}'"
        /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d ${azlampdbname} -Q "CREATE USER ${azlampdbuser} FROM LOGIN ${azlampdbuser}"
        /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d ${azlampdbname} -Q "exec sp_addrolemember 'db_owner','${azlampdbuser}'"
    else
        # Create postgres db
        echo "${dbIP}:5432:postgres:${dbadminloginazure}:${dbadminpass}" > /root/.pgpass
        chmod 600 /root/.pgpass
        psql -h $dbIP -U $dbadminloginazure -c "CREATE DATABASE ${azlampdbname};" postgres
        psql -h $dbIP -U $dbadminloginazure -c "CREATE USER ${azlampdbuser} WITH PASSWORD '${azlampdbpass}';" postgres
        psql -h $dbIP -U $dbadminloginazure -c "GRANT ALL ON DATABASE ${azlampdbname} TO ${azlampdbuser};" postgres
        rm -f /root/.pgpass
    fi
}

function config_syslog_on_controller
{
    mkdir /var/log/sitelogs
    chown syslog.adm /var/log/sitelogs
    cat <<EOF >> /etc/rsyslog.conf
\$ModLoad imudp
\$UDPServerRun 514
EOF
    cat <<EOF >> /etc/rsyslog.d/40-sitelogs.conf
local1.*   /var/log/sitelogs/azlamp/access.log
local1.err   /var/log/sitelogs/azlamp/error.log
local2.*   /var/log/sitelogs/azlamp/cron.log
EOF
}

# Long Redis cache Moodle config file generation code moved here
function create_redis_configuration_in_moodledata_muc_config_php
{
    local mucConfigPhpPath=$1

    # create redis configuration in .../moodledata/muc/config.php
    cat <<EOF > $mucConfigPhpPath
<?php defined('MOODLE_INTERNAL') || die();
 \$configuration = array (
  'siteidentifier' => '7a142be09ea65699e4a6f6ef91c0773c',
  'stores' => 
  array (
    'default_application' => 
    array (
      'name' => 'default_application',
      'plugin' => 'file',
      'configuration' => 
      array (
      ),
      'features' => 30,
      'modes' => 3,
      'default' => true,
      'class' => 'cachestore_file',
      'lock' => 'cachelock_file_default',
    ),
    'default_session' => 
    array (
      'name' => 'default_session',
      'plugin' => 'session',
      'configuration' => 
      array (
      ),
      'features' => 14,
      'modes' => 2,
      'default' => true,
      'class' => 'cachestore_session',
      'lock' => 'cachelock_file_default',
    ),
    'default_request' => 
    array (
      'name' => 'default_request',
      'plugin' => 'static',
      'configuration' => 
      array (
      ),
      'features' => 31,
      'modes' => 4,
      'default' => true,
      'class' => 'cachestore_static',
      'lock' => 'cachelock_file_default',
    ),
    'redis' => 
    array (
      'name' => 'redis',
      'plugin' => 'redis',
      'configuration' => 
      array (
        'server' => '$redisDns',
        'prefix' => 'moodle_prod',
        'password' => '$redisAuth',
        'serializer' => '1',
      ),
      'features' => 26,
      'modes' => 3,
      'mappingsonly' => false,
      'class' => 'cachestore_redis',
      'default' => false,
      'lock' => 'cachelock_file_default',
    ),
    'local_file' => 
    array (
      'name' => 'local_file',
      'plugin' => 'file',
      'configuration' => 
      array (
        'path' => '/tmp/muc/moodle_prod',
        'autocreate' => 1,
      ),
      'features' => 30,
      'modes' => 3,
      'mappingsonly' => false,
      'class' => 'cachestore_file',
      'default' => false,
      'lock' => 'cachelock_file_default',
    ),
  ),
  'modemappings' => 
  array (
    0 => 
    array (
      'store' => 'redis',
      'mode' => 1,
      'sort' => 0,
    ),
    1 => 
    array (
      'store' => 'default_session',
      'mode' => 2,
      'sort' => 0,
    ),
    2 => 
    array (
      'store' => 'default_request',
      'mode' => 4,
      'sort' => 0,
    ),
  ),
  'definitions' => 
  array (
    'core/string' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'string',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/langmenu' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'langmenu',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/databasemeta' => 
    array (
      'mode' => 1,
      'requireidentifiers' => 
      array (
        0 => 'dbfamily',
      ),
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 15,
      'component' => 'core',
      'area' => 'databasemeta',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/eventinvalidation' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'requiredataguarantee' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'eventinvalidation',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/questiondata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'requiredataguarantee' => false,
      'datasource' => 'question_finder',
      'datasourcefile' => 'question/engine/bank.php',
      'component' => 'core',
      'area' => 'questiondata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/htmlpurifier' => 
    array (
      'mode' => 1,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'htmlpurifier',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/config' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'config',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/groupdata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'component' => 'core',
      'area' => 'groupdata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/calendar_subscriptions' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'component' => 'core',
      'area' => 'calendar_subscriptions',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/capabilities' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'ttl' => 3600,
      'component' => 'core',
      'area' => 'capabilities',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/yuimodules' => 
    array (
      'mode' => 1,
      'component' => 'core',
      'area' => 'yuimodules',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/observers' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'component' => 'core',
      'area' => 'observers',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/plugin_manager' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'plugin_manager',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursecattree' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'invalidationevents' => 
      array (
        0 => 'changesincoursecat',
      ),
      'component' => 'core',
      'area' => 'coursecattree',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursecat' => 
    array (
      'mode' => 2,
      'invalidationevents' => 
      array (
        0 => 'changesincoursecat',
        1 => 'changesincourse',
      ),
      'ttl' => 600,
      'component' => 'core',
      'area' => 'coursecat',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/coursecatrecords' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'invalidationevents' => 
      array (
        0 => 'changesincoursecat',
      ),
      'component' => 'core',
      'area' => 'coursecatrecords',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/coursecontacts' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'simplekeys' => true,
      'ttl' => 3600,
      'component' => 'core',
      'area' => 'coursecontacts',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/repositories' => 
    array (
      'mode' => 4,
      'component' => 'core',
      'area' => 'repositories',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/externalbadges' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'ttl' => 3600,
      'component' => 'core',
      'area' => 'externalbadges',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursemodinfo' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'coursemodinfo',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/userselections' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'userselections',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/completion' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'ttl' => 3600,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'component' => 'core',
      'area' => 'completion',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursecompletion' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'ttl' => 3600,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'component' => 'core',
      'area' => 'coursecompletion',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/navigation_expandcourse' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'navigation_expandcourse',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/suspended_userids' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'suspended_userids',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/roledefs' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'component' => 'core',
      'area' => 'roledefs',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/plugin_functions' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 5,
      'component' => 'core',
      'area' => 'plugin_functions',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/tags' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'staticacceleration' => true,
      'component' => 'core',
      'area' => 'tags',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/grade_categories' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'invalidationevents' => 
      array (
        0 => 'changesingradecategories',
      ),
      'component' => 'core',
      'area' => 'grade_categories',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/temp_tables' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'temp_tables',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/tagindexbuilder' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'simplevalues' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'ttl' => 900,
      'invalidationevents' => 
      array (
        0 => 'resettagindexbuilder',
      ),
      'component' => 'core',
      'area' => 'tagindexbuilder',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/contextwithinsights' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'core',
      'area' => 'contextwithinsights',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/message_processors_enabled' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 3,
      'component' => 'core',
      'area' => 'message_processors_enabled',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/message_time_last_message_between_users' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simplevalues' => true,
      'datasource' => '\\core_message\\time_last_message_between_users',
      'component' => 'core',
      'area' => 'message_time_last_message_between_users',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/fontawesomeiconmapping' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'core',
      'area' => 'fontawesomeiconmapping',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/postprocessedcss' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => false,
      'component' => 'core',
      'area' => 'postprocessedcss',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/user_group_groupings' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'component' => 'core',
      'area' => 'user_group_groupings',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'availability_grade/scores' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'ttl' => 3600,
      'component' => 'availability_grade',
      'area' => 'scores',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'availability_grade/items' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'ttl' => 3600,
      'component' => 'availability_grade',
      'area' => 'items',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'mod_glossary/concepts' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => false,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'component' => 'mod_glossary',
      'area' => 'concepts',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'repository_googledocs/folder' => 
    array (
      'mode' => 1,
      'simplekeys' => false,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'canuselocalstore' => true,
      'component' => 'repository_googledocs',
      'area' => 'folder',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'repository_onedrive/folder' => 
    array (
      'mode' => 1,
      'simplekeys' => false,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'canuselocalstore' => true,
      'component' => 'repository_onedrive',
      'area' => 'folder',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'repository_skydrive/foldername' => 
    array (
      'mode' => 2,
      'component' => 'repository_skydrive',
      'area' => 'foldername',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'tool_mobile/plugininfo' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'tool_mobile',
      'area' => 'plugininfo',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'tool_monitor/eventsubscriptions' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'component' => 'tool_monitor',
      'area' => 'eventsubscriptions',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'tool_uploadcourse/helper' => 
    array (
      'mode' => 4,
      'component' => 'tool_uploadcourse',
      'area' => 'helper',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'tool_usertours/tourdata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'tool_usertours',
      'area' => 'tourdata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'tool_usertours/stepdata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'tool_usertours',
      'area' => 'stepdata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
  ),
  'definitionmappings' => 
  array (
    0 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/coursemodinfo',
      'sort' => 1,
    ),
    1 => 
    array (
      'store' => 'redis',
      'definition' => 'core/groupdata',
      'sort' => 1,
    ),
    2 => 
    array (
      'store' => 'redis',
      'definition' => 'core/roledefs',
      'sort' => 1,
    ),
    3 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_usertours/tourdata',
      'sort' => 1,
    ),
    4 => 
    array (
      'store' => 'redis',
      'definition' => 'repository_onedrive/folder',
      'sort' => 1,
    ),
    5 => 
    array (
      'store' => 'redis',
      'definition' => 'core/message_processors_enabled',
      'sort' => 1,
    ),
    6 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecontacts',
      'sort' => 1,
    ),
    7 => 
    array (
      'store' => 'redis',
      'definition' => 'repository_googledocs/folder',
      'sort' => 1,
    ),
    8 => 
    array (
      'store' => 'redis',
      'definition' => 'core/questiondata',
      'sort' => 1,
    ),
    9 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecat',
      'sort' => 1,
    ),
    10 => 
    array (
      'store' => 'redis',
      'definition' => 'core/databasemeta',
      'sort' => 1,
    ),
    11 => 
    array (
      'store' => 'redis',
      'definition' => 'core/eventinvalidation',
      'sort' => 1,
    ),
    12 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecattree',
      'sort' => 1,
    ),
    13 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecompletion',
      'sort' => 1,
    ),
    14 => 
    array (
      'store' => 'redis',
      'definition' => 'core/user_group_groupings',
      'sort' => 1,
    ),
    15 => 
    array (
      'store' => 'redis',
      'definition' => 'core/capabilities',
      'sort' => 1,
    ),
    16 => 
    array (
      'store' => 'redis',
      'definition' => 'core/yuimodules',
      'sort' => 1,
    ),
    17 => 
    array (
      'store' => 'redis',
      'definition' => 'core/observers',
      'sort' => 1,
    ),
    18 => 
    array (
      'store' => 'redis',
      'definition' => 'mod_glossary/concepts',
      'sort' => 1,
    ),
    19 => 
    array (
      'store' => 'redis',
      'definition' => 'core/fontawesomeiconmapping',
      'sort' => 1,
    ),
    20 => 
    array (
      'store' => 'redis',
      'definition' => 'core/config',
      'sort' => 1,
    ),
    21 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_mobile/plugininfo',
      'sort' => 1,
    ),
    22 => 
    array (
      'store' => 'redis',
      'definition' => 'core/plugin_functions',
      'sort' => 1,
    ),
    23 => 
    array (
      'store' => 'redis',
      'definition' => 'core/postprocessedcss',
      'sort' => 1,
    ),
    24 => 
    array (
      'store' => 'redis',
      'definition' => 'core/plugin_manager',
      'sort' => 1,
    ),
    25 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_usertours/stepdata',
      'sort' => 1,
    ),
    26 => 
    array (
      'store' => 'redis',
      'definition' => 'availability_grade/items',
      'sort' => 1,
    ),
    27 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/string',
      'sort' => 1,
    ),
    28 => 
    array (
      'store' => 'redis',
      'definition' => 'core/externalbadges',
      'sort' => 1,
    ),
    29 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/langmenu',
      'sort' => 1,
    ),
    30 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/htmlpurifier',
      'sort' => 1,
    ),
    31 => 
    array (
      'store' => 'redis',
      'definition' => 'core/completion',
      'sort' => 1,
    ),
    32 => 
    array (
      'store' => 'redis',
      'definition' => 'core/calendar_subscriptions',
      'sort' => 1,
    ),
    33 => 
    array (
      'store' => 'redis',
      'definition' => 'core/contextwithinsights',
      'sort' => 1,
    ),
    34 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_monitor/eventsubscriptions',
      'sort' => 1,
    ),
    35 => 
    array (
      'store' => 'redis',
      'definition' => 'core/message_time_last_message_between_users',
      'sort' => 1,
    ),
    36 => 
    array (
      'store' => 'redis',
      'definition' => 'availability_grade/scores',
      'sort' => 1,
    ),
  ),
  'locks' => 
  array (
    'cachelock_file_default' => 
    array (
      'name' => 'cachelock_file_default',
      'type' => 'cachelock_file',
      'dir' => 'filelocks',
      'default' => true,
    ),
  ),
);
EOF
}

# Long fail2ban config command moved here
function config_fail2ban
{
    cat <<EOF > /etc/fail2ban/jail.conf
# Fail2Ban configuration file.
#
# This file was composed for Debian systems from the original one
# provided now under /usr/share/doc/fail2ban/examples/jail.conf
# for additional examples.
#
# Comments: use '#' for comment lines and ';' for inline comments
#
# To avoid merges during upgrades DO NOT MODIFY THIS FILE
# and rather provide your changes in /etc/fail2ban/jail.local
#

# The DEFAULT allows a global definition of the options. They can be overridden
# in each jail afterwards.

[DEFAULT]

# "ignoreip" can be an IP address, a CIDR mask or a DNS host. Fail2ban will not
# ban a host which matches an address in this list. Several addresses can be
# defined using space separator.
ignoreip = 127.0.0.1/8

# "bantime" is the number of seconds that a host is banned.
bantime  = 600

# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = 600
maxretry = 3

# "backend" specifies the backend used to get files modification.
# Available options are "pyinotify", "gamin", "polling" and "auto".
# This option can be overridden in each jail as well.
#
# pyinotify: requires pyinotify (a file alteration monitor) to be installed.
#            If pyinotify is not installed, Fail2ban will use auto.
# gamin:     requires Gamin (a file alteration monitor) to be installed.
#            If Gamin is not installed, Fail2ban will use auto.
# polling:   uses a polling algorithm which does not require external libraries.
# auto:      will try to use the following backends, in order:
#            pyinotify, gamin, polling.
backend = auto

# "usedns" specifies if jails should trust hostnames in logs,
#   warn when reverse DNS lookups are performed, or ignore all hostnames in logs
#
# yes:   if a hostname is encountered, a reverse DNS lookup will be performed.
# warn:  if a hostname is encountered, a reverse DNS lookup will be performed,
#        but it will be logged as a warning.
# no:    if a hostname is encountered, will not be used for banning,
#        but it will be logged as info.
usedns = warn

#
# Destination email address used solely for the interpolations in
# jail.{conf,local} configuration files.
destemail = root@localhost

#
# Name of the sender for mta actions
sendername = Fail2Ban

#
# ACTIONS
#

# Default banning action (e.g. iptables, iptables-new,
# iptables-multiport, shorewall, etc) It is used to define
# action_* variables. Can be overridden globally or per
# section within jail.local file
banaction = iptables-multiport

# email action. Since 0.8.1 upstream fail2ban uses sendmail
# MTA for the mailing. Change mta configuration parameter to mail
# if you want to revert to conventional 'mail'.
mta = sendmail

# Default protocol
protocol = tcp

# Specify chain where jumps would need to be added in iptables-* actions
chain = INPUT

#
# Action shortcuts. To be used to define action parameter

# The simplest action to take: ban only
action_ = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]

# ban & send an e-mail with whois report to the destemail.
action_mw = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
              %(mta)s-whois[name=%(__name__)s, dest="%(destemail)s", protocol="%(protocol)s", chain="%(chain)s", sendername="%(sendername)s"]

# ban & send an e-mail with whois report and relevant log lines
# to the destemail.
action_mwl = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
               %(mta)s-whois-lines[name=%(__name__)s, dest="%(destemail)s", logpath=%(logpath)s, chain="%(chain)s", sendername="%(sendername)s"]

# Choose default action.  To change, just override value of 'action' with the
# interpolation to the chosen action shortcut (e.g.  action_mw, action_mwl, etc) in jail.local
# globally (section [DEFAULT]) or per specific section
action = %(action_)s

#
# JAILS
#

# Next jails corresponds to the standard configuration in Fail2ban 0.6 which
# was shipped in Debian. Enable any defined here jail by including
#
# [SECTION_NAME]
# enabled = true

#
# in /etc/fail2ban/jail.local.
#
# Optionally you may override any other parameter (e.g. banaction,
# action, port, logpath, etc) in that section within jail.local

[ssh]

enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 6

[dropbear]

enabled  = false
port     = ssh
filter   = dropbear
logpath  = /var/log/auth.log
maxretry = 6

# Generic filter for pam. Has to be used with action which bans all ports
# such as iptables-allports, shorewall
[pam-generic]

enabled  = false
# pam-generic filter can be customized to monitor specific subset of 'tty's
filter   = pam-generic
# port actually must be irrelevant but lets leave it all for some possible uses
port     = all
banaction = iptables-allports
port     = anyport
logpath  = /var/log/auth.log
maxretry = 6

[xinetd-fail]

enabled   = false
filter    = xinetd-fail
port      = all
banaction = iptables-multiport-log
logpath   = /var/log/daemon.log
maxretry  = 2


[ssh-ddos]

enabled  = false
port     = ssh
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 6


# Here we use blackhole routes for not requiring any additional kernel support
# to store large volumes of banned IPs

[ssh-route]

enabled = false
filter = sshd
action = route
logpath = /var/log/sshd.log
maxretry = 6

# Here we use a combination of Netfilter/Iptables and IPsets
# for storing large volumes of banned IPs
#
# IPset comes in two versions. See ipset -V for which one to use
# requires the ipset package and kernel support.
[ssh-iptables-ipset4]

enabled  = false
port     = ssh
filter   = sshd
banaction = iptables-ipset-proto4
logpath  = /var/log/sshd.log
maxretry = 6

[ssh-iptables-ipset6]

enabled  = false
port     = ssh
filter   = sshd
banaction = iptables-ipset-proto6
logpath  = /var/log/sshd.log
maxretry = 6


#
# HTTP servers
#

[apache]

enabled  = false
port     = http,https
filter   = apache-auth
logpath  = /var/log/apache*/*error.log
maxretry = 6

# default action is now multiport, so apache-multiport jail was left
# for compatibility with previous (<0.7.6-2) releases
[apache-multiport]

enabled   = false
port      = http,https
filter    = apache-auth
logpath   = /var/log/apache*/*error.log
maxretry  = 6

[apache-noscript]

enabled  = false
port     = http,https
filter   = apache-noscript
logpath  = /var/log/apache*/*error.log
maxretry = 6

[apache-overflows]

enabled  = false
port     = http,https
filter   = apache-overflows
logpath  = /var/log/apache*/*error.log
maxretry = 2

# Ban attackers that try to use PHP's URL-fopen() functionality
# through GET/POST variables. - Experimental, with more than a year
# of usage in production environments.

[php-url-fopen]

enabled = false
port    = http,https
filter  = php-url-fopen
logpath = /var/www/*/logs/access_log

# A simple PHP-fastcgi jail which works with lighttpd.
# If you run a lighttpd server, then you probably will
# find these kinds of messages in your error_log:
#   ALERT – tried to register forbidden variable ‘GLOBALS’
#   through GET variables (attacker '1.2.3.4', file '/var/www/default/htdocs/index.php')

[lighttpd-fastcgi]

enabled = false
port    = http,https
filter  = lighttpd-fastcgi
logpath = /var/log/lighttpd/error.log

# Same as above for mod_auth
# It catches wrong authentifications

[lighttpd-auth]

enabled = false
port    = http,https
filter  = suhosin
logpath = /var/log/lighttpd/error.log

[nginx-http-auth]

enabled = false
filter  = nginx-http-auth
port    = http,https
logpath = /var/log/nginx/error.log

# Monitor roundcube server

[roundcube-auth]

enabled  = false
filter   = roundcube-auth
port     = http,https
logpath  = /var/log/roundcube/userlogins


[sogo-auth]

enabled  = false
filter   = sogo-auth
port     = http, https
# without proxy this would be:
# port    = 20000
logpath  = /var/log/sogo/sogo.log


#
# FTP servers
#

[vsftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = vsftpd
logpath  = /var/log/vsftpd.log
# or overwrite it in jails.local to be
# logpath = /var/log/auth.log
# if you want to rely on PAM failed login attempts
# vsftpd's failregex should match both of those formats
maxretry = 6


[proftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = proftpd
logpath  = /var/log/proftpd/proftpd.log
maxretry = 6


[pure-ftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = pure-ftpd
logpath  = /var/log/syslog
maxretry = 6


[wuftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = wuftpd
logpath  = /var/log/syslog
maxretry = 6


#
# Mail servers
#

[postfix]

enabled  = false
port     = smtp,ssmtp,submission
filter   = postfix
logpath  = /var/log/mail.log


[couriersmtp]

enabled  = false
port     = smtp,ssmtp,submission
filter   = couriersmtp
logpath  = /var/log/mail.log


#
# Mail servers authenticators: might be used for smtp,ftp,imap servers, so
# all relevant ports get banned
#

[courierauth]

enabled  = false
port     = smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s
filter   = courierlogin
logpath  = /var/log/mail.log


[sasl]

enabled  = false
port     = smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s
filter   = postfix-sasl
# You might consider monitoring /var/log/mail.warn instead if you are
# running postfix since it would provide the same log lines at the
# "warn" level but overall at the smaller filesize.
logpath  = /var/log/mail.log

[dovecot]

enabled = false
port    = smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s
filter  = dovecot
logpath = /var/log/mail.log

# To log wrong MySQL access attempts add to /etc/my.cnf:
# log-error=/var/log/mysqld.log
# log-warning = 2
[mysqld-auth]

enabled  = false
filter   = mysqld-auth
port     = 3306
logpath  = /var/log/mysqld.log


# DNS Servers


# These jails block attacks against named (bind9). By default, logging is off
# with bind9 installation. You will need something like this:
#
# logging {
#     channel security_file {
#         file "/var/log/named/security.log" versions 3 size 30m;
#         severity dynamic;
#         print-time yes;
#     };
#     category security {
#         security_file;
#     };
# };
#
# in your named.conf to provide proper logging

# !!! WARNING !!!
#   Since UDP is connection-less protocol, spoofing of IP and imitation
#   of illegal actions is way too simple.  Thus enabling of this filter
#   might provide an easy way for implementing a DoS against a chosen
#   victim. See
#    http://nion.modprobe.de/blog/archives/690-fail2ban-+-dns-fail.html
#   Please DO NOT USE this jail unless you know what you are doing.
#[named-refused-udp]
#
#enabled  = false
#port     = domain,953
#protocol = udp
#filter   = named-refused
#logpath  = /var/log/named/security.log

[named-refused-tcp]

enabled  = false
port     = domain,953
protocol = tcp
filter   = named-refused
logpath  = /var/log/named/security.log

# Multiple jails, 1 per protocol, are necessary ATM:
# see https://github.com/fail2ban/fail2ban/issues/37
[asterisk-tcp]

enabled  = false
filter   = asterisk
port     = 5060,5061
protocol = tcp
logpath  = /var/log/asterisk/messages

[asterisk-udp]

enabled  = false
filter	 = asterisk
port     = 5060,5061
protocol = udp
logpath  = /var/log/asterisk/messages


# Jail for more extended banning of persistent abusers
# !!! WARNING !!!
#   Make sure that your loglevel specified in fail2ban.conf/.local
#   is not at DEBUG level -- which might then cause fail2ban to fall into
#   an infinite loop constantly feeding itself with non-informative lines
[recidive]

enabled  = false
filter   = recidive
logpath  = /var/log/fail2ban.log
action   = iptables-allports[name=recidive]
           sendmail-whois-lines[name=recidive, logpath=/var/log/fail2ban.log]
bantime  = 604800  ; 1 week
findtime = 86400   ; 1 day
maxretry = 5
EOF
}
