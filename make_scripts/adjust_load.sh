#!/bin/bash

# used for perf bench type.

SCHEME=$1
load=$2
replicas=0

pat="m[a-z\-]*=([0-9]+)"
for line in $(cat alloc/$SCHEME.cfg); do
  if [[ $line =~ $pat ]]; then
    replicas=${BASH_REMATCH[1]}
    break
  fi
done

echo $(( load * replicas ))