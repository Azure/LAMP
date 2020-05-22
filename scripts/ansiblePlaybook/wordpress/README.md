# wordpress_playbook
Playbook Name
--------------

WordPress playbook

Requirements
------------

WordPress requires the following prerequisites. 
NGINX server, MySQL and PHP.

Role Variables
--------------

This playbook has three roles. One is for wordpress installation and other is for WooCommerce plugin installation and last role is for Replicating the entire WordPress folder to VMSS of the host VM. 

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: webservers
      roles:
         - { role: .rolename, x: 42 }


Author Information
------------------

This entire ansible playbook repository is created by iTalent Digital pvt ltd.
