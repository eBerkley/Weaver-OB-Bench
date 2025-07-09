#!/bin/bash

echo export_allocations.sh

ALLOC_DIR="alloc"
mkdir -p $ALLOC_DIR

MAX_CORES=${MAX_CORES:-36}

# bench_type_pattern="([a-z_\-]+)_([a-z0-9\-]+)_([0-9]+)"
stats_pattern="^([a-z_\-]+),([0-9]+)"
write_alloc () {
  local in=$1
  local out=$2
  printf "" >$out

  for line in $(cat $in); do
    if [[ ! $line =~ $stats_pattern ]]; then continue; fi

    name=${BASH_REMATCH[1]}
    replicas=${BASH_REMATCH[2]}

    if [[ $name = 'loadgenerator' ]] || [[ $name = 'aggregate' ]] then continue; fi
    
    echo $name=$replicas >>$out
    
  done
  
}

get () {
    f=$1
    scheme=$f

    cscheme=groups_height
    cores_total=$MAX_CORES

    pod_stats_path=benchmark/out/$f/stats/pod_stats.csv
    if [[ ! -r $pod_stats_path ]]; then
      >&2 echo Error: $pod_stats_path does not exist. Skipping...
      return
    fi
    echo $f

    at_capacity=$(./scripts/check_capacity.sh $pod_stats_path $scheme $cscheme $cores_total) 
    exit_code=$?
    
    if [[ $at_capacity = 1 ]] && [[ $exit_code = 0 ]]; then
      write_alloc $pod_stats_path $ALLOC_DIR/$f.cfg
    else
      >&2 echo Error: $pod_stats_path reports pods created less than capacity. Skipping...
    fi

}

if [[ -z $1 ]]; then
  for f in $(ls benchmark/out); do get $f; done
else 
  get $1
fi