#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# HORIZON

yum install -y openstack-dashboard httpd mod_wsgi memcached python-memcached

sed -i -e "s/^OPENSTACK_HOST =.*$/OPENSTACK_HOST = 'controller'/" /etc/openstack-dashboard/local_settings
sed -i -e "s/^ALLOWED_HOSTS.*$/ALLOWED_HOSTS = \['\*'\]/" /etc/openstack-dashboard/local_settings
sed -i -e "s/^.*'BACKEND': 'django\.core\.cache\.backends\.locmem\.LocMemCache',$/'        BACKEND': 'django\.core\.cache\.backends\.memcached\.MemcachedCache',\n        'LOCATION': '127\.0\.0\.1:11211',/" /etc/openstack-dashboard/local_settings

setsebool -P httpd_can_network_connect on
chown -R apache:apache /usr/share/openstack-dashboard/static
systemctl enable httpd.service memcached.service
systemctl start httpd.service memcached.service
