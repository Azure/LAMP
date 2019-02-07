# Environment Variables

In order to configure our deployment and tools we'll set up some environment variables to ensure consistency. If you are running these scripts through SimDem you can customize these values by copying and editing `env.json` into `env.local.json`.

We'll need a unique name for our Resource Group in Azure, but when running in an automated mode it is useful to have a (mostly) unique name for your deployment and related resources. We'll use a timestamp. If the environmnt variable `LAMP_RG_NAME` is not set we will create a new value using a timestamp:

```sh
if [ -z "$LAMP_RG_NAME" ]; then LAMP_RG_NAME=lamp_$(date +%Y-%m-%d-%H); fi
```

Other configurable values for our Azure deployment include the location and depoloyment name. We'll standardize these, but you can use different values if you like.

```sh
LAMP_RG_LOCATION=southcentralus
LAMP_DEPLOYMENT_NAME=MasterDeploy
```

We also need to provide an SSH key. Later, we'll generate this if it doesn't already exist but to enable us to reuse an existing key we'll store it's filename in an Environment Variable.

```sh
LAMP_SSH_KEY_FILENAME=~/.ssh/lamp_id_rsa
```

We need a workspace for storing configuration files and other
per-deployment artifacts:

```sh
LAMP_AZURE_WORKSPACE=~/azure-lamp
```

## Create Workspace

Ensure the workspace for this particular deployment exists:

```sh
mkdir -p $LAMP_AZURE_WORKSPACE/$LAMP_RG_NAME
```

## Validation

After working through this file there should be a number of environment variables defined that will be used to provide a common setup for all our LAMP on Azure work.

The resource group name defines the name of the group into which all resources will be, or are, deployed.

```sh
echo "Resource Group for deployment: $LAMP_RG_NAME"
```

Results:

```text
Resource Group for deployment: southcentralus
```

The resource group location is:

```sh
echo "Deployment location: $LAMP_RG_LOCATION"
```

Results:

```text
Deployment location: southcentralus
```

When deploying a LAMP cluster the deployment will be given a name so that it can be identified later should it be neceessary to debug.

```sh
echo "Deployment name: $LAMP_DEPLOYMENT_NAME"
```

Results:

```text
Deployment name: MasterDeploy
```

The SSH key to use can be found in a file, if necessary this will be created as part of these scripts.

```sh
echo "SSH key filename: $LAMP_SSH_KEY_FILENAME"
```

Results:

```text
SSH key filename: ~/.ssh/lamp_id_rsa
```

Configuration files will be written to / read from a customer directory:

```sh
echo "Workspace directory: $LAMP_AZURE_WORKSPACE"
```

Results:

```text
Workspace directory: ~/azure-lamp
```

Ensure the workspace directory exists:

```sh
if [ ! -f "$LAMP_AZURE_WORKSPACE/$LAMP_RG_NAME" ]; then echo "Workspace exists"; fi
```

Results:

```text
Workspace exists
```
