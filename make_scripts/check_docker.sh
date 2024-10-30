#!/bin/bash

# This file is used to assert that the env variable DOCKER has been set in CONFIG.cfg

if [[ -z "$DOCKER" ]]; then
  echo "Error: the env variable 'DOCKER' must be specified in CONFIG.cfg".
  echo "It should be set to the name of a docker repo that you have read/write access to."
  echo "set the DOCKER variable, and then re-run again."
  exit 1
fi
