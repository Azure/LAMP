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

lamp_on_azure_configs_json_path=${1}

. ./helper_functions.sh

get_setup_params_from_configs_json $lamp_on_azure_configs_json_path || exit 99

echo $glusterNode         >> /tmp/vars.txt
echo $glusterVolume       >> /tmp/vars.txt
echo $siteFQDN            >> /tmp/vars.txt
echo $httpsTermination    >> /tmp/vars.txt
echo $syslogServer        >> /tmp/vars.txt
echo $dbServerType        >> /tmp/vars.txt
echo $fileServerType      >> /tmp/vars.txt
echo $storageAccountName  >> /tmp/vars.txt
echo $storageAccountKey   >> /tmp/vars.txt
echo $nfsVmName           >> /tmp/vars.txt
echo $nfsByoIpExportPath  >> /tmp/vars.txt
echo $htmlLocalCopySwitch >> /tmp/vars.txt
echo $redisDeploySwitch   >> /tmp/vars.txt
echo $redisDns            >> /tmp/vars.txt
echo $redisAuth           >> /tmp/vars.txt
echo $phpVersion          >> /tmp/vars.txt

# downloading and updating php packages from the repository 
  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt-get update

check_fileServerType_param $fileServerType

{
  # make sure the system does automatic update
  apt-get -y update
  # TODO: ENSURE THIS IS CONFIGURED CORRECTLY
  apt-get -y install unattended-upgrades

  # install pre-requisites
  apt-get -y install python-software-properties unzip rsyslog

  apt-get -y install postgresql-client mysql-client git

  if [ $fileServerType = "gluster" ]; then
    #configure gluster repository & install gluster client
    add-apt-repository ppa:gluster/glusterfs-3.10 -y
    apt-get -y update
    apt-get -y install glusterfs-client
  elif [ "$fileServerType" = "azurefiles" ]; then
    apt-get -y install cifs-utils
  fi

  # install the base stack
  # passing php versions $phpVersion
  apt-get -y install nginx php$phpVersion php$phpVersion-fpm php$phpVersion-cli php$phpVersion-curl php$phpVersion-zip php-pear php$phpVersion-mbstring php$phpVersion-dev mcrypt php$phpVersion-soap php$phpVersion-json php$phpVersion-redis php$phpVersion-bcmath php$phpVersion-gd php$phpVersion-pgsql php$phpVersion-mysql php$phpVersion-xmlrpc php$phpVersion-intl php$phpVersion-xml php$phpVersion-bz2

  # MSSQL
  if [ "$dbServerType" = "mssql" ]; then
    install_php_mssql_driver
  fi

  # PHP Version
  PhpVer=$(get_php_version)

  if [ $fileServerType = "gluster" ]; then
    # Mount gluster fs for /azlamp
    mkdir -p /azlamp
    chown www-data /azlamp
    chmod 770 /azlamp
    echo -e 'Adding Gluster FS to /etc/fstab and mounting it'
    setup_and_mount_gluster_share $glusterNode $glusterVolume /azlamp
  elif [ $fileServerType = "nfs" ]; then
    # mount NFS export (set up on controller VM--No HA)
    echo -e '\n\rMounting NFS export from '$nfsVmName':/azlamp on /azlamp and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount $nfsVmName /azlamp /azlamp
  elif [ $fileServerType = "nfs-ha" ]; then
    # mount NFS-HA export
    echo -e '\n\rMounting NFS export from '$nfsHaLbIP':'$nfsHaExportPath' on /azlamp and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount $nfsHaLbIP $nfsHaExportPath /azlamp
  elif [ $fileServerType = "nfs-byo" ]; then
    # mount NFS-BYO export
    echo -e '\n\rMounting NFS export from '$nfsByoIpExportPath' on /azlamp and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount0 $nfsByoIpExportPath /azlamp
  else # "azurefiles"
    setup_and_mount_azure_files_share azlamp $storageAccountName $storageAccountKey
  fi

  # Configure syslog to forward
  cat <<EOF >> /etc/rsyslog.conf
\$ModLoad imudp
\$UDPServerRun 514
EOF
  cat <<EOF >> /etc/rsyslog.d/40-remote.conf
local1.*   @${syslogServer}:514
local2.*   @${syslogServer}:514
EOF
  systemctl restart syslog

  # Build nginx config
  cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes 2;
pid /run/nginx.pid;

events {
	worker_connections 2048;
}

http {
  sendfile on;
  server_tokens off;
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
  #ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
  #upgrading to TLSv1.2 and droping 1 & 1.1
  ssl_protocols TLSv1.2;
  #ssl_prefer_server_ciphers on;
  #adding ssl ciphers
  ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;

  gzip on;
  gzip_disable "msie6";
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy

  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF

  # Set up html dir local copy if specified
  if [ "$htmlLocalCopySwitch" = "true" ]; then
    mkdir -p /var/www/html
    rsync -av --delete /azlamp/html/. /var/www/html
    setup_html_local_copy_cron_job
  fi

  config_all_sites_on_vmss $htmlLocalCopySwitch $httpsTermination

  # php config 
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
  # Redis for sessions
  if [ "$redisDeploySwitch" = "true" ]; then
    sed -i "s/session.save_handler.*/session.save_handler = redis/" $PhpIni
    sed -i "s/;session.save_path.*/session.save_path = \"tcp:\/\/$redisDns:6379?auth=$redisAuth\"/" $PhpIni
  fi
    
  # Remove the default nginx site
  rm -f /etc/nginx/sites-enabled/default

  # update startup script to wait for certificate in /azlamp mount
  setup_azlamp_mount_dependency_for_systemd_service nginx || exit 1

  # restart nginx
  systemctl restart nginx

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
pm.min_spare_servers = 20 
pm.max_spare_servers = 30 
EOF

  # Restart php-fpm
  systemctl restart php${PhpVer}-fpm

}  > /tmp/setup.log
