# Deploy Autoscaling LAMP Stack to Azure

After following the steps in this this document you will have a new cluster with auto-scaling frontends, ready to host your LAMP applications at scale.
The filesystem behind it is mirrored for high availability and
optionally backed up through Azure.

## Prerequisites

To make things consitent across different sessions managing the cluster we
should [configure the environment](./Preparation.md).

## Create Resource Group

When you deploy the template, you will create many resources. On Azure it is a best practice to collect such resources together in a Resource Group. The first thing we need to do, therefore, is create a resource group:

```sh
az group create --name $LAMP_RG_NAME --location $LAMP_RG_LOCATION
```

Results:

```expected_similarity=0.4
{
  "id": "/subscriptions/325e7c34-99fb-4190-aa87-1df746c67705/resourceGroups/rglamparm3",
  "location": "westus2",
  "managedBy": null,
  "name": "rglamparm3",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null
}
```

## Create Azure Deployment Parameters

Your deployment will be configured using an
`azuredeploy.parameters.json` file. It is possible to provide these
parameters interactively via the command line by simply omitting the
paramaters file in the command in the next section. However, it is
more reproducible if we use a paramaters file.

A good set of defaults are provided in the GitHub repository. These
defaults create a scalable cluster that is suitable for low volume
testing. If you are building out a production service you should
review the section below on sizing considerations. For now we will
proceed with the defaults, but there is one value, the `sshPublicKey`
that **must** be provided. The following command will replace the
placeholder in the parameters template file with an SSH key used for
testing puporses (this is created as part of the envrionment setup in
the prerequisites):

```sh
ssh_pub_key=`cat $LAMP_SSH_KEY_FILENAME.pub`
echo $ssh_pub_key
sed "s|GEN-SSH-PUB-KEY|$ssh_pub_key|g" $LAMP_AZURE_WORKSPACE/arm_template/azuredeploy.parameters.json > $LAMP_AZURE_WORKSPACE/$LAMP_RG_NAME/azuredeploy.parameters.json
```

If you'd like to configure the cluster (to be deployed)
with your own SSL certificate for your domain (siteURL) at the
deployment time, you can do so by using [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/)
and following the instructions in the [SSL cert documentation](SslCert.md).

For more information see the [parameters documentation](Parameters.md).

## Deploy cluster

Now that we have a resource group and a configuration file we can
create the cluster itself. This is done with a single command:

```sh
az group deployment create \
  --name $LAMP_DEPLOYMENT_NAME \
  --resource-group $LAMP_RG_NAME \
  --template-file $LAMP_AZURE_WORKSPACE/arm_template/azuredeploy.json \
  --parameters $LAMP_AZURE_WORKSPACE/$LAMP_RG_NAME/azuredeploy.parameters.json
```

## Using the created stack

In testing, stacks typically took between 0.5 and 1 hour to finish,
depending on spec. Once complete you will receive a JSON output
containing information needed to manage your cluster (see
`outputs`). You can also retrieve this infromation from the portal or
the CLI.

Once the cluster has been created, and (where necessary) you have
configured your custom `siteURL` DNS to point to the
`loadBalancerDNS`, you should be able to load the `siteURL` in a
browser. Note that the values for each of these
parameters are available in the portal or the `outputs` section of the
JSON response from the previous deploy command. See [documentation on
how to retrieve configuration data](./Get-Install-Data.md) along
with full details of all the output parameters available to you.

Note that by default the deployment uses a self-signed certificate,
consequently you will receive a warning when accessing the site. To
add a genuine certificate see the documentation on [managing your
cluster](./Manage.md).

## Sizing Considerations and Limitations

Depending on the LAMP apps you deploy and the expected traffic, you will want to configure your deployment appropriately. The defaults included produce a cluster that is inexpensive but probably too low spec to use beyond simple testing scenarios. This section includes an overview of how to size the database and VM instances for your use case.

### Database Sizing

As of the time of this writing, Azure supports "Basic", "General Purpose" and "Memory Optimized" tiers for MySQL/PostgreSQL database instances. In addition the `mysqlPgresVcores` parameter defines the number of vCores for each DB server instance, and the number of those you can use is limited by database tier:

- Basic: 1, 2
- General Purpose: 2, 4, 8, 16, 32
- Memory Optimized: 2, 4, 8, 16

This value also limits the maximum number of connections, as defined
here: https://docs.microsoft.com/en-us/azure/mysql/concepts-limits

The appropriate size for the database depends entirely on the individual sites and the traffic. As MySQL databases cannot change to (or be restored to) a different tier (e.g. Basic to General Purpose) once deployed, it is a good idea to slightly overspec your database.

All MySQL/PostgreSQL database storage, regardless of tier, have a hard upper limit of 1
terabyte (1024 GB), starting from 5 GB minimum, increasing by 1 GB. You gain additional iops for each added GB, so if you're expecting a heavy amount of traffic you will want to oversize your storage. The current maximum iops with a 1TB disk is 3,000.

### Controller instance sizing

The controller primarily acts as a syslog server.

Depending on the applications you are installing in your cluster, you might want to leverage the controller VM also for running cron jobs (example of applications which need that include Moodle, NextCloud, etc). In this case, sizing for the controller instance depends on how big your cron runs are; if they are very delayed and cron processes are building up on the controller, then an upgraded tier might be necessary.

### Frontend instances

In general the frontend instances will not be the source of any
bottlenecks unless they are severely undersized versus the rest of the
cluster. More powerful instances will be needed should FPM processes
spawn and exhaust memory during periods of heavy site load. This can
also be mitigated against by increasing the number of VMs, but spawning
new VMs is slower than having that capacity already available.

It is worth noting that the memory allowances on these instances allow
for more memory than they may be able to provide with lower instance
tiers. This is intentional as you can opt to run larger VMs with more
memory and not require manual configuration. FPM also allows for a
very large number of threads which prevents the system from failing
during many small jobs.


## Next Steps

  1. [Retrieve configuration details using CLI](./Get-Install-Data.md)
  1. [Manage the cluster](./Manage.md)
