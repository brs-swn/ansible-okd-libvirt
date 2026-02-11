Role Name
=========

This configures a basic KVM hypervisor with LibVirt and routed bridged network

Requirements
------------

This Role is customized for Fedora Linux 41 or higher. Other distributions
can be used, but updates to packaging and paths would have to be changed.
This assumes that a basic OS is installed with the proper partitions to 
accommodate the minimum storage. Hosts file, user accounts and NTP are also 
assumed to be configured.

Role Variables
--------------

See the default variable list for variables that can be overriden in the inventory group vars.

Dependencies
------------

 - The hypervisor should have been deployed using the KVM kickstart file
   included with ansible-okd-services.
 - An ansible user with SSH keys must already be configured on the target host.
 - It is advisable to to configure NTP.
 - No other Galaxy roles should be necessary to use this role.

Example Playbook
----------------

The play book should be defined as follows:

    - hosts: okd_libvirt
      become: yes
      become_user: root
      roles:
        - ansible-okd-libvirt

To execute the playbook use the following syntax:

    export ANSIBLE_CONFIG=ansible.cfg

    ansible-playbook \
     --private-key ~/.ssh/okd_rsa \
     -u fedora \
     -i ../inventory/hosts \
     server-configure-kvm.yml

License
-------

GPL-2.0-or-later

Author Information
------------------

Brent R. Scott <brs.scottworks@gmail.com>
