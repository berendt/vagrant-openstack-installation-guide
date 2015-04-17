#!/bin/sh

set -x

###################################################################################################
###################################################################################################
# MONGODB

yum install -y mongodb-server mongodb

# NOTE(berendt): This is just a workaround for the Vagrant box
sed -i -e "s/^bind_ip =.*$/bind_ip = 127.0.0.1,10.0.0.11/" /etc/mongod.conf

sed -i -e "s/^#smallfiles =.*$/smallfiles = true/" /etc/mongod.conf

systemctl enable mongod.service
systemctl start mongod.service
