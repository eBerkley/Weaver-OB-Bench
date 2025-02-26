#!/bin/bash

ALLOC_DIR="alloc"
mkdir -p $ALLOC_DIR


bench_type_pattern="([a-z_\-]+)_([a-z0-9\-]+)_([0-9]+)"
stats_pattern="^([a-z\-]+),([0-9]+)"
write_alloc () {
  local in=$1
  local out=$2
  printf "" >$out

  for line in $(cat $in); do
    if [[ ! $line =~ $stats_pattern ]]; then continue; fi

    name=${BASH_REMATCH[1]}
    replicas=${BASH_REMATCH[2]}

    if [[ $name = 'loadgenerator' ]] then continue; fi
    
    echo $name=$replicas >>$out
    
  done
  
}

tmp=$(mktemp)

for f in $(ls benchmark/out); do
  if [[ $f =~ $bench_type_pattern ]]; then

    scheme=${BASH_REMATCH[1]}
    cscheme=${BASH_REMATCH[2]}
    cores_total=${BASH_REMATCH[3]}

    pod_stats_path=benchmark/out/$f/stats/pod_stats.csv
    if [[ ! -r $pod_stats_path ]]; then
      >&2 echo Error: $pod_stats_path does not exist. Skipping...
    fi
    echo $f

    at_capacity=$(./scripts/check_capacity.sh $pod_stats_path $scheme $cscheme $cores_total) 
    exit_code=$?
    
    if [[ $at_capacity = 1 ]] && [[ $exit_code = 0 ]]; then
      write_alloc $pod_stats_path $ALLOC_DIR/$f.cfg
    else
      >&2 echo Error: $pod_stats_path reports pods created less than capacity. Skipping...
    fi
  fi
done

rm -f $tmp