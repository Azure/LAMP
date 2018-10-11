# Prepare cluster for LAMP applications

To generalize an installed Moodle cluster so you can run LAMP applications, you'll first need to login to the Moodle cluster controller virtual machine. The directory you'll need to work out of is /azlamp. 

## Removing all Moodle content

Leaving the Moodle related content in place is not detrimental but if you'd like to remove all Moodle related content, please locate the directories (under /azlamp/html and /azlamp/data and delete the directory structure). If this is done after a fresh cluster installation, there's only sub-directory each (starting with 'lb') in each of the two mentioned directories:

```rm -rf /azlamp/html/lb-n5o57b.westus2.cloudapp.azure.com```
```rm -rf /azlamp/data/lb-n5o57b.westus2.cloudapp.azure.com```

## Configuring the controller for a specific LAMP application (WordPress)


### Installation Destination
An example LAMP application (WordPress) is illustrated here for the sake of clarity. The approach is similar to any LAMP application out there. 

First, you'd need to navigate to /azlamp/html and create a directory based on a domain name you have in mind. An example domain name is used below:

```cd /azlamp/html```

```mkdir wpsitename.mydomain.com```

Once that's done and you've downloaded the latest version of WordPress, please follow the instructions here to complete configuring a database and finishing a [WordPress install](https://codex.wordpress.org/Installing_WordPress#Famous_5-Minute_Installation). 

```wget https://wordpress.org/latest.tar.gz```

```tar xvfz latest.tar.gz```


### SSL Certs

The certificates for your LAMP application reside in /azlamp/certs/yourdomain or in this instance, /azlamp/certs/wpsitename.mydomain.com

```mkdir /azlamp/certs/wpsitename.mydomain.com```

Copy over the .crt and .key files over to */azlamp/certs/wpsitename.mydomain.com*

It's recommended that the certificate files be read-only to owner and that these files are owned by *www-data*:

```chown www-data:www-data /azlamp/certs/wpsitename.mydomain.com/*```
```chmod 400 /azlamp/certs/wpsitename.mydomain.com/*```


### Linking to the content/cluster data location

Navigate to the WordPress content directory and run the following command:
```cd /azlamp/html/wpsitename.mydomain.com```
```ln -s /azlamp/data/wpsitename.mydomain.com/wp-content/uploads .```


At this point, your LAMP application is setup to use in the LAMP cluster. If you'd like to install a separate LAMP application (WordPress or otherwise), you'll have to repeat the process listed here with a new domain for the new application.