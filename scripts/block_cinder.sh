#!/bin/sh

set -x

/vagrant/scripts/prepare_node.sh

###################################################################################################
###################################################################################################
# CINDER

yum install -y lvm2
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

yum install -y openstack-cinder targetcli python-oslo-db python-oslo-log MySQL-python

# !!! WORKAROUND !!!
cp /usr/share/cinder/cinder-dist.conf /etc/cinder/cinder.conf
chown -R cinder:cinder /etc/cinder/cinder.conf

crudini --set /etc/cinder/cinder.conf database connection 'mysql://cinder:CINDER_DBPASS@controller/cinder'
crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host controller
crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password RABBIT_PASS
crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri 'http://controller:5000'
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_url 'http://controller:35357'
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_domain_id default
crudini --set /etc/cinder/cinder.conf keystone_authtoken user_domain_id default
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_name service
crudini --set /etc/cinder/cinder.conf keystone_authtoken username cinder
crudini --set /etc/cinder/cinder.conf keystone_authtoken password CINDER_PASS
crudini --del /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name
crudini --del /etc/cinder/cinder.conf keystone_authtoken admin_user
crudini --del /etc/cinder/cinder.conf keystone_authtoken admin_password
crudini --del /etc/cinder/cinder.conf keystone_authtoken auth_host
crudini --del /etc/cinder/cinder.conf keystone_authtoken auth_port
crudini --del /etc/cinder/cinder.conf keystone_authtoken auth_protocol
crudini --set /etc/cinder/cinder.conf DEFAULT my_ip 10.0.0.41
crudini --set /etc/cinder/cinder.conf DEFAULT verbose True
crudini --set /etc/cinder/cinder.conf DEFAULT oslo_concurrency lock_path /var/lock/cinder
crudini --set /etc/cinder/cinder.conf DEFAULT glance_host controller
crudini --set /etc/cinder/cinder.conf DEFAULT iscsi_helper lioadm
crudini --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
crudini --set /etc/cinder/cinder.conf DEFAULT iscsi_protocol iscsi

systemctl enable openstack-cinder-volume.service target.service
systemctl start openstack-cinder-volume.service target.service
