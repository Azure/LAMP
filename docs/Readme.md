
# Deploy and Manage a Scalable LAMP cluster on Azure

The core documentation provided here is about deploying and managing a Moodle (a popular LAMP application) on Azure. However, with a few simple manual steps, you can take the provisioned Moodle cluster and arrive at a general cluster for running any LAMP application.

While you can manually [deploy](Deploy.md) a Moodle cluster and this option offers you complete control, it's recommended you deploy the Moodle cluster using an ARM template, especially if you aren't command line savvy.

## Cluster Deployment

The following button will allow you to specify various configurations for your Moodle cluster
deployment. The number of configuration options might be overwhelming, so some pre-defined/restricted deployment options for
typical Moodle scenarios follow this.

[![Deploy to Azure Fully Configurable](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy.json)  [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy.json)

NOTE:  All of the deployment options require you to provide a valid SSH protocol 2 (SSH-2) RSA public-private key pairs with a minimum length of 2048 bits. Other key formats such as ED25519 and ECDSA are not supported. If you are unfamiliar with SSH then you should read this [article](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys) which will explain how to generate a key using the Windows Subsystem for Linux (it's easy and takes only a few minutes).  If you are new to SSH, remember SSH is a key pair solution. What this means is you have a public key and a private key, and the one you will be using to deploy your template is the public key.

## Predefined deployment options
Below are a list of pre-defined/restricted deployment options based on typical deployment scenarios (i.e. dev/test, production etc.) All configurations are fixed and you just need to pass your ssh public key to the template for logging in to the deployed VMs. Please note that the actual cost will be bigger with potentially autoscaled VMs, backups and network cost.

| Deployment Type | Description | Estimated Cost | Launch |
| --- | --- | --- | ---
| Minimal  | This deployment will use NFS, Microsoft SQL, and smaller autoscale web frontend VM sku (1 core) that'll give faster deployment time (less than 30 minutes) and requires only 2 VM cores currently that'll fit even in a free trial Azure subscription.|[link](https://azure.com/e/5f9752c934ab41799ae3264dd2ee57d1)|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-minimal.json)
| Small to Mid-Size | Supporting up to 1000 concurrent users.  This deployment will use NFS (no high availability) and MySQL (8 vCores), without other options like elastic search or redis cache.|[link](https://azure.com/e/fd794268d0bf421aa17c626fb88f25bc)|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-small2mid-noha.json)
|Large size deployment (with high availability)| Supporting more than 2000 concurrent users. This deployment will use Gluster (for high availability, requiring 2 VMs), MySQL (16 vCores) and redis cache, without other options like elastic search. |[link](https://azure.com/e/078f7294ab6544e8911ddc2ee28850d7)|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-large-ha.json)
| Maximum |This maximal deployment will use Gluster (for high availability, adding 2 VMs for a Gluster cluster), MySQL with highest SKU, redis cache, elastic search (3 VMs), and pretty large storage sizes (both data disks and DB).|[link](https://azure.com/e/e0f959b93ed84eb891dcc44f7883f5b5)|[![Deploy to Azure Maximally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-maximal.json)

NOTE: Depending on the region you choose to deploy the stack in - the deployment might fail due to SKUs being hardcoded in the template where they are not available. For example, today our small-mid-size deployment option hard codes Gen-4 Azure MySQL SKUs into the template, and if a region where that is currently not available in (i.e. westus2) is used, your deployment will fail.  If your deployment fails, please revert to the fully configurable template where possible and change the SKU paramater to one that exists in your region (i.e. Gen-5) or alternatively change your deployment region to one in which the SKU is available (i.e. southcentralus).     

For a comprehensive listing of all the components and attached services in the Moodle/LAMP cluster, please go through the documentation [here](../README.md)

## Next Steps

  1. [Prepare a Moodle cluster deployment to handle general LAMP applications](Generalize-To-Lamp.md)
  2. [Manage a Moodle/LAMP cluster on Azure](dManage.md)
  3. [Delete a Moodle/LAMP Cluster](Delete.md)

