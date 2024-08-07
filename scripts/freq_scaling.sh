#!/bin/bash
found=0
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  out=$(cat $cpu)
  if [ ! "$out" = "performance" ]; then
    echo $cpu = $out
    found=1
  fi
done

if [ $found -eq 0 ]; then
  echo Frequency scaling configured correctly.
else
  echo Frequency scaling not configured correctly.
  exit 1
fi

