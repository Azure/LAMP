# Prepare cluster for LAMP applications

If you chose Apache as your `webServerType` and `true` for the `htmlLocalCopy` switch at your Moodle cluster deployment time, you can install additional LAMP sites on your Moodle cluster, utilizing Apache's VirtualHost feature (we call this "LAMP generalization"). To generalize an installed Moodle cluster so you can run LAMP applications, you'll first need to login to the Moodle cluster controller virtual machine. The directory you'll need to work out of is `/azlamp`. 

## Removing all Moodle content

Leaving the Moodle related content in place is not detrimental but if you'd like to remove all Moodle related content, please locate the directories (under `/azlamp/html`, `/azlamp/data`, and `/azlamp/certs`, and delete the corresponding subdirectories). If this is done after a fresh cluster installation, there's only sub-directory each in each of the three mentioned directories:

```
rm -rf /azlamp/html/<your_moodle_siteURL_or_lb_dns>
rm -rf /azlamp/data/<your_moodle_siteURL_or_lb_dns>
rm -rf /azlamp/certs/<your_moodle_siteURL_or_lb_dns>
```

## Configuring the controller for a specific LAMP application (WordPress)


### Installation Destination
An example LAMP application (WordPress) is illustrated here for the sake of clarity. The approach is similar to any LAMP application out there. 

First, you'd need to navigate to `/azlamp/html` and create a directory based on a domain name you have in mind. An example domain name is used below:

```
cd /azlamp/html
mkdir wpsitename.mydomain.com
cd /azlamp/html/wpsitename.mydomain.com
```

Once that's done and you've downloaded the latest version of WordPress, please follow the instructions here to complete configuring a database and finishing a [WordPress install](https://codex.wordpress.org/Installing_WordPress#Famous_5-Minute_Installation). 

```
wget https://wordpress.org/latest.tar.gz
tar xvfz latest.tar.gz --strip 1
```


### SSL Certs

The certificates for your LAMP application reside in `/azlamp/certs/yourdomain` or in this instance, `/azlamp/certs/wpsitename.mydomain.com`

```
mkdir /azlamp/certs/wpsitename.mydomain.com
```

Copy over the .crt and .key files over to `/azlamp/certs/wpsitename.mydomain.com`.
The file names should be changed to `nginx.crt` and `nginx.key` in order to be recognized by the configured nginx servers.

It's recommended that the certificate files be read-only to owner and that these files are owned by *www-data*:

```
chown www-data:www-data /azlamp/certs/wpsitename.mydomain.com/*
chmod 400 /azlamp/certs/wpsitename.mydomain.com/*
```


### Linking to the content/cluster data location

Navigate to the WordPress content directory and run the following command:

```
mkdir -p /azlamp/data/wpsitename.mydomain.com/wp-content/uploads
cd /azlamp/html/wpsitename.mydomain.com
ln -s /azlamp/data/wpsitename.mydomain.com/wp-content/uploads .
```

This step is needed because the `<siteroot>/wp-content/uploads` directory need to be shared across all web frontend instances, and Wordpress configuration doesn't allow an external directory to be used as the uploads repository. In fact, Drupal also has a similar design, so a similar symbolic link will be needed for Drupal as well. This is in contrary to Moodle, which allows users to configure any external directory as its file storage location.

### Update Apache configurations on all web frontend instances

Once the correspnding html/data/certs directories are configured, we need to reconfigure all Apache services on web frontend instances, so that newly created sites are added to the Apache VirtualHost configurations and deleted sites are removed from them as well. This is done by the `/azlamp/bin/update-vmss-config` hook (executed every minute on each and every VMSS instance using a cron job), which requires us to provide the commands to run (to reconfigure Apache service) on each VMSS instance. There's already a utility script installed for that, so it's easy to achieve as follows.

On the controller machine, look up the file `/azlamp/bin/update-vmss-config`. If you haven't modified that file, you'll see the following lines in the file:

```
        #1)
        #    . /azlamp/bin/utils.sh
        #    reset_all_sites_on_vmss true VMSS apache
        #;;
```

Remove all the leading `#` characters from these lines (uncommenting) and save the file, then wait for a minute. After that, your newly added sites should be available through the domain names specified/used as the directory names (Of course this assumes you set up your DNS records for your new site FQDNs so that their CNAME records point to the deployed Moodle cluster's load balancer DNS name, whis is of the form `lb-xyz123.an_azure_region.cloudapp.azure.com`).

If you are adding sites for the second or later time, you'll already have the above lines commented out. Just create another `case` block, copying the 4 lines, but make sure to change the number so that it's one greater than the last VMSS config version number (you should be able to find that from the script).

The last step is to let the `/azlamp/html` directory sync with `/var/www/html` in every VMSS instance. This should be done by running `/usr/local/bin/update_last_modified_time.azlamp.sh` script on the controller machine as root. Once this is run and after a minute, the `/var/www/html` directory on every VMSS instance should be the same as `/azlamp/html`, and the newly added sites should be available.

At this point, your LAMP application is setup to use in the LAMP cluster. If you'd like to install a separate LAMP application (WordPress or otherwise), you'll have to repeat the process listed here with a new domain for the new application.