#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# CEILOMETER

mongo --host controller --eval '
  db = db.getSiblingDB("ceilometer");
  db.createUser({user: "ceilometer",
  pwd: "CEILOMETER_DBPASS",
  roles: [ "readWrite", "dbAdmin" ]})'

source /home/vagrant/admin-openrc.sh

openstack user create --password CEILOMETER_PASS ceilometer
openstack role add --project service --user ceilometer admin
openstack service create --type metering \
  --description "Telemetry" ceilometer
openstack endpoint create \
  --publicurl http://controller:8777 \
  --internalurl http://controller:8777 \
  --adminurl http://controller:8777 \
  --region regionOne \
  metering

yum install -y openstack-ceilometer-api openstack-ceilometer-collector \
  openstack-ceilometer-notification openstack-ceilometer-central openstack-ceilometer-alarm \
  python-ceilometerclient

crudini --set /etc/ceilometer/ceilometer.conf database connection 'mongodb://ceilometer:CEILOMETER_DBPASS@controller:27017/ceilometer'

crudini --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend rabbit
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_host controller
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password RABBIT_PASS
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy keystone
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri  http://controller:5000/v2.0
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken identity_uri http://controller:35357
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password CEILOMETER_PASS
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri 'http://controller:5000'
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_url 'http://controller:35357'
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_plugin password
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_domain_id default
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken user_domain_id default
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_name service
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken username ceilometer
#crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken password CEILOMETER_PASS
crudini --set /etc/ceilometer/ceilometer.conf publisher telemetry_secret TELEMETRY_SECRET
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://controller:5000/v2.0
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name service
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_password CEILOMETER_PASS
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_endpoint_type internalURL
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_region_name regionOne
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT verbose True

systemctl enable openstack-ceilometer-api.service openstack-ceilometer-notification.service \
  openstack-ceilometer-central.service openstack-ceilometer-collector.service \
  openstack-ceilometer-alarm-evaluator.service openstack-ceilometer-alarm-notifier.service
systemctl start openstack-ceilometer-api.service openstack-ceilometer-notification.service \
  openstack-ceilometer-central.service openstack-ceilometer-collector.service \
  openstack-ceilometer-alarm-evaluator.service openstack-ceilometer-alarm-notifier.service

systemctl restart openstack-ceilometer-api.service openstack-ceilometer-notification.service \
  openstack-ceilometer-central.service openstack-ceilometer-collector.service \
  openstack-ceilometer-alarm-evaluator.service openstack-ceilometer-alarm-notifier.service

###################################################################################################
###################################################################################################
# GLANCE

crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver messagingv2
crudini --set /etc/glance/glance-api.conf DEFAULT rpc_backend rabbit
crudini --set /etc/glance/glance-api.conf DEFAULT rabbit_host controller
crudini --set /etc/glance/glance-api.conf DEFAULT rabbit_userid openstack
crudini --set /etc/glance/glance-api.conf DEFAULT rabbit_password RABBIT_PASS

systemctl restart openstack-glance-api.service openstack-glance-registry.service

###################################################################################################
###################################################################################################
# CINDER

crudini --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
crudini --set /etc/cinder/cinder.conf DEFAULT notification_driver messagingv2

systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service

### RUN STEPS (block_ceilometer.sh) ON BLOCK1
ssh root@block1 "/vagrant/scripts/block_ceilometer.sh"

###################################################################################################
###################################################################################################
# NOVA

### RUN STEPS (compute_ceilometer.sh) ON COMPUTE1
ssh root@compute1 "/vagrant/scripts/compute_ceilometer.sh"

###################################################################################################
###################################################################################################
# SWIFT

source /home/vagrant/admin-openrc.sh
openstack role create ResellerAdmin
openstack role add --project service --user ceilometer ResellerAdmin

crudini --set /etc/swift/proxy-server.conf filter:keystoneauth operator_roles admin,_member_,ResellerAdmin
crudini --set /etc/swift/proxy-server.conf pipeline:main pipeline "authtoken cache healthcheck keystoneauth proxy-logging ceilometer proxy-server"
crudini --set /etc/swift/proxy-server.conf filter:ceilometer paste.filter_factory ceilometermiddleware.swift:filter_factory
crudini --set /etc/swift/proxy-server.conf filter:ceilometer control_exchange swift
crudini --set /etc/swift/proxy-server.conf filter:ceilometer url rabbit://openstack:RABBIT_PASS@controller:5672/
crudini --set /etc/swift/proxy-server.conf filter:ceilometer driver messagingv2
crudini --set /etc/swift/proxy-server.conf filter:ceilometer topic notifications
crudini --set /etc/swift/proxy-server.conf filter:ceilometer log_level = WARN

usermod -a -G ceilometer swift

pip install ceilometermiddleware

systemctl restart openstack-swift-proxy.service
