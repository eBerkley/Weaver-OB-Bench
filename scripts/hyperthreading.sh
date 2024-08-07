#!/bin/bash

help () {
  echo "usage: hyperthreading.sh [on|off|ON|OFF|1|0|toggle|2]"
  echo hyperthreading status: $(cat /sys/devices/system/cpu/smt/control)
}

if [[ $# -ne 1 ]]; then
  help
  exit 0
fi

if [ "$1" = "on" ] || [ "$1" = "ON" ] || [ "$1" = "1" ]; then
  echo on > /sys/devices/system/cpu/smt/control

elif [ "$1" = "off" ] || [ "$1" = "OFF" ] || [ "$1" = "0" ]; then
  echo off > /sys/devices/system/cpu/smt/control

elif [ "$1" = "toggle" ] || [ "$1" = "2" ]; then
  cur=$(cat /sys/devices/system/cpu/smt/control)
  
  if [ "$cur" = "off" ]; then
    echo "SMT -> on"
    echo on > /sys/devices/system/cpu/smt/control

  else
    echo "SMT -> off"
    echo off > /sys/devices/system/cpu/smt/control
  fi

else
  help
  exit 1

fi

