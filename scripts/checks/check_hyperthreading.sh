#!/bin/bash

status=$(cat /sys/devices/system/cpu/smt/control)
if [[ $status = 'on' ]]; then
  >&2 echo Error: hyperthreading is enabled. Run \'scripts/hyperthreading.sh 0\' as root to disable.
  exit 1
elif [[ $status = 'off' ]]; then
  echo hyperthreading is disabled.
  
else
  >&2 echo Error: unknown smt setting: $status
  >&2 echo ???????????????????????????????
  exit 1
fi