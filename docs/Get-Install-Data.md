# Retrieve essential install details

Once a deployment has completed the ARM template will output some values that you will need for managing your cluster. These are available in the Azure Portal too, but in this document we will retrieve them using the Azure CLI. This document describes the available parameters and how to retrieve them.

## Prerequisites

In order to configure our deployment and tools we'll set up some [environment variables](./Environment-Variables.md) to ensure consistency.

## Output Paramater Overview

The available output parameters are:

  - **loadBalancerDNS**: This is the DNS name of your application load balancer. To add a custom domain,  you'll need to add a CNAME entry in your DNS zone that should point to this address.
  - **controllerInstanceIP**: This is the IP address of the controller
    Virtual Machine. You will need to SSH into this to make changes to
    your applications' code, or view logs.
  - **databaseDNS**: This is the public DNS of your database instance. If you wish to set up local backups or access the DB directly, you'll need to use this. (Note that by default, firewall rules forbid access to the database from external resources; you can configure the database's firewall using the Azure Portal)
  - **databaseAdminUsername**: The admin username for your database (MySQL, PostgreSQL or Azure SQL).
  - **databaseAdminPassword**: The admin password for your database (MySQL, PostgreSQL or Azure SQL).

## Retrieving Output Parameters Using the CLI

To get a complete list of outputs in json format use:

```sh
az group deployment show \
  --resource-group $LAMP_RG_NAME \
  --name $LAMP_DEPLOYMENT_NAME \
  --out json \
  --query *.outputs
```

Individual outputs can be retrieved by filtering, for example, to get
just the value of the `loadBalancerDNS` use:

```sh
az group deployment show \
  --resource-group $LAMP_RG_NAME \
  --name $LAMP_DEPLOYMENT_NAME \
  --out json \
  --query *.outputs.loadBalancerDNS.value
```

However, since we are requesting JSON output (the default) the value
is enclosed in quotes. In order to remove these we can output as a tab
separated list (TSV):

```sh
az group deployment show \
  --resource-group $LAMP_RG_NAME \
  --name $LAMP_DEPLOYMENT_NAME \
  --out tsv \
  --query *.outputs.loadBalancerDNS
```

Now we can assign individual values to environment variables, for example:

```sh
LAMP_LOAD_BALANCER_DNS="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.loadBalancerDNS.value)"
```

### Retrieving Site Load Balancer URL

The load balancer DNS is the publicly registered DNS name for your
cluster's DNS. You should point your custom domain to this hostname, with a CNAME record.

```sh
LAMP_LOAD_BALANCER_DNS="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.loadBalancerDNS.value)"
```

### Retriving Controller Virtual Machine Details

The controller VM runs management tasks for the cluster, such as syslog.

```sh
LAMP_CONTROLLER_INSTANCE_IP="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.controllerInstanceIP.value)"
```

There is no username and password for this VM since a username and SSH key are provided as input parameters to the template.

### Retreiving Database Information

#### Database URL

```sh
LAMP_DATABASE_DNS="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.databaseDNS.value)"
```

#### Database admin username

```sh
LAMP_DATABASE_ADMIN_USERNAME="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.databaseAdminUsername.value)"
```

#### Database admin password

```sh
LAMP_DATABASE_ADMIN_PASSWORD="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.databaseAdminPassword.value)"
```

### Retrieving Virtual Network Information

First frontend VM IP:

```sh
LAMP_FIRST_FRONTEND_VM_IP="$(az group deployment show --resource-group $LAMP_RG_NAME --name $LAMP_DEPLOYMENT_NAME --out tsv --query *.outputs.firstFrontendVmIP.value)"
```

This will be a private IP, inside the Virtual Network. You can connect to this VM using the controller instance as jumpbox, and SSH agent forwarding (see the instructions in the [Readme](./Readme.md))

## Validation

After having run each of the commands in this document you should have
each of the output parameters available in environment variable:

```sh
echo $LAMP_LOAD_BALANCER_DNS
echo $LAMP_ADMIN_PASSWORD
echo $LAMP_CONTROLLER_INSTANCE_IP
echo $LAMP_DATABASE_DNS
echo $LAMP_DATABASE_ADMIN_USERNAME
echo $LAMP_DATABASE_ADMIN_PASSWORD
echo $LAMP_FIRST_FRONTEND_VM_IP
```

## Next Steps

  1. [Manage the cluster](./Manage.md)
