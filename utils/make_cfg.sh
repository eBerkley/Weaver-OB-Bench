#!/bin/bash

cd $(dirname $0)/../cfgs

name=$1

load_replicas=

if [[ $name =~ "-arm" ]]; then
  load_replicas=74
else
  load_replicas=22
fi
# LOADGEN_REPLICAS=26 for 36 cores per socket servers
## 22 workers + 3 kube cores + 1 master + 1 overflow = 27
## Add 1 mongo configsvc + 3 mongos + (2 mongo shards * 2 replicas) + 1 redis = 36
# LOADGEN_REPLICAS=74 for 80 cores per socket servers
## 74 workers + 5 kube cores + 1 master + 0 overflow = 80
# TODO: Verify that altra never makes overflow alloc. 
# if it does should be simple to identify, alloc bench won't work.
cat << EOF > $name.cfg
SCHEME=$name
C_SCHEME=groups_height
LOADGEN_REPLICAS=$load_replicas
OB_CORES=1
OB_REPLICAS=100
VTUNE_GROUP_NAME=$(./../utils/lower_grp.sh $name)
FIXED=main
FIXED_HEIGHT=2
FIXED_WIDTH=1
ALLOC_FILE=*
CRITICAL_SCALE_UTIL=75
NONCRITICAL_SCALE_UTIL=75
TRIVIAL_SCALE_UTIL=75
FALLBACK_SCALE_UTIL=60
CRITICAL_MIN_REPLICAS=1
NONCRITICAL_MIN_REPLICAS=1
TRIVIAL_MIN_REPLICAS=1
FALLBACK_MIN_REPLICAS=1
EOF