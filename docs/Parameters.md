# LAMP on Azure Parameters

Our goal with these templates is to make it as easy as possible to deploy a LAMP on Azure cluster that can be customized to your specific needs. To that end we provide a great manay configuration options. This document attempts to document all these parameters, however, like all documentation it can sometimes fall behind. For a canonical reference you should review the `azuredeploy.json` file.

## Extracting documentation from azuredeploy.json

To make it a litte easier to read `azuredeploy.json` you might want to run the following commands which will extract the necessary information and display it in a more readable form.

```sh
sudp apt install jq
```

```sh
jq -r '.parameters | to_entries[] | "### " + .key + "\n\n" + .value.metadata.description + "\n\nType: " + .value.type + "\n\nPossible Values: " + (.value.allowedValues | @text) + "\n\nDefault: " + (.value.defaultValue | @text) + "\n"' azuredeploy.json
```

## Available Parameters

### _artifactsLocation

The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.

Type: string

Possible Values: null

Default: https://raw.githubusercontent.com/Azure/LAMP/master/

### _artifactsLocationSasToken

The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.

Type: securestring

Possible Values: null

Default:

### applyScriptsSwitch

Switch to process or bypass all scripts/extensions

Type: bool

Possible Values: null

Default: true

### azureBackupSwitch

Switch to configure AzureBackup and enlist VM's

Type: bool

Possible Values: null

Default: false

### redisDeploySwitch

Switch to deploy a Redis Cache or not.

Type: bool

Possible Values: null

Default: false

### vnetGwDeploySwitch

Switch to deploy a virtual network gateway or not

Type: bool

Possible Values: null

Default: false

### htmlLocalCopySwitch

Switch to create a local copy of /azlamp/html or not

Type: bool

Possible Values: null

Default: true

### ddosSwitch

Switch to create a DDoS protection plan

Type: bool

Possible Values: null

Default: false

### enableAccelNwForCtlrVmSwitch

Switch to enable Azure Accelerated Networking on the controller VM. Default to false because currently the default controller VM SKU (D1) doesn't support AN. Change this to true if you set the controller VM SKU to eligibible ones (e.g., D2) for better performance.

Type: bool

Possible Values: null

Default: false

### enableAccelNwForOtherVmsSwitch

Switch to enable Azure Accelerated Networking on all other VMs. Default to true because currently the default controller VM SKU for all other VMS (D2) does support AN. Change this to false if you set the SKU of any other VMs to an ineligibible one (e.g., D1) to avoid deployment failure.

Type: bool

Possible Values: null

Default: true

### httpsTermination

Indicates where https termination occurs. 'VMSS' is for https termination at the VMSS instance VMs (using nginx https proxy). 'AppGw' is for https termination with an Azure Application Gateway. When selecting this, you need to specify all appGw* parameters. 'None' is for testing only with no https. 'None' may not be used with a separately configured https termination layer.

Type: string

Possible Values: ["VMSS","AppGw","None"]

Default: VMSS

### siteURL

URL for LAMP site

Type: string

Possible Values: null

Default: www.example.org

### sshPublicKey

ssh public key

Type: string

Possible Values: null

Default: null

### sshUsername

ssh user name

Type: string

Possible Values: null

Default: azureadmin

### controllerVmSku

VM size for the controller VM

Type: string

Possible Values: null

Default: Standard_DS1_v2

### autoscaleVmSku

VM size for autoscaled web VMs

Type: string

Possible Values: null

Default: Standard_DS2_v2

### autoscaleVmCountMax

Maximum number of autoscaled web VMs

Type: int

Possible Values: null

Default: 10

### autoscaleVmCountMin

Minimum (also initial) number of autoscaled web VMs

Type: int

Possible Values: null

Default: 1

### osDiskStorageType

Azure storage type for all VMs' OS disks. With htmlLocalCopySwith true, Premium_LRS (SSD) is strongly recommended, as PHP files will be served from OS disks.

Type: string

Possible Values: ["Premium_LRS","Standard_LRS"]

Default: Premium_LRS

### dbServerType

Database type

Type: string

Possible Values: ["postgres","mysql","mssql"]

Default: mysql

### dbLogin

Database admin username

Type: string

Possible Values: null

Default: dbadmin

### mysqlPgresVcores

MySql/Postgresql vCores. For Basic tier, only 1 & 2 are allowed. For GeneralPurpose tier, 2, 4, 8, 16, 32 are allowed. For MemoryOptimized, 2, 4, 8, 16 are allowed.

Type: int

Possible Values: [1,2,4,8,16,32]

Default: 2

### mysqlPgresStgSizeGB

MySql/Postgresql storage size in GB. Minimum 5GB, increase by 1GB, up to 1TB (1024 GB)

Type: int

Possible Values: null

Default: 125

### mysqlPgresSkuTier

MySql/Postgresql sku tier

Type: string

Possible Values: ["Basic","GeneralPurpose","MemoryOptimized"]

Default: GeneralPurpose

### mysqlPgresSkuHwFamily

MySql/Postgresql sku hardware family. Central US is Gen4 only, so make sure to change this parameter to Gen4 if your deployment is on Central US.

Type: string

Possible Values: ["Gen4","Gen5"]

Default: Gen5

### mysqlVersion

Mysql version

Type: string

Possible Values: ["5.6","5.7"]

Default: 5.7

### postgresVersion

Postgresql version

Type: string

Possible Values: ["9.5","9.6"]

Default: 9.6

### sslEnforcement

MySql/Postgresql SSL connection

Type: string

Possible Values: ["Disabled","Enabled"]

Default: Disabled

### mssqlDbServiceObjectiveName

MS SQL database service object names

Type: string

Possible Values: ["S1","S2","S3","S4","S5","S6","S7","S9"]

Default: S1

### mssqlDbSize

MS SQL database size

Type: string

Possible Values: ["100MB","250MB","500MB","1GB","2GB","5GB","10GB","20GB","30GB","40GB","50GB","100GB","250GB","300GB","400GB","500GB","750GB","1024GB"]

Default: 250GB

### mssqlDbEdition

MS SQL DB edition

Type: string

Possible Values: ["Basic","Standard"]

Default: Standard

### mssqlVersion

Mssql version

Type: string

Possible Values: ["12.0"]

Default: 12.0

### fileServerType

File server type: GlusterFS, NFS, and NFS-HA (2-VM highly available NFS cluster)

Type: string

Possible Values: ["gluster","nfs","nfs-ha","nfs-byo"]

Default: nfs

### nfsByoIpExportPath

IP address and export path of the BYO-NFS share when fileServerType == nfs-byo. E.g., 172.16.1.8:/msazure

Type: string

Possible Values: null

Default:

### fileServerDiskSize

Size per disk for gluster nodes or nfs server

Type: int

Possible Values: null

Default: 127

### fileServerDiskCount

Number of disks in raid0 per gluster node or nfs server

Type: int

Possible Values: null

Default: 4

### fileServerVmSku

VM size for the gluster or NFS-HA nodes

Type: string

Possible Values: null

Default: Standard_DS2_v2

### keyVaultResourceId

(VMSS https termination only) Azure Resource Manager resource ID of the Key Vault in case you stored your SSL cert in an Azure Key Vault (Note that this Key Vault must have been pre-created on the same Azure region where this template is being deployed). Leave this blank if you didn't. Resource ID example: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/xxx/providers/Microsoft.KeyVault/vaults/yyy. This value can be obtained from keyvault.sh output if you used the script to store your SSL cert in your Key Vault.

Type: string

Possible Values: null

Default:

### sslCertKeyVaultURL

(VMSS https termination only) Azure Key Vault URL for your stored SSL cert. This value can be obtained from keyvault.sh output if you used the script to store your SSL cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default:

### sslCertThumbprint

(VMSS https termination only) Thumbprint of your stored SSL cert. This value can be obtained from keyvault.sh output if you used the script to store your SSL cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default:

### caCertKeyVaultURL

(VMSS https termination only) Azure Key Vault URL for your stored CA (Certificate Authority) cert. This value can be obtained from keyvault.sh output if you used the script to store your CA cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default:

### caCertThumbprint

(VMSS https termination only) Thumbprint of your stored CA cert. This value can be obtained from keyvault.sh output if you used the script to store your CA cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default:

### appGwSslCertKeyVaultResourceId

(App Gateway https termination only) Azure Key Vault URL for your stored SSL cert, again for App Gateway https termination case only. (Note that this Key Vault must have been pre-created on the same Azure region where this template is being deployed). Leave this blank if you didn't. Resource ID example: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/xxx/providers/Microsoft.KeyVault/vaults/yyy.

Type: string

Possible Values: null

Default:

### appGwSslCertKeyVaultSecretName

(App Gateway https termination only) Name of the Azure Key Vault secret that's stored in the previously specified Key Vault as a PFX certificate (with no password) for your site's SSL cert. This secret must be pre-populated in the specified Key Vault with the matching name.

Type: string

Possible Values: null

Default:

### appGwSkuName

(App Gateway https termination only) Name of the Applicate Gateway SKU

Type: string

Possible Values: ["Standard_Small","Standard_Medium","Standard_Large","WAF_Medium","WAF_Large"]

Default: Standard_Medium

### appGwSkuTier

(App Gateway https termination only) Tier of the Applicate Gateway

Type: string

Possible Values: ["Standard","WAF"]

Default: Standard

### appGwSkuCapacity

(App Gateway https termination only) Capacity instance count) of the Applicate Gateway

Type: int

Possible Values: null

Default: 2

### storageAccountType

Storage Account type. This storage account is only for the (currently disabled) Azure Files file share option

Type: string

Possible Values: ["Standard_LRS","Standard_GRS","Standard_ZRS"]

Default: Standard_LRS

### customVnetId

Azure Resource ID of the Azure virtual network where you want to deploy your LAMP resources. A vnet resource ID is of the following format: /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxxxx/resourceGroups/gggg/providers/Microsoft.Network/virtualNetworks/vvvv. Note that this virtual network must be on the same Azure location as this template deployment location. If this parameter is blank, a new Azure virtual network will be created and used. In that case, the address space of the newly created virtual network will be */16 of the following vNetAddressSpace parameter value below.

Type: string

Possible Values: null

Default:

### vNetAddressSpace

Address range for the LAMP virtual network and various subnets - presumed /16 for a newly created vnet in case customVnetId is blank. Further subneting (a number of */24 subnets starting from the xxx.yyy.zzz.0/24 will be created on a newly created vnet or your BYO-vnet (specified in customVnetId parameter).

Type: string

Possible Values: null

Default: 172.31.0.0

### gatewayType

Virtual network gateway type

Type: string

Possible Values: ["Vpn","ER"]

Default: Vpn

### vpnType

Virtual network gateway vpn type

Type: string

Possible Values: ["RouteBased","PolicyBased"]

Default: RouteBased

### loadBalancerSku

Loadbalancer SKU

Type: string

Possible Values: ["Basic","Standard"]

Default: Basic

### location

Azure Location for all resources.

Type: string

Possible Values: null

Default: [resourceGroup().location]
