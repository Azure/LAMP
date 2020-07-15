# Installing WordPress with WooCommerce on a LAMP Cluster in Microsoft Azure

## One Click Deploy of WordPress with WooCommerce Plug-in on top of LAMP
This document explains how to install WordPress with the WooCommerce plugin on a LAMP cluster in Azure. The following diagram shows how the required system components participate in the installation process.

![Workflow](https://github.com/Azure/LAMP/blob/master/images/One_Click_WP.png)

## Supported Software Configuration
- To support the current installation, the LAMP stack must be running with the below software versions.
	*	Ubuntu 16.04 LTS
	*	Nginx web server 1.10.3
	*	MySQL PaaS 5.6, 5.7 or 8.0 database server
	*	PHP 7.2, 7.3, or 7.4 
    *   WordPress 5.4, 5.4.1, 5.4.2

## Overview of the Installation Process
- The installation process consists of the following high-level procedures:
	*	Deploy the LAMP Stack
	*	Install WordPress with WooCommerce on the Controller VM

- Once predefined template has been choosen user will be redirected to the Azure Custom deployment.

- By default CMS Application field will be "WordPress", however if user wants to deploy LAMP only please select None in the dropdown list.

- When user selects WordPress, template will deploy the WordPress with 5.4.2 version and also deploys the latest WooCommerce plug-in on top of WordPress.

- In custom deployment user will have an option to choose WordPress versions mentioned above.

## Overview of the Installation Process

Script will check the CMS Application type and install WordPress.

* Creates a Database for CMS Application (WordPress) on MySQL Server.
* Download the WordPress compressed tar file with the selected version.
* Creates a WordPress configuration file.
* Linking data folder to shared data folder.
* Download and installs the WP-CLI tool.
* Installation of WordPress by using WP-CLI tool.
* Download and Install WooCommerce Plugin.
* Generate Open SSL certificates.
* Generate a text file with WordPress site details.
