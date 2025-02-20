#!/bin/bash

# This file will see if, based on the current CSCHEME + Allocations, we can admit any more pods.

# echo 1 if we are at capacity, 0 otherwise.

# Usage: check_capacity.sh [STATS_FILE] [SCHEME_NAME] [C_SCHEME] [CORES]

cd $(dirname $0)/..
CUR_STATS=${1:-'scripts/pod_stats.csv'}
SCHEME=${2:-$SCHEME}
C_SCHEME=${3:-$C_SCHEME}
MAX_CORES=${4:-36}

# If $CUR_STATS does not exist / isn't readable
if [[ ! -r $CUR_STATS ]]; then
  # Assume that it's because we just started the benchmark, and it hasn't been created yet. 
  echo Debug: file $CUR_STATS does not exist / is not readable. >&2
  echo 0
  exit 0
fi



GROUPS_FILE=${GROUPS_FILE:-"release/generated/groups.yaml"}
SCHEME_DIR=${SCHEME_DIR:-'release/base/colocation'}
RESOURCE_SPEC_FILE=${RESOURCE_SPEC_FILE:-'release/base/resourceSpec.yaml'}


SCHEME_PATH=$SCHEME_DIR/$SCHEME

SCHEME_FILE=$SCHEME_PATH/spec.yaml
CSCHEME_FILE=$SCHEME_PATH/$C_SCHEME.cfg

total_cores=0

cscheme_pattern="^([a-z_\-]+)=([0-9]+)"


# Lowest number of cores that can be allocated to a single pod.
# In other words, if each pod requires 2 cores, but we only have 1 core left, 
#   we say that we are at capacity anyways.
min_alloc=$MAX_CORES

for alloc in $(cat $CSCHEME_FILE); do
  if [[ $alloc =~ $cscheme_pattern ]]; then
    name=${BASH_REMATCH[1]}
    cores=${BASH_REMATCH[2]}
    
    # Update min alloc, if needed.
    min_alloc=$(( min_alloc < cores ? min_alloc : cores ))

    stats_pattern="^$name,([0-9]+)"

    if [[ $(grep $name $CUR_STATS) =~ $stats_pattern ]]; then
      replicas=${BASH_REMATCH[1]}
      (( total_cores += replicas * $cores ))
    else
      echo Error: name $name not found in stats. >&2
      echo 1
      exit 1
    fi
  else
    echo Error: $alloc does not match cscheme pattern. >&2
    echo 1
    exit 1
  fi
done

remaining=$(( MAX_CORES - total_cores ))
if [[ $remaining < $min_alloc ]]; then
  echo 1
else
  echo 0
fi