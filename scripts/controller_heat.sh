#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# NOVA

cat <<EOT | mysql -u root -pROOT_DB_PASS
CREATE DATABASE heat;
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' \
  IDENTIFIED BY 'HEAT_DBPASS';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' \
  IDENTIFIED BY 'HEAT_DBPASS';
EOT

source /home/vagrant/admin-openrc.sh

openstack user create --password HEAT_PASS heat
openstack role add --project service --user heat admin
openstack role create heat_stack_owner
openstack role add --project demo --user demo heat_stack_owner
openstack role create heat_stack_user
openstack service create --type orchestration \
  --description "Orchestration" heat
openstack service create --type cloudformation \
  --description "Orchestration" heat-cfn
openstack endpoint create \
  --publicurl http://controller:8004/v1/%\(tenant_id\)s \
  --internalurl http://controller:8004/v1/%\(tenant_id\)s \
  --adminurl http://controller:8004/v1/%\(tenant_id\)s \
  --region regionOne \
  orchestration
openstack endpoint create \
  --publicurl http://controller:8000/v1 \
  --internalurl http://controller:8000/v1 \
  --adminurl http://controller:8000/v1 \
  --region regionOne \
  cloudformation

yum install -y openstack-heat-api openstack-heat-api-cfn openstack-heat-engine \
  python-heatclient

# !!! WORKAROUND !!!
cp /usr/share/heat/heat-dist.conf /etc/heat/heat.conf
chown -R heat:heat /etc/heat/heat.conf

crudini --set /etc/heat/heat.conf database connection 'mysql://heat:HEAT_DBPASS@controller/heat'
crudini --set /etc/heat/heat.conf DEFAULT rpc_backend rabbit
crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_host controller
crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_password RABBIT_PASS
crudini --set /etc/heat/heat.conf DEFAULT auth_strategy keystone
crudini --set /etc/heat/heat.conf keystone_authtoken auth_uri 'http://controller:5000'
crudini --set /etc/heat/heat.conf keystone_authtoken auth_url 'http://controller:35357'
crudini --set /etc/heat/heat.conf keystone_authtoken auth_plugin password
crudini --set /etc/heat/heat.conf keystone_authtoken project_domain_id default
crudini --set /etc/heat/heat.conf keystone_authtoken user_domain_id default
crudini --set /etc/heat/heat.conf keystone_authtoken project_name service
crudini --set /etc/heat/heat.conf keystone_authtoken username heat
crudini --set /etc/heat/heat.conf keystone_authtoken password CINDER_PASS
crudini --del /etc/heat/heat.conf keystone_authtoken admin_tenant_name
crudini --del /etc/heat/heat.conf keystone_authtoken admin_user
crudini --del /etc/heat/heat.conf keystone_authtoken admin_password
crudini --del /etc/heat/heat.conf keystone_authtoken auth_host
crudini --del /etc/heat/heat.conf keystone_authtoken auth_port
crudini --del /etc/heat/heat.conf keystone_authtoken auth_protocol
crudini --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://controller:8000
crudini --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://controller:8000/v1/waitcondition
crudini --set /etc/heat/heat.conf DEFAULT stack_domain_admin heat_domain_admin
crudini --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password HEAT_DOMAIN_PASS
crudini --set /etc/heat/heat.conf DEFAULT stack_user_domain_name heat_user_domain
crudini --set /etc/heat/heat.conf DEFAULT verbose True

source /home/vagrant/admin-openrc.sh

heat-keystone-setup-domain \
  --stack-user-domain-name heat_user_domain \
  --stack-domain-admin heat_domain_admin \
  --stack-domain-admin-password HEAT_DOMAIN_PASS

systemctl enable openstack-heat-api.service openstack-heat-api-cfn.service \
  openstack-heat-engine.service
systemctl start openstack-heat-api.service openstack-heat-api-cfn.service \
  openstack-heat-engine.service
