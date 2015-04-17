#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# CINDER

cat <<EOT | mysql -u root -pROOT_DB_PASS
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' \
  IDENTIFIED BY 'CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' \
  IDENTIFIED BY 'CINDER_DBPASS';
EOT

echo "export OS_VOLUME_API_VERSION=2" | tee -a /home/vagrant/admin-openrc.sh /home/vagrant/demo-openrc.sh
source /home/vagrant/admin-openrc.sh

openstack user create --password CINDER_PASS cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder \
  --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 \
  --description "OpenStack Block Storage" volumev2
openstack endpoint create \
  --publicurl http://controller:8776/v2/%\(tenant_id\)s \
  --internalurl http://controller:8776/v2/%\(tenant_id\)s \
  --adminurl http://controller:8776/v2/%\(tenant_id\)s \
  --region regionOne \
  volume
openstack endpoint create \
  --publicurl http://controller:8776/v2/%\(tenant_id\)s \
  --internalurl http://controller:8776/v2/%\(tenant_id\)s \
  --adminurl http://controller:8776/v2/%\(tenant_id\)s \
  --region regionOne \
  volumev2

yum install -y openstack-cinder python-cinderclient python-oslo-db python-oslo-log

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
crudini --set /etc/cinder/cinder.conf DEFAULT my_ip 10.0.0.11
crudini --set /etc/cinder/cinder.conf DEFAULT verbose True
crudini --set /etc/cinder/cinder.conf DEFAULT oslo_concurrency lock_path /var/lock/cinder

su -s /bin/sh -c "cinder-manage db sync" cinder

systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service

### RUN STEPS (block.sh) ON BLOCK1
ssh root@block1 "/vagrant/scripts/block_cinder.sh"
