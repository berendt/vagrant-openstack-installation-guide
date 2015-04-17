#!/bin/sh

set -x

/vagrant/scripts/prepare_node.sh

###################################################################################################
###################################################################################################
# SWIFT

yum install -y xfsprogs rsync

mkfs.xfs /dev/sdb
mkdir -p /srv/node/sdb
echo "/dev/sdb /srv/node/sdb xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
mount /srv/node/sdb

cat <<EOT > /etc/rsyncd.conf
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 10.0.0.50
 
[account]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/account.lock
 
[container]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/container.lock
 
[object]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/object.lock
EOT

systemctl enable rsyncd.service
systemctl start rsyncd.service

yum install -y openstack-swift-account openstack-swift-container \
  openstack-swift-object

curl -o /etc/swift/account-server.conf \
  https://git.openstack.org/cgit/openstack/swift/plain/etc/account-server.conf-sample?h=stable/kilo
curl -o /etc/swift/container-server.conf \
  https://git.openstack.org/cgit/openstack/swift/plain/etc/container-server.conf-sample?h=stable/kilo
curl -o /etc/swift/object-server.conf \
  https://git.openstack.org/cgit/openstack/swift/plain/etc/object-server.conf-sample?h=stable/kilo

BIND_IP=$(grep $(hostname) /etc/hosts | tail -n1 | awk '{ print $1 }')

crudini --set /etc/swift/account-server.conf DEFAULT bind_ip $BIND_IP
crudini --set /etc/swift/account-server.conf DEFAULT bind_port 6002
crudini --set /etc/swift/account-server.conf DEFAULT user swift
crudini --set /etc/swift/account-server.conf DEFAULT swift_dir /etc/swift
crudini --set /etc/swift/account-server.conf DEFAULT devices /srv/node
crudini --set /etc/swift/account-server.conf "pipeline:main" pipeline "healthcheck recon account-server"
crudini --set /etc/swift/account-server.conf "filter:recon" recon_cache_path /var/cache/swift

crudini --set /etc/swift/container-server.conf DEFAULT bind_ip $BIND_IP
crudini --set /etc/swift/container-server.conf DEFAULT bind_port 6001
crudini --set /etc/swift/container-server.conf DEFAULT user swift
crudini --set /etc/swift/container-server.conf DEFAULT swift_dir /etc/swift
crudini --set /etc/swift/container-server.conf DEFAULT devices /srv/node
crudini --set /etc/swift/container-server.conf "pipeline:main" pipeline "healthcheck recon container-server"
crudini --set /etc/swift/container-server.conf "filter:recon" recon_cache_path /var/cache/swift

crudini --set /etc/swift/object-server.conf DEFAULT bind_ip $BIND_IP
crudini --set /etc/swift/object-server.conf DEFAULT bind_port 6000
crudini --set /etc/swift/object-server.conf DEFAULT user swift
crudini --set /etc/swift/object-server.conf DEFAULT swift_dir /etc/swift
crudini --set /etc/swift/object-server.conf DEFAULT devices /srv/node
crudini --set /etc/swift/object-server.conf "pipeline:main" pipeline "healthcheck recon object-server"
crudini --set /etc/swift/object-server.conf filter:recon recon_cache_path /var/cache/swift
crudini --set /etc/swift/object-server.conf filter:recon recon_lock_path /var/lock

chown -R swift:swift /srv/node
mkdir -p /var/cache/swift
chown -R swift:swift /var/cache/swift
