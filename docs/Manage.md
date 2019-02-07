# Managing a Scalable LAMP Cluster in Azure

This document provides an overview of how to perform various
management tasks on a scalable LAMP cluster on Azure.

## Prerequisites

In order to configure our deployment and tools we'll set up some
[environment variables](./Environment-Variables.md) to ensure consistency.

In order to manage a cluster it is clearly necessary to first [deploy
a scalable LAMP cluster on Azure](./Deploy.md).

For convenience and readability this document also assumes that essential [deployment details for your cluster have been assigned to environment variables](./Get-Install-Data.md).

## Updating PHP application code/settings

Your controller Virtual Machine has your PHP applications' code and data stored in
`/azlamp`. The site code is stored in `/azlamp/html/<yoursitename>/`. If `gluster` or
`nfs-ha` is selected for the `fileServerType` parameter at the deployment time, this
data is replicated across dual gluster or NFS-HA nodes to provide high
availability. This directory is also mounted to your autoscaling
frontends so all changes to files on the controller VM are immediately
available to all frontend machines (when the `htmlLocalCopySwitch` in `azuredeploy.json`
is false–otherwise, see below). 

Note that **the HTML directory is read-only for the web frontend VMs**. This means that any updates to your code or settings need to be done on the controller VM, manually replacing files or through shell commands, not a web browser. For example, you won't be able to use web-based admin tools that some applications offer (like WordPress, Drupal, Moodle...) to automatically update the codebase, install plugins and templates, etc.

Depending on how large your Gluster/NFS disks are sized, it may be helpful
to keep multiple older versions (`/azlamp/html/site1`, `/azlamp/html-backups/site1`, etc) to roll back if needed.

To connect to your Controller VM use SSH with a username of `azureadmin` (this can be changed with the `adminUsername` parameter when deploying the template) and the SSH provided in the `sshPublicKey` input parameter. For example, to retrieve a listing of files and directories in the `/azlamp` directory use:

```sh
ssh -o StrictHostKeyChecking=no azureadmin@$LAMP_CONTROLLER_INSTANCE_IP ls -l /azlamp
```

Results:

```text
total 32
drwxr-xr-x 2 root root  4096 Aug 28 18:27 bin
drwxr-xr-x 5 root root  4096 Aug  8 16:49 certs
drwxr-xr-x 5 root root  4096 Aug  8 16:52 data
drwxr-xr-x 5 root root  4096 Aug  8 16:48 html
```

> **Important note** It is important to realize that the `-o StrictHostKeyChecking=no` option in the above SSH command presents a security risk. It is included here to facilitate automated validation of these commands. It is not recommended to use this option in production environments, instead run the command manually and validate the host key. Subsequent executions of an SSH command will not require this validation step. For more information there is an excellent [superuser.com
Q&A](https://superuser.com/questions/421074/ssh-the-authenticity-of-host-host-cant-be-established/421084#421084).

### If you set `htmlLocalCopySwitch` to true (this is the default option)

Originally the `/azlamp/html` directory was accessed by web server processes directly across all autoscaled web VMs through the specified file server (Gluster or NFS), and this is was good for web response time. Therefore, we introduced the `htmlLocalCopySwitch` that'll copy the `/azlamp/html` directory to `/var/www/html` in each autoscaled web VM and reconfigures the (nginx) web server's server root directory accordingly, when it's set to true. This now requires directory sync between `/azlamp/html` and `/var/www/html`, and currently it's addressed by simple polling (minutely). Therefore, if you are going to update your application's PHP code/settings with the switch set to true, please follow the following steps:

* Depending on the application that you're running, you might want to put it in maintenance mode first, if possible (this is application-specific).
  * This will need to be done on the contoller VM with some shell command.
  * It should be followed by running the following command to propagate the change to all autoscaled web VMs:
    ```sh
    sudo /usr/local/bin/update_last_modified_time.azlamp.sh
    ```
  * Once this command is executed, each autoscaled web VM will pick up (sync) the changes within 1 minute, so wait for one minute.
* Then you can start updating your application's code/settings, like installing/updating plugins, or upgrading version, or changing configurations stored in files. Again, note that this should be all done on the controller VM using some shell commands, or manually replacing files using SFTP (file transfer over SSH).
* When you are done updating your code/settings, run the same command as above (`sudo /usr/local/bin/update_last_modified_time.azlamp.sh`) to let each autoscaled web VM pick up (sync) the changes (wait for another minute here, for the same reason).

Please do let us know on this GitHub repo's Issues if you encounter any problems with this process.

### SSH Access to other VMs in the cluster

By default, only the Controller VM has port 22 open to accept connections from external clients. The LAMP cluster is designed to be fully automated and self-healing, and all of the webservers' logs are sent to the Controller VM.

In the rare case you need to connect to another VM inside the cluster (e.g. one of the web servers in the VMSS cluster, or a GlusterFS node), you can use the controller VM as jumpbox, and connect using SSH agent forwarding.

First, identify the private IP of the VM you want to connect to inside the cluster. By default, VMs are in the `172.31.0.0/16` address space (configurable with the `vNetAddressSpace` property), and you can see the list of VMs connected to a Virtual Network by looking at the VNet on the Azure Portal.

The next step is to enable SSH agent forwarding **on your laptop**. On Linux, macOS and on Windows 10 using the Windows Subsystem for Linux, assuming your SSH private key is in `~/.ssh/id_rsa`, first add the private key to your SSH agent with:

```sh
# On your laptop:
ssh-add ~/.ssh/id_rsa
# If the private key has a password, you'll be asked to type it
```

Connect to the public IP or DNS name of the controller VM, making sure to specify the `-A` switch to enable forwarding of your SSH agent:

```sh
# On your laptop:
ssh -A user@ip-or-dns
```

Once you're connected via SSH to the controller, you can jump to other nodes connecting via SSH to their private IPs. For example:

```sh
# From the controller (connected via SSH)
# "private-ip" is something like 172.31.0.5
ssh private-ip
```

## Getting a database dump

To obtain a SQL dump you run the commands appropriate for your chosen database on the Controller VM.

### PostgreSQL

PostgreSQL provides a `pg_dump` command that can be used to take a
snapshot of the database via SSH. For example, use the following
command (make sure to specify the database name replacing `database_name`):

```sh
ssh azureadmin@$LAMP_CONTROLLER_INSTANCE_IP 'pg_dump -Fc -h $LAMP_DATABASE_DNS -U $LAMP_DATABASE_ADMIN_USERNAME database_name | gzip > /azlamp/data/<your_site_fqdn>/db-snapshot.sql.gz'
```

You can also download the file directly to your laptop:

```sh
ssh azureadmin@$LAMP_CONTROLLER_INSTANCE_IP 'pg_dump -Fc -h $LAMP_DATABASE_DNS -U $LAMP_DATABASE_ADMIN_USERNAME database_name' | gzip > db-snapshot.sql.gz'
```

See the Postgres documentation for full details of the [`pg_dump`](https://www.postgresql.org/docs/9.5/static/backup-dump.html) command.

### MySQL

MySQL provides a `mysql_dump` command that can be used to take a
snapshot of the database via SSH. For example, use the following
command (make sure to specify the database name replacing `database_name`):

```sh
ssh azureadmin@$LAMP_CONTROLLER_INSTANCE_IP 'mysqldump -h $LAMP_DATABASE_DNS -u $LAMP_DATABASE_ADMIN_USERNAME -p'${LAMP_DATABASE_ADMIN_PASSWORD}' --databases database_name | gzip > /azlamp/data/<your_site_fqdn>/db-backup.sql.gz'
```

You can also download the file directly to your laptop:

```sh
ssh azureadmin@$LAMP_CONTROLLER_INSTANCE_IP 'mysqldump -h $LAMP_DATABASE_DNS -u $LAMP_DATABASE_ADMIN_USERNAME -p'${LAMP_DATABASE_ADMIN_PASSWORD}' --databases database_name' | gzip > db-backup.sql.gz'
```

## Backup and Recovery

If you have set the `azureBackupSwitch` in the input parameters to `1` then Azure will provide VM backups of your GlusterFS nodes, using the Azure Backup service. This is recommended as it contains both your PHP code and your site data.
Restoring a backed-up VM is outside the scope of this doc, but documentation on Azure Recovery Services can be found here: https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-first-look-arm

## Resizing your Database

Note: This process involves site downtime and should therefore only be
carried out during a planned maintenance window.

At the time of writing Azure does not support resizing MySQL or
PostgreSQL databases between tiers. You can, however, create a new database instance,
with a different size, and change your config to point to that. To get
a different size database you'll need to:

  1. Depending on the application that you're running, you might want to put it in maintenance mode first, if possible (this is application-specific); follow the same process as when you are updating the code.
  2. Perform an SQL dump of your database. See above for more details.
  3. Create a new Azure database of the size you want inside your existing Resource Group.
  4. Restore the dump in the new database. Make sure you re-create the same databases (with the same names) and users.
  5. On the controller instance, change the db setting in your app's `config.php` file to point to the new database (the exact location and configuration is specific to your application).
  6. Take your site out of maintenance mode; follow the same process as when you are updating the code.
  7. Once confirmed working, delete the previous database instance.

How long this takes depends entirely on the size of your database and
the speed of your VM tier. It will always be a large enough window to
make a noticeable outage.

## Changing the SSL cert

The self-signed cert generated by the template is suitable for very
basic testing, but a public website will want a real cert. After
purchasing a trusted certificate, it can be copied to the following
files to be ready immediately:

  - `/azlamp/certs/<your_site_fqdn>/nginx.key`: Your certificate's private key
  - `/azlamp/certs/<your_site_fqdn>/nginx.crt`: Your combined signed certificate and trust chain certificate(s).

## Managing Azure DDoS protection

By default, every plublic IP is protected by Azure DDoS protection Basic SKU. 
You can find more information about Azure DDoS protection Basic SKU [here](https://docs.microsoft.com/en-us/azure/virtual-network/ddos-protection-overview).

If you want more protection, you can activate Azure DDoS protection Standard SKU by setting the `ddosSwith` to true. You can find how to work with Azure DDoS protection plan [here](https://docs.microsoft.com/en-us/azure/virtual-network/manage-ddos-protection#work-with-ddos-protection-plans).

If you want to disable the Azure DDoS protection, you can follow the instruction  [here](https://docs.microsoft.com/en-us/azure/virtual-network/manage-ddos-protection#disable-ddos-for-a-virtual-network).

Be careful, disabling the Azure DDoS protection on your VNet will not stop charges. You have to delete the Azure DDoS protection plan if you want to stop being charged.

If you have deployed your cluster without Azure DDoS protection plan, you still can activate the Azure DDoS protection plan thanks to the instruction [here](https://docs.microsoft.com/en-us/azure/virtual-network/manage-ddos-protection#enable-ddos-for-an-existing-virtual-network).

## Next Steps

  1. [Retrieve configuration details using CLI](./Get-Install-Data.md)
