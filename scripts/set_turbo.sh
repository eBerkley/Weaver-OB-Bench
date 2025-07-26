#!/bin/bash


if [[ ! -e "/sys/devices/system/cpu/intel_pstate/no_turbo" ]]; then
  echo Error: \"/sys/devices/system/cpu/intel_pstate/no_turbo\" does not exist. >&2
  exit 1
fi

if [[ $UID != 0 ]]; then
  echo Not running as sudo, can\'t set turbo mode.
  echo turbo mode disabled: $(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
  exit
fi


if [[ -z $1 ]] || [[ $1 = 1 ]]; then
  echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
  echo Turbo mode enabled.
elif [[ $1 = 0 ]]; then
  echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
  echo Turbo mode disabled.
else
  echo Error: Unknown input \($1\), should be 0 | 1. >&2
  exit 1
fi