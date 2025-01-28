#!/bin/bash

cur=0

for p in $(pgrep -f "/weaver/ob"); do
  cores=$(cat /proc/$p/status | grep Cpus_allowed_list | awk '{print $2}')
  hostname=$(sudo cat /proc/$p/environ | strings | grep HOSTNAME)
  fusion_group=$(echo $hostname | gawk 'match($0, /=ob-([^-]*)/, a) {print a[1]}')

  sudo taskset -cp $cur $p
  (( cur += 1 ))

  cores2=$(cat /proc/$p/status | grep Cpus_allowed_list | awk '{print $2}')

  echo $fusion_group \($p\) : $cores '-->' $cores2

done
