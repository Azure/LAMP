#!/bin/bash
set -ex

scriptName="$0"
redis_host="$1"
redis_port="$2"
redis_password="$3"
wp_directory="$4"

# function to print usage of this script to out
function usage {
    echo "usage: $scriptName <redis_host> <redis_port> <redis_password> <wp_directory>"
    echo "      <redis_host>            : host url where redis cache is hosted"
    echo "      <redis_port>            : port to connect on with redis"
    echo "      <redis_password>        : password to authenticate to redis"
    echo "      <wp_directory>          : path to wp directory"
}

# check if valid parameters are passed
# check number of arguments passed
if [[ $# -ne 4 ]]; then                                              
    usage
# arguments are not empty  
elif [[ -z "$redis_host" || -z "$redis_password" || -z "$redis_port" || -z "$wp_directory" ]]; then            
    usage
fi

redis_endpoint="$redis_host:$redis_port"
w3tc_config_path="$wp_directory/wp-content/w3tc-config/master.php"

# parse config file as json by replacing prefix in file contents temporarily
config_json=$(cat "$w3tc_config_path" | sed 's/<?php exit; ?>//' )
mv "$w3tc_config_path" "$w3tc_config_path.bak"

# set redis servers for all
config_json=$(echo $config_json | jq '."dbcache.redis.servers"=["'$redis_endpoint'"]')
config_json=$(echo $config_json | jq '."dbcache.redis.password"="'$redis_password'"')
config_json=$(echo $config_json | jq '."objectcache.redis.servers"=["'$redis_endpoint'"]')
config_json=$(echo $config_json | jq '."objectcache.redis.password"="'$redis_password'"')
config_json=$(echo $config_json | jq '."minify.redis.servers"=["'$redis_endpoint'"]')
config_json=$(echo $config_json | jq '."minify.redis.password"="'$redis_password'"')
config_json=$(echo $config_json | jq '."pgcache.redis.servers"=["'$redis_endpoint'"]')
config_json=$(echo $config_json | jq '."pgcache.redis.password"="'$redis_password'"')

# db cache config (disable but still keep it configured)
config_json=$(echo $config_json | jq '."dbcache.enabled"=false')
config_json=$(echo $config_json | jq '."dbcache.engine"="redis"')

# object cache config (enabled)
config_json=$(echo $config_json | jq '."objectcache.enabled"=true')
config_json=$(echo $config_json | jq '."objectcache.engine"="redis"')

# minify cache config (disable but still keep it configured)
config_json=$(echo $config_json | jq '."minify.enabled"=false')
config_json=$(echo $config_json | jq '."minify.engine"="redis"')

# page cache config (disable but still keep it configured)
config_json=$(echo $config_json | jq '."pgcache.enabled"=false')
config_json=$(echo $config_json | jq '."pgcache.engine"="redis"')

echo "<?php exit; ?>" > "$w3tc_config_path"
echo $config_json >> "$w3tc_config_path"