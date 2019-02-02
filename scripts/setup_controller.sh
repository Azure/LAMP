#!/bin/bash

# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -ex

#parameters 
{
    lamp_on_azure_configs_json_path=${1}

    . ./helper_functions.sh

    get_setup_params_from_configs_json $lamp_on_azure_configs_json_path || exit 99

    echo $glusterNode          >> /tmp/vars.txt
    echo $glusterVolume        >> /tmp/vars.txt
    echo $siteFQDN             >> /tmp/vars.txt
    echo $httpsTermination     >> /tmp/vars.txt
    echo $dbIP                 >> /tmp/vars.txt
    echo $adminpass            >> /tmp/vars.txt
    echo $dbadminlogin         >> /tmp/vars.txt
    echo $dbadminloginazure    >> /tmp/vars.txt
    echo $dbadminpass          >> /tmp/vars.txt
    echo $storageAccountName   >> /tmp/vars.txt
    echo $storageAccountKey    >> /tmp/vars.txt
    echo $redisDns             >> /tmp/vars.txt
    echo $redisAuth            >> /tmp/vars.txt
    echo $dbServerType                >> /tmp/vars.txt
    echo $fileServerType              >> /tmp/vars.txt
    echo $mssqlDbServiceObjectiveName >> /tmp/vars.txt
    echo $mssqlDbEdition	>> /tmp/vars.txt
    echo $mssqlDbSize	>> /tmp/vars.txt
    echo $thumbprintSslCert >> /tmp/vars.txt
    echo $thumbprintCaCert >> /tmp/vars.txt
    echo $nfsByoIpExportPath >> /tmp/vars.txt

    check_fileServerType_param $fileServerType

    # make sure system does automatic updates and fail2ban
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y update
    # TODO: ENSURE THIS IS CONFIGURED CORRECTLY
    apt-get -y install unattended-upgrades fail2ban

    config_fail2ban

    # create gluster, nfs or Azure Files mount point
    mkdir -p /azlamp

    if [ $fileServerType = "gluster" ]; then
        # configure gluster repository & install gluster client
        add-apt-repository ppa:gluster/glusterfs-3.10 -y                 >> /tmp/apt1.log
    elif [ $fileServerType = "nfs" ]; then
        # configure NFS server and export
        setup_raid_disk_and_filesystem /azlamp /dev/md1 /dev/md1p1
        configure_nfs_server_and_export /azlamp
    fi

    apt-get -y update                                                   >> /tmp/apt2.log
    apt-get -y --force-yes install rsyslog git                          >> /tmp/apt3.log

    if [ $fileServerType = "gluster" ]; then
        apt-get -y --force-yes install glusterfs-client                 >> /tmp/apt3.log
    elif [ "$fileServerType" = "azurefiles" ]; then
        apt-get -y --force-yes install cifs-utils                       >> /tmp/apt3.log
    fi

    if [ $dbServerType = "mysql" ]; then
        apt-get -y --force-yes install mysql-client >> /tmp/apt3.log
    elif [ "$dbServerType" = "postgres" ]; then
        #apt-get -y --force-yes install postgresql-client >> /tmp/apt3.log
        # Get a new version of Postgres to match Azure version (default Xenial postgresql-client version--previous line--is 9.5)
        # Note that this was done after create_db, but before pg_dump cron job setup (no idea why). If this change
        # causes any pgres install issue, consider reverting this ordering change...
        add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        apt-get update
        apt-get install -y postgresql-client-9.6
    fi

    if [ $fileServerType = "gluster" ]; then
        # mount gluster files system
        echo -e '\n\rInstalling GlusterFS on '$glusterNode':/'$glusterVolume '/azlamp\n\r' 
        setup_and_mount_gluster_share $glusterNode $glusterVolume /azlamp
    elif [ $fileServerType = "nfs-ha" ]; then
        # mount NFS-HA export
        echo -e '\n\rMounting NFS export from '$nfsHaLbIP' on /azlamp\n\r'
        configure_nfs_client_and_mount $nfsHaLbIP $nfsHaExportPath /azlamp
    elif [ $fileServerType = "nfs-byo" ]; then
        # mount NFS-BYO export
        echo -e '\n\rMounting NFS export from '$nfsByoIpExportPath' on /azlamp\n\r'
        configure_nfs_client_and_mount0 $nfsByoIpExportPath /azlamp
    fi
    
    # install pre-requisites
    apt-get install -y --fix-missing python-software-properties unzip

    # install the entire stack
    apt-get -y --force-yes install nginx php-fpm php php-cli php-curl php-zip >> /tmp/apt5.log

    # LAMP requirements
    apt-get -y update > /dev/null
    apt-get install -y --force-yes php-common php-soap php-json php-redis php-bcmath php-gd php-xmlrpc php-intl php-xml php-bz2 php-pear php-mbstring php-dev mcrypt >> /tmp/apt6.log
    PhpVer=$(get_php_version)
    if [ $dbServerType = "mysql" ]; then
        apt-get install -y --force-yes php-mysql
    elif [ $dbServerType = "mssql" ]; then
        apt-get install -y libapache2-mod-php  # Need this because install_php_mssql_driver tries to update apache2-mod-php settings always (which will fail without this)
        install_php_mssql_driver
    else
        apt-get install -y --force-yes php-pgsql
    fi

    # Set up initial LAMP dirs
    mkdir -p /azlamp/html
    mkdir -p /azlamp/certs
    mkdir -p /azlamp/data

    # Build nginx config
    create_main_nginx_conf_on_controller $httpsTermination

    update_php_config_on_controller

    # Remove the default site
    rm -f /etc/nginx/sites-enabled/default

    # restart Nginx
    systemctl restart nginx

    # Master config for syslog
    config_syslog_on_controller
    systemctl restart rsyslog

    # Turning off services we don't need the controller running
    systemctl stop nginx
    systemctl stop php${PhpVer}-fpm

    if [ $fileServerType = "azurefiles" ]; then
        # Delayed copy of azlamp installation to the Azure Files share

        # First rename azlamp directory to something else
        mv /azlamp /azlamp_old_delete_me
        # Then create the azlamp share
        echo -e '\n\rCreating an Azure Files share for azlamp'
        create_azure_files_share azlamp $storageAccountName $storageAccountKey /tmp/wabs.log
        # Set up and mount Azure Files share. Must be done after nginx is installed because of www-data user/group
        echo -e '\n\rSetting up and mounting Azure Files share on //'$storageAccountName'.file.core.windows.net/azlamp on /azlamp\n\r'
        setup_and_mount_azure_files_share azlamp $storageAccountName $storageAccountKey
        # Move the local installation over to the Azure Files
        echo -e '\n\rMoving locally installed azlamp over to Azure Files'
        cp -a /azlamp_old_delete_me/* /azlamp || true # Ignore case sensitive directory copy failure
        # rm -rf /azlamp_old_delete_me || true # Keep the files just in case
    fi

    # chmod /azlamp for Azure NetApp Files (its default is 770!)
    if [ $fileServerType = "nfs-byo" ]; then
        chmod +rx /azlamp
    fi

    create_last_modified_time_update_script
    run_once_last_modified_time_update_script

    # Install scripts for LAMP
    mkdir -p /azlamp/bin
    cp helper_functions.sh /azlamp/bin/utils.sh
    chmod +x /azlamp/bin/utils.sh
    cat <<EOF > /azlamp/bin/update-vmss-config
#!/bin/bash

# Lookup the version number corresponding to the next process to be run on the machine
VERSION=1
VERSION_FILE=/root/vmss_config_version
[ -f \${VERSION_FILE} ] && VERSION=\$(<\${VERSION_FILE})

# iterate over processes that haven't yet been run on this machine, executing them one by one
while true
do
    case \$VERSION in
        # Uncomment the following block when adding/removing sites. Change the parameters if needed (default should work for most cases).
        # true (or anything else): htmlLocalCopySwitch, VMSS (or anything else): https termination
        # Add another block with the next version number for any further site addition/removal.

        #1)
        #    . /azlamp/bin/utils.sh
        #    reset_all_sites_on_vmss true VMSS
        #;;

        *)
            # nothing more to do so exit
            exit 0
        ;;
    esac

    # increment the version number and store it away to mark the successful end of the process
    VERSION=\$(( \$VERSION + 1 ))
    echo \$VERSION > \${VERSION_FILE}

done
EOF
  
}  > /tmp/install.log
