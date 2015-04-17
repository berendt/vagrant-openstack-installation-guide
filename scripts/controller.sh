#!/bin/sh

set -x

/vagrant/scripts/prepare_controller.sh
/vagrant/scripts/controller_mariadb.sh
/vagrant/scripts/controller_rabbitmq.sh
/vagrant/scripts/controller_keystone.sh
/vagrant/scripts/controller_glance.sh
/vagrant/scripts/controller_nova.sh
/vagrant/scripts/controller_neutron.sh
/vagrant/scripts/controller_horizon.sh
/vagrant/scripts/controller_cinder.sh
/vagrant/scripts/controller_swift.sh
/vagrant/scripts/controller_heat.sh
/vagrant/scripts/controller_mongodb.sh
/vagrant/scripts/controller_ceilometer.sh
#/vagrant/scripts/controller_test.sh
