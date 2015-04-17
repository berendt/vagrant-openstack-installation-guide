#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# KEYSTONE

cat <<EOT | mysql -u root -pROOT_DB_PASS
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
  IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
  IDENTIFIED BY 'KEYSTONE_DBPASS';
EOT

yum install -y openstack-keystone python-openstackclient memcached python-memcached
systemctl enable memcached.service
systemctl start memcached.service

crudini --set /etc/keystone/keystone.conf DEFAULT admin_token RANDOM_TOKEN
crudini --set /etc/keystone/keystone.conf database connection 'mysql://keystone:KEYSTONE_DBPASS@controller/keystone'
crudini --set /etc/keystone/keystone.conf memcache servers 'localhost:11211'
crudini --set /etc/keystone/keystone.conf token provider 'keystone.token.providers.uuid.Provider'
crudini --set /etc/keystone/keystone.conf token driver 'keystone.token.persistence.backends.memcache.Token'
crudini --set /etc/keystone/keystone.conf revoke driver 'keystone.contrib.revoke.backends.sql.Revoke'
crudini --set /etc/keystone/keystone.conf DEFAULT verbose True

su -s /bin/sh -c "keystone-manage db_sync" keystone

systemctl enable openstack-keystone.service
systemctl start openstack-keystone.service

(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
  echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
  >> /var/spool/cron/keystone

export OS_TOKEN=RANDOM_TOKEN
export OS_URL=http://controller:35357/v2.0
openstack service create --name keystone \
  --description "OpenStack Identity" identity
openstack endpoint create \
  --publicurl http://controller:5000/v2.0 \
  --internalurl http://controller:5000/v2.0 \
  --adminurl http://controller:35357/v2.0 \
  --region regionOne \
  identity

openstack project create --description "Admin Project" admin
openstack user create --password ADMIN_PASS admin
openstack role create admin
openstack role add --project admin --user admin admin
openstack project create --description "Service Project" service
openstack project create --description "Demo Project" demo
openstack user create --password DEMO_PASS demo
openstack role create _member_
openstack role add --project demo --user demo _member_

unset OS_TOKEN OS_URL

openstack --os-auth-url http://controller:35357 \
  --os-project-name admin --os-username admin --os-auth-type password \
  --os-password ADMIN_PASS token issue
openstack --os-auth-url http://controller:35357 \
  --os-project-domain-id default --os-user-domain-id default \
  --os-project-name admin --os-username admin --os-auth-type password \
  --os-password ADMIN_PASS token issue
openstack --os-auth-url http://controller:35357 \
  --os-project-name admin --os-username admin --os-auth-type password \
  --os-password ADMIN_PASS project list
openstack --os-auth-url http://controller:35357 \
  --os-project-name admin --os-username admin --os-auth-type password \
  --os-password ADMIN_PASS user list
openstack --os-auth-url http://controller:35357 \
  --os-project-name admin --os-username admin --os-auth-type password \
  --os-password ADMIN_PASS role list
openstack --os-auth-url http://controller:5000 \
  --os-project-domain-id default --os-user-domain-id default \
  --os-project-name demo --os-username demo --os-auth-type password \
  --os-password DEMO_PASS token issue
openstack --os-auth-url http://controller:5000 \
  --os-project-domain-id default --os-user-domain-id default \
  --os-project-name demo --os-username demo --os-auth-type password \
  --os-password DEMO_PASS user list


cat <<EOT >> /home/vagrant/admin-openrc.sh
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_AUTH_URL=http://controller:35357/v3
EOT

cat <<EOT >> /home/vagrant/demo-openrc.sh
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=demo
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=DEMO_PASS
export OS_AUTH_URL=http://controller:5000/v3
EOT
