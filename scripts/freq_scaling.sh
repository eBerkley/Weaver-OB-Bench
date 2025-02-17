#!/bin/bash
governer=${1:-'performance'}
echo attempting to set all cores to $governer:

if [[ $UID -ne 0 ]]; then
  >&2 echo Error: must run as root.
  exit 1
fi

for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do  
  echo $governer > $cpu 2> /dev/null
done

echo Success!



