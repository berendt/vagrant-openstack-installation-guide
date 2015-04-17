#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# SWIFT

source /home/vagrant/admin-openrc.sh

openstack user create --password SWIFT_PASS swift
openstack role add --project service --user swift admin
openstack service create --name swift \
  --description "OpenStack Object Storage" object-store
openstack endpoint create \
  --publicurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' \
  --internalurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' \
  --adminurl http://controller:8080 \
  --region regionOne \
  object-store

yum install -y openstack-swift-proxy python-swiftclient python-keystone-auth-token \
  python-keystonemiddleware memcached

curl -o /etc/swift/proxy-server.conf \
  https://git.openstack.org/cgit/openstack/swift/plain/etc/proxy-server.conf-sample?h=stable/kilo

crudini --set /etc/swift/proxy-server.conf DEFAULT bind_port 8080
crudini --set /etc/swift/proxy-server.conf DEFAULT user swift
crudini --set /etc/swift/proxy-server.conf DEFAULT swift_dir /etc/swift
crudini --set /etc/swift/proxy-server.conf pipeline:main pipeline "catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo proxy-logging proxy-server"
#crudini --set /etc/swift/proxy-server.conf app:proxy-server allow_account_management true
crudini --set /etc/swift/proxy-server.conf app:proxy-server account_autocreate true
crudini --set /etc/swift/proxy-server.conf filter:keystoneauth use 'egg:swift#keystoneauth'
crudini --set /etc/swift/proxy-server.conf filter:keystoneauth operator_roles admin,_member_
crudini --set /etc/swift/proxy-server.conf filter:authtoken paste.filter_factory keystonemiddleware.auth_token:filter_factory
crudini --set /etc/swift/proxy-server.conf filter:authtoken auth_uri http://controller:5000
crudini --set /etc/swift/proxy-server.conf filter:authtoken auth_url http://controller:35357
crudini --set /etc/swift/proxy-server.conf filter:authtoken auth_plugin password
crudini --set /etc/swift/proxy-server.conf filter:authtoken project_domain_id default
crudini --set /etc/swift/proxy-server.conf filter:authtoken user_domain_id default
crudini --set /etc/swift/proxy-server.conf filter:authtoken project_name service
crudini --set /etc/swift/proxy-server.conf filter:authtoken username swift
crudini --set /etc/swift/proxy-server.conf filter:authtoken password SWIFT_PASS
crudini --set /etc/swift/proxy-server.conf filter:authtoken delay_auth_decision true

crudini --set /etc/swift/proxy-server.conf filter:cache memcache_servers 127.0.0.1:11211

### RUN STEPS (object_swift.sh) ON OBJECT{1,2}
for node in object1 object2; do
    ssh root@$node "/vagrant/scripts/object_swift.sh"
done

cd /etc/swift

swift-ring-builder account.builder create 10 3 1
#swift-ring-builder account.builder add r1z1-10.0.0.51:6002/sdb1 100
#swift-ring-builder account.builder add r1z2-10.0.0.51:6002/sdc1 100
#swift-ring-builder account.builder add r1z3-10.0.0.52:6002/sdb1 100
#swift-ring-builder account.builder add r1z4-10.0.0.52:6002/sdc1 100
swift-ring-builder account.builder add r1z1-10.0.0.51:6002/sdb 100
swift-ring-builder account.builder add r1z3-10.0.0.52:6002/sdb 100
swift-ring-builder account.builder
swift-ring-builder account.builder rebalance

swift-ring-builder container.builder create 10 3 1
#swift-ring-builder container.builder add r1z1-10.0.0.51:6001/sdb1 100
#swift-ring-builder container.builder add r1z2-10.0.0.51:6001/sdc1 100
#swift-ring-builder container.builder add r1z3-10.0.0.52:6001/sdb1 100
#swift-ring-builder container.builder add r1z4-10.0.0.52:6001/sdc1 100
swift-ring-builder container.builder add r1z1-10.0.0.51:6001/sdb 100
swift-ring-builder container.builder add r1z3-10.0.0.52:6001/sdb 100
swift-ring-builder container.builder
swift-ring-builder container.builder rebalance

swift-ring-builder object.builder create 10 3 1
#swift-ring-builder object.builder add r1z1-10.0.0.51:6000/sdb1 100
#swift-ring-builder object.builder add r1z2-10.0.0.51:6000/sdc1 100
#swift-ring-builder object.builder add r1z3-10.0.0.52:6000/sdb1 100
#swift-ring-builder object.builder add r1z4-10.0.0.52:6000/sdc1 100
swift-ring-builder object.builder add r1z1-10.0.0.51:6000/sdb 100
swift-ring-builder object.builder add r1z3-10.0.0.52:6000/sdb 100
swift-ring-builder object.builder
swift-ring-builder object.builder rebalance

chown -R swift:swift /etc/swift

for node in object1 object2; do
    for filename in account.ring.gz container.ring.gz object.ring.gz; do
        scp /etc/swift/$filename root@$node:/etc/swift/$filename
    done
done

curl -o /etc/swift/swift.conf \
  https://git.openstack.org/cgit/openstack/swift/plain/etc/swift.conf-sample?h=stable/kilo

crudini --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix HASH_PATH_PREFIX
crudini --set /etc/swift/swift.conf swift-hash swift_hash_path_prefix HASH_PATH_SUFFIX
crudini --set /etc/swift/swift.conf storage-policy:0 name Policy-0
crudini --set /etc/swift/swift.conf storage-policy:0 default yes

for node in object1 object2; do
    scp /etc/swift/swift.conf root@$node /etc/swift/swift.conf
    ssh root@$node "chown -R swift:swift /etc/swift"
done

systemctl enable openstack-swift-proxy.service memcached.service
systemctl start openstack-swift-proxy.service memcached.service

for node in object1 object2; do
    ssh root@$node "systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service \
      openstack-swift-account-reaper.service openstack-swift-account-replicator.service"
    ssh root@$node "systemctl start openstack-swift-account.service openstack-swift-account-auditor.service \
      openstack-swift-account-reaper.service openstack-swift-account-replicator.service"
    ssh root@$node "systemctl enable openstack-swift-container.service openstack-swift-container-auditor.service \
      openstack-swift-container-replicator.service openstack-swift-container-updater.service"
    ssh root@$node "systemctl start openstack-swift-container.service openstack-swift-container-auditor.service \
      openstack-swift-container-replicator.service openstack-swift-container-updater.service"
    ssh root@$node "systemctl enable openstack-swift-object.service openstack-swift-object-auditor.service \
      openstack-swift-object-replicator.service openstack-swift-object-updater.service"
    ssh root@$node "systemctl start openstack-swift-object.service openstack-swift-object-auditor.service \
      openstack-swift-object-replicator.service openstack-swift-object-updater.service"
done
