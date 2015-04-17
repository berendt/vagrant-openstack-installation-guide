#!/bin/sh

set -x

/vagrant/scripts/prepare_node.sh

###################################################################################################
###################################################################################################
# NOVA

yum install -y openstack-nova-compute sysfsutils

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host controller
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password RABBIT_PASS
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri 'http://controller:5000'
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url 'http://controller:35357'
crudini --set /etc/nova/nova.conf keystone_authtoken auth_plugin password
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_id default
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_id default
crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
crudini --set /etc/nova/nova.conf keystone_authtoken username nova
crudini --set /etc/nova/nova.conf keystone_authtoken password NOVA_PASS
crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.0.0.31
crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled True
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 10.0.0.31
crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url 'http://controller:6080/vnc_auto.html'
crudini --set /etc/nova/nova.conf glance host controller
crudini --set /etc/nova/nova.conf DEFAULT verbose True
crudini --set /etc/nova/nova.conf DEFAULT oslo_concurrency lock_path /var/lock/nova

egrep -c '(vmx|svm)' /proc/cpuinfo

crudini --set /etc/nova/nova.conf libvirt virt_type qemu

systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
