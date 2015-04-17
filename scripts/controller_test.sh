#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# KEYSTONE

source /home/vagrant/admin-openrc.sh
openstack token issue

###################################################################################################
###################################################################################################
# GLANCE

source /home/vagrant/admin-openrc.sh
mkdir /tmp/images
wget -P /tmp/images http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
glance image-create --name "cirros-0.3.3-x86_64" --file /tmp/images/cirros-0.3.3-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --visibility public --progress
glance image-list
rm -rf /tmp/images

###################################################################################################
###################################################################################################
# NOVA

source /home/vagrant/admin-openrc.sh
nova service-list
nova endpoints
nova image-list

###################################################################################################
###################################################################################################
# NEUTRON

source /home/vagrant/admin-openrc.sh
neutron agent-list

neutron net-create ext-net --router:external \
  --provider:physical_network external --provider:network_type flat
neutron subnet-create ext-net 203.0.113.0/24 --name ext-subnet \
  --allocation-pool start=203.0.113.101,end=203.0.113.200 \
  --disable-dhcp --gateway 203.0.113.1

source /home/vagrant/demo-openrc.sh

neutron net-create demo-net
neutron subnet-create demo-net 192.168.1.0/24 \
  --name demo-subnet --gateway 192.168.1.1

neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net

###################################################################################################
###################################################################################################
# CINDER

source /home/vagrant/admin-openrc.sh
cinder service-list

source /home/vagrant/demo-openrc.sh
cinder create --display-name demo-volume1 1
cinder list

###################################################################################################
###################################################################################################
# SWIFT

source /home/vagrant/demo-openrc.sh
swift --auth-version 3 stat
dd if=/dev/urandom of=/tmp/swift bs=1M count=1
swift --auth-version 3 upload demo-container1 /tmp/swift
swift --auth-version 3 list
swift --auth-version 3 download demo-container1 tmp/swift
rm /tmp/swift
rm tmp

###################################################################################################
###################################################################################################
# CEIOMETER

source /home/vagrant/admin-openrc.sh

ceilometer meter-list
glance image-download "cirros-0.3.3-x86_64" > /tmp/cirros.img
ceilometer meter-list
ceilometer statistics -m image.download -p 60
rm /tmp/cirros.img
