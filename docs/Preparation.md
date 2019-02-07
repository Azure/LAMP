# Environment Preparation

This document describes how to ensure your local environment (ie. your laptop) is configured for working with LAMP  on Azure.

## Prerequisites

In order to configure our deployment and tools we'll set up some [environment variables](./Environment-Variables.md) to ensure consistency.

## Required software

We'll use a number of tools when working with this template. Let's
ensure they are all installed.

### Linux (Ubuntu) and Windows Subsystem for Linux

> If you're using Windows 10, we recommend you use the Windows Subsystem for Linux to have a full bash shell experience, based on Ubuntu. See the [documentation](https://docs.microsoft.com/en-us/windows/wsl/install-win10) on how to enable the Windows Subsystem for Linux.

On the terminal in Ubuntu and WSL:

```sh
sudo apt-get update
sudo apt-get install wget -y
sudo apt-get openssh-client -y
```

The [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest) is also important:

```sh
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo apt-get update && sudo apt-get install apt-transport-https azure-cli
```

### macOS

On macOS, most dependencies are already pre-installed in the system by default.

You can install the Azure CLI with Homebrew. Please follow the instructions in the [documentation](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-macos?view=azure-cli-latest).

## Ensure we have a valid SSH key pair

We use SSH for secure communication with our hosts. The following line
will check there is a valid SSH key available and, if not, create one.

```sh
if [ ! -f "$LAMP_SSH_KEY_FILENAME" ]; then ssh-keygen -t rsa -b 4096 -N "" -f $LAMP_SSH_KEY_FILENAME; fi
```

### Note on SSH keys

All of the deployment options require you to provide a valid SSH protocol 2 (SSH-2) RSA public-private key pair, with a minimum length of 2048 bits. Other key formats such as ED25519 and ECDSA are not supported. If you are unfamiliar with SSH then you should read this [article](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys) which will explain how to generate a key using the Windows Subsystem for Linux, or a Mac or Linux laptop (it's easy and takes only a few minutes). If you are new to SSH, remember SSH is a key pair-based solution. What this means is that you have a public key and a private key, and the one you will be using to deploy your template is the public key.

## Checkout the LAMP ARM Template

The LAMP Azure Resource Manager template is hosted on GitHub. We'll
checkout the template into our workspace.

```sh
git clone git@github.com:Azure/LAMP.git $LAMP_AZURE_WORKSPACE/arm_template
```

## Validation

After completing these steps we should have, among other things, a complete checkout of the LAMP templates from GitHub:

```sh
ls $LAMP_AZURE_WORKSPACE/arm_template
```

Results:

```expected_similarity=0.4
azuredeploy.json  azuredeploy.parameters.json  CONTRIBUTE.md  docs  env.json  etc  images  LICENSE  LICENSE-DOCS  metadata.json  nested
README.md
```

We should also have a number of applications installed, such as the Azure CLI:

```sh
if hash az 2>/dev/null; then echo "Azure CLI Installed"; else echo "Missing dependency: Azure CLI"; fi
```

```text
AzureCLI Installed
```
