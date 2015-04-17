#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# CEILOMETER

crudini --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
crudini --set /etc/cinder/cinder.conf DEFAULT notification_driver messagingv2

systemctl restart openstack-cinder-volume.service
