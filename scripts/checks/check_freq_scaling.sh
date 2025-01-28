#!/bin/bash
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  out=$(cat $cpu 2> /dev/null)
  if [[ $out != 'performance' ]]; then
    >&2 echo frequency scaling configured incorrectly! run scripts/freq_scaling.sh as root.
    exit 1
  fi
done
echo frequency scaling configured correctly.