#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# NOVA

cat <<EOT | mysql -u root -pROOT_DB_PASS
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY 'NOVA_DBPASS';
EOT

source /home/vagrant/admin-openrc.sh

openstack user create --password NOVA_PASS nova
openstack role add --project service --user nova admin
openstack service create --name nova \
  --description "OpenStack Compute" compute
openstack endpoint create \
  --publicurl http://controller:8774/v2/%\(tenant_id\)s \
  --internalurl 'http://controller:8774/v2/%(tenant_id)s' \
  --adminurl 'http://controller:8774/v2/%(tenant_id)s' \
  --region regionOne \
  compute

yum install -y openstack-nova-api openstack-nova-cert openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
  python-novaclient

crudini --set /etc/nova/nova.conf database connection 'mysql://nova:NOVA_DBPASS@controller/nova'
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
crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.0.0.11
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 10.0.0.11
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 10.0.0.11
crudini --set /etc/nova/nova.conf glance host controller
crudini --set /etc/nova/nova.conf DEFAULT verbose True
crudini --set /etc/nova/nova.conf DEFAULT oslo_concurrency lock_path /var/lock/nova

su -s /bin/sh -c "nova-manage db sync" nova

systemctl enable openstack-nova-api.service openstack-nova-cert.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-cert.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service

### RUN STEPS (compute_nova.sh) ON COMPUTE1
ssh root@compute1 "/vagrant/scripts/compute_nova.sh"
