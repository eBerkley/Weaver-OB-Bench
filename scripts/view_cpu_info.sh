#!/bin/bash

OB=ob
LOCUST=locust
for PROC_ID in $(pgrep $OB); do
  echo "$PROC_ID:"
  cat /proc/$PROC_ID/status | grep "Cpus_allowed_list\|Mems_allowed_list"
  echo
done
