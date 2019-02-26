
# Deploy and Manage a Scalable LAMP Cluster on Azure

This repo contains guides and [Azure Resource Manager](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview) templates designed to help you deploy and manage a highly available and scalable
[LAMP](https://en.wikipedia.org/wiki/LAMP_(software_bundle)) cluster on Azure. The template(s) provided here deploy an *empty* infrastructure/stack to deploy any general LAMP application.

If you have Azure account you can deploy LAMP via the [Azure Portal](https://portal.azure.com) using the buttons below. Please note that while you can use an [Azure free account](https://aka.ms/azure-free-phprefarch) to get started, depending on which template configuration you choose you will likely be required to upgrade to a paid account.

## Fully configurable deployment

The following button will allow you to specify various configurations for your LAMP cluster deployment. The number of configuration options might be overwhelming, so some pre-defined/restricted deployment options for typical LAMP scenarios follow this.

[![Deploy to Azure Fully Configurable](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FLAMP%2Fmaster%2Fazuredeploy.json)  [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FLAMP%2Fmaster%2Fazuredeploy.json)

## Predefined deployment options

Below are a list of pre-defined/restricted deployment options based on typical deployment scenarios (i.e. dev/test, production etc.) All configurations are fixed and you just need to pass your SSH public key to the template for logging in to the deployed VMs. Please note that the actual cost will be bigger with potentially autoscaled VMs, backups and network cost.

| Deployment Type | Description | Estimated Cost | Launch |
| --- | --- | --- | ---
| Minimal  | This deployment will use NFS, Microsoft SQL, and smaller autoscale web frontend VM sku (1 core) that'll give faster deployment time (less than 30 minutes) and requires only 2 VM cores. Currently this will fit even in a free Azure trial subscription.|[link](https://azure.com/e/5f9752c934ab41799ae3264dd2ee57d1)|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FLAMP%2Fmaster%2Fazuredeploy-minimal.json)
| Small to Mid-Size | Supporting up to 1,000 concurrent users. This deployment will use NFS (with no high availability) and MySQL (8 vCores), without other options like Redis Cache.|[link](https://azure.com/e/fd794268d0bf421aa17c626fb88f25bc)|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FLAMP%2Fmaster%2Fazuredeploy-small2mid-noha.json)
|Large size deployment (with high availability)| Supporting more than 2,000 concurrent users. This deployment will use GlusterFS (in high availability, requiring 2 VMs), MySQL (16 vCores) and Redis Cache. |[link](https://azure.com/e/078f7294ab6544e8911ddc2ee28850d7)|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FLAMP%2Fmaster%2Fazuredeploy-large-ha.json)
| Maximum |This maximal deployment will use GlusterFS (in high availability, adding 2 VMs for a GlusterFS cluster), MySQL with the highest SKU, Redis Cache, and pretty large storage sizes (for both data disks and DB).|[link](https://azure.com/e/e0f959b93ed84eb891dcc44f7883f5b5)|[![Deploy to Azure Maximally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FLAMP%2Fmaster%2Fazuredeploy-maximal.json)

## Stack Architecture

This template set deploys the following infrastructure core to your LAMP instance:

- Autoscaling web frontend layer (with nginx and PHP-FPM)
- Private Virtual Network for frontend instances
- Controller VM running cron and handling syslog for the autoscaling cluster
- [Azure Load balancer](https://azure.microsoft.com/en-us/services/load-balancer/) to balance across the autoscaling instances
- [Azure Database for MySQL](https://azure.microsoft.com/en-us/services/mysql/) or [Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/services/postgresql/) or [Azure SQL Database](https://azure.microsoft.com/en-us/services/sql-database/)
- Dual [GlusterFS](https://www.gluster.org/) nodes or NFS for highly available access to LAMP files

# Next Steps

## Prepare deployed cluster for LAMP applications

If you chose `true` for the `htmlLocalCopy` switch at your LAMP cluster deployment time, you can install additional LAMP sites on your cluster, utilizing Nginx's virtual host feature. To manage your installed cluster, you'll first need to login to the LAMP cluster controller virtual machine. The directory you'll need to work out of is `/azlamp`. You will need privileged access which means that you'll either need to be root (superuser) or have *sudo* access.

## Configuring the controller for a specific LAMP application (WordPress)

### Connect via SSH

You can connect via SSH to the controller VM. From a Linux, macOS or Windows 10 client using the Windows Subsystem for Linux, you can connect to the controller's VM using SSH and the public IP or DNS name of the controller.

```sh
ssh user@ip-or-dns
```

The username can be configured with `sshUsername`; the default value is `azureadmin`. You'll be authenticating using your SSH private key, so no password is necessary for the SSH user.

### Installation Destination

An example LAMP application (WordPress) is illustrated here for the sake of clarity. The approach is similar to any LAMP application out there.

First, you'd need to navigate to `/azlamp/html` and create a directory based on a domain name you have in mind. An example domain name is used below:

```sh
cd /azlamp/html
mkdir wpsitename.mydomain.com
cd /azlamp/html/wpsitename.mydomain.com
```

Download the latest version of WordPress, for example with:

```sh
wget https://wordpress.org/latest.tar.gz
tar xvfz latest.tar.gz --strip 1
```

### SSL Certs

The certificates for your LAMP application reside in `/azlamp/certs/yourdomain` or in this instance, `/azlamp/certs/wpsitename.mydomain.com`

```sh
mkdir /azlamp/certs/wpsitename.mydomain.com
```

Copy over the .crt and .key files over to `/azlamp/certs/wpsitename.mydomain.com`.
The file names should be changed to `nginx.crt` and `nginx.key` in order to be recognized by the configured nginx servers. Depending on your local environment, you may choose to use the utility *scp* or a tool like [WinSCP](https://winscp.net/eng/download.php) to copy these files over to the cluster controller virtual machine.

You can also generate a self-signed certificate, useful for testing only:

```sh
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /azlamp/certs/wpsitename.mydomain.com/nginx.key \
  -out /azlamp/certs/wpsitename.mydomain.com/nginx.crt \
  -subj "/C=US/ST=WA/L=Redmond/O=IT/CN=wpsitename.mydomain.com"
```

It's recommended that the certificate files be read-only to owner and that these files are owned by *www-data*:

```sh
chown www-data:www-data /azlamp/certs/wpsitename.mydomain.com/nginx.*
chmod 400 /azlamp/certs/wpsitename.mydomain.com/nginx.*
```

### Linking to the content/cluster data location

Navigate to the WordPress content directory and run the following command:

```sh
mkdir -p /azlamp/data/wpsitename.mydomain.com/wp-content/uploads
ln -s /azlamp/data/wpsitename.mydomain.com/wp-content/uploads /azlamp/html/wpsitename.mydomain.com/wp-content/uploads
chmod 0777 /azlamp/data/wpsitename.mydomain.com/wp-content/uploads
```

This step is needed because the `<siteroot>/wp-content/uploads` directory need to be shared across all web frontend instances, and WordPress configuration doesn't allow an external directory to be used as the uploads repository. In fact, Drupal also has a similar design, so a similar symbolic link will be needed for Drupal as well. This is in contrary to Moodle, which allows users to configure any external directory as its file storage location.

### Update Nginx configurations on all web frontend instances

Once the correspnding html/data/certs directories are configured, we need to reconfigure all Nginx services on web frontend instances, so that a virtual host is added for each newly added site, and old ones are removed. This is done by the `/azlamp/bin/update-vmss-config` hook (executed every minute on each and every VMSS instance using a cron job), which requires us to provide the commands to run on each VMSS instance. There's already a utility script installed for that, so it's easy to achieve this.

On the controller machine, look up the file `/azlamp/bin/update-vmss-config`. If you haven't modified that file, you'll see the following lines in the file:

```sh
        #1)
        #    . /azlamp/bin/utils.sh
        #    reset_all_sites_on_vmss true VMSS
        #;;
```

Remove all the leading `#` characters from these lines (to uncomment them) and save the file, then wait for about a minute. After that, your newly added sites should be available through the domain names specified/used as the directory names (Of course this assumes you set up your DNS records for your new site FQDNs so that their CNAME records point to the deployed LAMP cluster's load balancer DNS name, whis is of the form `lb-xyz123.an_azure_region.cloudapp.azure.com`).

If you make changes and add or remove websites at a later time, you'll already have the above lines commented out. Just create another `case` block, copying the 4 lines, but make sure to change the number so that it's one greater than the last VMSS config version number (you should be able to find that from the script). As an example, the final text would look like:

```sh
        1)
            . /azlamp/bin/utils.sh
            reset_all_sites_on_vmss true VMSS
        ;;
        2)
            . /azlamp/bin/utils.sh
            reset_all_sites_on_vmss true VMSS
        ;;
```

### Replicate PHP files

The last step is to let the `/azlamp/html` directory sync with `/var/www/html` in every VMSS instance. This should be done by running **this script on the controller machine**, as root:

```sh
/usr/local/bin/update_last_modified_time.azlamp.sh
```

Once this is run and after a minute, the `/var/www/html` directory on every VMSS instance should be the same as `/azlamp/html`, and the newly added sites should be available.

At this point, your app is setup to use in the LAMP cluster. If you'd like to install a separate LAMP application (WordPress or otherwise), you'll have to repeat the process listed here with a new domain for the new application.

### WordPress installer

Once you completed the steps above and you can see your WordPress website running in the browser, please follow the instructions here to complete configuring a database and finishing a [WordPress install](https://codex.wordpress.org/Installing_WordPress#Famous_5-Minute_Installation).

If you chose `true` for the `htmlLocalCopy` switch, WordPress will be running from a read-only directory, so the installer won't be able to create a `wp-config.php` file for you. However, the installer will provide you with the full content of the required config file. On the controller VM, copy that content into the file `/azlamp/html/wpsitename.mydomain.com/wp-config.php`. You then need to trigger a replication of the data, by running the script `/usr/local/bin/update_last_modified_time.azlamp.sh` again from the controller VM, as root. Data will be replicated in around one minute.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of
Conduct](https://opensource.microsoft.com/codeofconduct/). For more
information see the [Code of Conduct
FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Legal Notices

Microsoft and any contributors grant you a license to the Microsoft
documentation and other content in this repository under the [Creative
Commons Attribution 4.0 International Public
License](https://creativecommons.org/licenses/by/4.0/legalcode), see
the [LICENSE](LICENSE) file, and grant you a license to any code in
the repository under the [MIT
License](https://opensource.org/licenses/MIT), see the
[LICENSE-CODE](LICENSE-CODE) file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products
and services referenced in the documentation may be either trademarks
or registered trademarks of Microsoft in the United States and/or
other countries. The licenses for this project do not grant you rights
to use any Microsoft names, logos, or trademarks. Microsoft's general
trademark guidelines can be found at
http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/en-us/

Microsoft and any contributors reserve all others rights, whether
under their respective copyrights, patents, or trademarks, whether by
implication, estoppel or otherwise.
