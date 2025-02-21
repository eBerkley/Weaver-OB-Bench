#!/bin/bash

status=$(cat /proc/sys/kernel/numa_balancing)
if [[ $status = 1 ]]; then
  echo numa balancing enabled.
  exit 0
elif [[ $status = 0 ]]; then
  >&2 echo Error: numa balancing is disabled. run scripts/numa_balance.sh as root.
  exit 1
else
  >&2 echo Error: unknown numa balancing setting: $status
  exit 1
fi


