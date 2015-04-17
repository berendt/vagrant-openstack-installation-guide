#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# GLANCE

cat <<EOT | mysql -u root -pROOT_DB_PASS
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
  IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
  IDENTIFIED BY 'GLANCE_DBPASS';
EOT

echo "export OS_IMAGE_API_VERSION=2" | tee -a /home/vagrant/admin-openrc.sh /home/vagrant/demo-openrc.sh
source /home/vagrant/admin-openrc.sh

openstack user create --password GLANCE_PASS glance
openstack role add --project service --user glance admin
openstack service create --name glance \
  --description "OpenStack Image service" image
openstack endpoint create \
  --publicurl http://controller:9292 \
  --internalurl http://controller:9292 \
  --adminurl http://controller:9292 \
  --region regionOne \
  image

yum install -y openstack-glance-api openstack-glance-registry openstack-glance python-glanceclient

# NOTE(berendt): !!! This is a workaround !!!
yum install -y python-glance

crudini --set /etc/glance/glance-api.conf database connection 'mysql://glance:GLANCE_DBPASS@controller/glance'
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri 'http://controller:5000'
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url h'ttp://controller:35357'
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_plugin password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_id default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_id default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password GLANCE_PASS
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir '/var/lib/glance/images/'
crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver noop
crudini --set /etc/glance/glance-api.conf DEFAULT verbose True

crudini --set /etc/glance/glance-registry.conf database connection 'mysql://glance:GLANCE_DBPASS@controller/glance'
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri 'http://controller:5000'
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url h'ttp://controller:35357'
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_plugin password
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_id default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_id default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken password GLANCE_PASS
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop
crudini --set /etc/glance/glance-api.conf DEFAULT verbose True

su -s /bin/sh -c "glance-manage db_sync" glance

systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
