#!/bin/bash

cd /etc/icinga2/conf.d/private

export GIT_OUTPUT=`git pull`

if [[ $GIT_OUTPUT = *".conf"* ]]; then
  echo "Changes made, reloading Icinga2"
  systemctl reload icinga2
else
  echo "No changes made, NOT reloading Icinga2"
fi
