#!/bin/bash

status=$(cat /sys/devices/system/cpu/smt/control)
if [[ $status = 'on' ]]; then
  >&2 echo Error: hyperthreading is enabled. Run \'scripts/hyperthreading.sh 0\' as root to disable.
  exit 1
elif [[ $status = 'off' ]]; then
  echo hyperthreading is disabled.
  
elif [[ $status = 'notimplemented' ]]; then
  echo hyperthreading not implemented.
else
  >&2 echo Error: unknown smt setting: $status
  exit 1
fi