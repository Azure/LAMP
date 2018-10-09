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
    moodle_on_azure_configs_json_path=${1}

    . ./helper_functions.sh

    get_setup_params_from_configs_json $moodle_on_azure_configs_json_path || exit 99

    echo $moodleVersion        >> /tmp/vars.txt
    echo $glusterNode          >> /tmp/vars.txt
    echo $glusterVolume        >> /tmp/vars.txt
    echo $siteFQDN             >> /tmp/vars.txt
    echo $httpsTermination     >> /tmp/vars.txt
    echo $dbIP                 >> /tmp/vars.txt
    echo $moodledbname         >> /tmp/vars.txt
    echo $moodledbuser         >> /tmp/vars.txt
    echo $moodledbpass         >> /tmp/vars.txt
    echo $adminpass            >> /tmp/vars.txt
    echo $dbadminlogin         >> /tmp/vars.txt
    echo $dbadminloginazure    >> /tmp/vars.txt
    echo $dbadminpass          >> /tmp/vars.txt
    echo $storageAccountName   >> /tmp/vars.txt
    echo $storageAccountKey    >> /tmp/vars.txt
    echo $azuremoodledbuser    >> /tmp/vars.txt
    echo $redisDns             >> /tmp/vars.txt
    echo $redisAuth            >> /tmp/vars.txt
    echo $elasticVm1IP         >> /tmp/vars.txt
    echo $installO365pluginsSwitch    >> /tmp/vars.txt
    echo $dbServerType                >> /tmp/vars.txt
    echo $fileServerType              >> /tmp/vars.txt
    echo $mssqlDbServiceObjectiveName >> /tmp/vars.txt
    echo $mssqlDbEdition	>> /tmp/vars.txt
    echo $mssqlDbSize	>> /tmp/vars.txt
    echo $installObjectFsSwitch >> /tmp/vars.txt
    echo $installGdprPluginsSwitch >> /tmp/vars.txt
    echo $thumbprintSslCert >> /tmp/vars.txt
    echo $thumbprintCaCert >> /tmp/vars.txt
    echo $searchType >> /tmp/vars.txt
    echo $azureSearchKey >> /tmp/vars.txt
    echo $azureSearchNameHost >> /tmp/vars.txt
    echo $tikaVmIP >> /tmp/vars.txt
    echo $nfsByoIpExportPath >> /tmp/vars.txt

    check_fileServerType_param $fileServerType

    # make sure system does automatic updates and fail2ban
    sudo apt-get -y update
    sudo apt-get -y install unattended-upgrades fail2ban

    config_fail2ban

    # create gluster, nfs or Azure Files mount point
    mkdir -p /azlamp

    export DEBIAN_FRONTEND=noninteractive

    if [ $fileServerType = "gluster" ]; then
        # configure gluster repository & install gluster client
        sudo add-apt-repository ppa:gluster/glusterfs-3.8 -y                 >> /tmp/apt1.log
    elif [ $fileServerType = "nfs" ]; then
        # configure NFS server and export
        setup_raid_disk_and_filesystem /azlamp /dev/md1 /dev/md1p1
        configure_nfs_server_and_export /azlamp
    fi

    sudo apt-get -y update                                                   >> /tmp/apt2.log
    sudo apt-get -y --force-yes install rsyslog git                          >> /tmp/apt3.log

    if [ $fileServerType = "gluster" ]; then
        sudo apt-get -y --force-yes install glusterfs-client                 >> /tmp/apt3.log
    elif [ "$fileServerType" = "azurefiles" ]; then
        sudo apt-get -y --force-yes install cifs-utils                       >> /tmp/apt3.log
    fi

    if [ $dbServerType = "mysql" ]; then
        sudo apt-get -y --force-yes install mysql-client >> /tmp/apt3.log
    elif [ "$dbServerType" = "postgres" ]; then
        #sudo apt-get -y --force-yes install postgresql-client >> /tmp/apt3.log
        # Get a new version of Postgres to match Azure version (default Xenial postgresql-client version--previous line--is 9.5)
        # Note that this was done after create_db, but before pg_dump cron job setup (no idea why). If this change
        # causes any pgres install issue, consider reverting this ordering change...
        add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
        apt-get update
        apt-get install -y postgresql-client-9.6
    fi

    if [ "$installObjectFsSwitch" = "true" -o "$fileServerType" = "azurefiles" ]; then
        # install azure cli & setup container
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
            sudo tee /etc/apt/sources.list.d/azure-cli.list

        curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - >> /tmp/apt4.log
        sudo apt-get -y install apt-transport-https >> /tmp/apt4.log
        sudo apt-get -y update > /dev/null
        sudo apt-get -y install azure-cli >> /tmp/apt4.log

        az storage container create \
            --name objectfs \
            --account-name $storageAccountName \
            --account-key $storageAccountKey \
            --public-access off \
            --fail-on-exist >> /tmp/wabs.log

        az storage container policy create \
            --account-name $storageAccountName \
            --account-key $storageAccountKey \
            --container-name objectfs \
            --name readwrite \
            --start $(date --date="1 day ago" +%F) \
            --expiry $(date --date="2199-01-01" +%F) \
            --permissions rw >> /tmp/wabs.log

        sas=$(az storage container generate-sas \
            --account-name $storageAccountName \
            --account-key $storageAccountKey \
            --name objectfs \
            --policy readwrite \
            --output tsv)
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
    sudo apt-get install -y --fix-missing python-software-properties unzip

    # install the entire stack
    sudo apt-get -y  --force-yes install nginx php-fpm varnish >> /tmp/apt5a.log
    sudo apt-get -y  --force-yes install php php-cli php-curl php-zip >> /tmp/apt5b.log

    # Moodle requirements
    sudo apt-get -y update > /dev/null
    sudo apt-get install -y --force-yes graphviz aspell php-common php-soap php-json php-redis > /tmp/apt6.log
    sudo apt-get install -y --force-yes php-bcmath php-gd php-xmlrpc php-intl php-xml php-bz2 php-pear php-mbstring php-dev mcrypt >> /tmp/apt6.log
    PhpVer=$(get_php_version)
    if [ $dbServerType = "mysql" ]; then
        sudo apt-get install -y --force-yes php-mysql
    elif [ $dbServerType = "mssql" ]; then
        install_php_mssql_driver
    else
        sudo apt-get install -y --force-yes php-pgsql
    fi

    # Set up initial moodle dirs
    moodleHtmlDir="/azlamp/html/$siteFQDN"
    moodleCertsDir="/azlamp/certs/$siteFQDN"
    moodleDataDir="/azlamp/data/$siteFQDN/moodledata"   # Need the .../moodledata subdir because we also save the DB backup files in /azlamp/data/$siteFQDN and we'd like to separate it from moodledata content

    mkdir -p /azlamp/html       # /azlamp/html/$siteFQDN should NOT be created here, but in download_and_place_... (to support the case of already created /azlamp/html/$siteFQDN directory and avoiding redownloading)
    mkdir -p $moodleCertsDir
    mkdir -p $moodleDataDir

    download_and_place_per_site_moodle_and_plugins_on_controller $moodleVersion $moodleHtmlDir $installGdprPluginsSwitch $installO365pluginsSwitch $searchType $installObjectFsSwitch

    # Build nginx config
    create_main_nginx_conf_on_controller $httpsTermination
    create_per_site_nginx_conf_on_controller $siteFQDN $httpsTermination $moodleHtmlDir $moodleCertsDir
    create_per_site_nginx_ssl_certs_on_controller $siteFQDN $moodleCertsDir $httpsTermination $thumbprintSslCert $thumbprintCaCert

    update_php_config_on_controller

    # Remove the default site. Moodle is the only site we want
    rm -f /etc/nginx/sites-enabled/default

    # restart Nginx
    sudo service nginx restart

    configure_varnish_on_controller
    # Restart Varnish
    systemctl daemon-reload
    service varnish restart

    create_per_site_sql_db_from_controller $dbServerType $dbIP $dbadminloginazure $dbadminpass $moodledbname $moodledbuser $moodledbpass $mssqlDbSize $mssqlDbEdition $mssqlDbServiceObjectiveName

    # Master config for syslog
    config_syslog_on_controller
    service rsyslog restart

    # Fire off moodle setup
    setup_and_config_per_site_moodle_on_controller $httpsTermination $siteFQDN $dbServerType $moodleHtmlDir $moodleDataDir $dbIP $moodledbname $azuremoodledbuser $moodledbpass $adminpass

    if [ "$redisAuth" != "None" ]; then
        create_redis_configuration_in_moodledata_muc_config_php $moodleDataDir/muc/config.php

        # redis configuration in $moodleHtmlDir/config.php
        sed -i "23 a \$CFG->session_redis_lock_expire = 7200;" $configPhpPath
        sed -i "23 a \$CFG->session_redis_acquire_lock_timeout = 120;" $configPhpPath
        sed -i "23 a \$CFG->session_redis_prefix = 'moodle_prod'; // Optional, default is don't set one." $configPhpPath
        sed -i "23 a \$CFG->session_redis_database = 0;  // Optional, default is db 0." $configPhpPath
        sed -i "23 a \$CFG->session_redis_port = 6379;  // Optional." $configPhpPath
        sed -i "23 a \$CFG->session_redis_host = '$redisDns';" $configPhpPath
        sed -i "23 a \$CFG->session_redis_auth = '$redisAuth';" $configPhpPath
        sed -i "23 a \$CFG->session_handler_class = '\\\core\\\session\\\redis';" $configPhpPath
    fi

    if [ "$searchType" = "elastic" ]; then
        # Set up elasticsearch plugin
        if [ "$tikaVmIP" = "none" ]; then
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_elastic' => ['hostname' => 'http://$elasticVm1IP']];" $configPhpPath
        else
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_elastic' => ['hostname' => 'http://$elasticVm1IP', 'fileindexing' => 'true', 'tikahostname' => 'http://$tikaVmIP', 'tikaport' => '9998'],];" $configPhpPath
        fi

        sed -i "23 a \$CFG->searchengine = 'elastic';" $configPhpPath
        sed -i "23 a \$CFG->enableglobalsearch = 'true';" $configPhpPath
        # create index
        php $moodleHtmlDir/search/cli/indexer.php --force --reindex

    elif [ "$searchType" = "azure" ]; then
        # Set up Azure Search service plugin
        if [ "$tikaVmIP" = "none" ]; then
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_azure' => ['searchurl' => 'https://$azureSearchNameHost', 'apikey' => '$azureSearchKey']];" $configPhpPath
        else
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_azure' => ['searchurl' => 'https://$azureSearchNameHost', 'apikey' => '$azureSearchKey', 'fileindexing' => '1', 'tikahostname' => 'http://$tikaVmIP', 'tikaport' => '9998'],];" $configPhpPath
        fi

        sed -i "23 a \$CFG->searchengine = 'azure';" $configPhpPath
        sed -i "23 a \$CFG->enableglobalsearch = 'true';" $configPhpPath
        # create index
        php $moodleHtmlDir/search/cli/indexer.php --force --reindex

    fi

    if [ "$installObjectFsSwitch" = "true" ]; then
        # Set the ObjectFS alternate filesystem
        sed -i "23 a \$CFG->alternative_file_system_class = '\\\tool_objectfs\\\azure_file_system';" $configPhpPath
        # Add the ObjectFS plugin configuration to Moodle.
        if [ $dbServerType = "mysql" ]; then
            mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1);"
            mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\\\tool_objectfs\\\azure_file_system');"
            mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '${storageAccountName}');"
            mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs');"
            mysql -h $dbIP -u $dbadminloginazure -p${dbadminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '${sas}');"
        elif [ $dbServerType = "mssql" ]; then
            /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1)"
            /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\\\tool_objectfs\\\azure_file_system')"
            /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '${storageAccountName}')"
            /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs')"
            /opt/mssql-tools/bin/sqlcmd -S $dbIP -U $dbadminloginazure -P ${dbadminpass} -d${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '${sas}')"
        else # $dbServerType = "postgres"
            echo "${dbIP}:5432:${moodledbname}:${azuremoodledbuser}:${moodledbpass}" > /root/.pgpass
            chmod 600 /root/.pgpass
            psql -h $dbIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1);"$moodledbname
            psql -h $dbIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\tool_objectfs\azure_file_system');" $moodledbname
            psql -h $dbIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '$storageAccountName');" $moodledbname
            psql -h $dbIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs');" $moodledbname
            psql -h $dbIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '$sas');" $moodledbname
            rm -f /root/.pgpass
        fi
    fi

    setup_per_site_moodle_cron_jobs_on_controller $moodleHtmlDir $siteFQDN $dbServerType $dbIP $moodledbname $azuremoodledbuser $moodledbpass

    # Turning off services we don't need the controller running
    service nginx stop
    service php${PhpVer}-fpm stop
    service varnish stop
    service varnishncsa stop
    service varnishlog stop

    if [ $fileServerType = "azurefiles" ]; then
        # Delayed copy of moodle installation to the Azure Files share

        # First rename azlamp directory to something else
        mv /azlamp /azlamp_old_delete_me
        # Then create the moodle share
        echo -e '\n\rCreating an Azure Files share for azlamp'
        create_azure_files_share azlamp $storageAccountName $storageAccountKey /tmp/wabs.log
        # Set up and mount Azure Files share. Must be done after nginx is installed because of www-data user/group
        echo -e '\n\rSetting up and mounting Azure Files share on //'$storageAccountName'.file.core.windows.net/azlamp on /azlamp\n\r'
        setup_and_mount_azure_files_share azlamp $storageAccountName $storageAccountKey
        # Move the local installation over to the Azure Files
        echo -e '\n\rMoving locally installed moodle over to Azure Files'
        cp -a /azlamp_old_delete_me/* /azlamp || true # Ignore case sensitive directory copy failure
        # rm -rf /azlamp_old_delete_me || true # Keep the files just in case
    fi

    create_last_modified_time_update_script
    run_once_last_modified_time_update_script

    # Install scripts for LAMP gen.
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
        # true (or anything else): htmlLocalCopySwitch, VMSS (or anything else): https termination, apache (or nginx): web server type
        # Add another block with the next version number for any further site addition/removal.

        #1)
        #    . /azlamp/bin/utils.sh
        #    reset_all_sites true VMSS apache
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
