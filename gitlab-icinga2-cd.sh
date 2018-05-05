#!/bin/bash

cd /etc/icinga2/conf.d/private
git pull
systemctl reload icinga2
