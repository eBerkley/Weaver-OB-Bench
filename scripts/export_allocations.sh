#!/bin/bash

ALLOC_DIR="alloc"
mkdir -p $ALLOC_DIR


bench_type_pattern="([a-z_\-]+)_([a-z0-9]+)_([0-9]+)"
for f in $(ls benchmark/out); do
  if [[ $f =~ $bench_type_pattern ]]; then
    scheme=${BASH_REMATCH[1]}
    cscheme=${BASH_REMATCH[2]}
    cores_total=${BASH_REMATCH[3]}

    pod_stats_path=benchmark/out/$f/stats/pod_stats.csv
    echo $f

    # agg_pattern="ob aggregate,([0-9]+),"
    # if [[ $(cat $pod_stats_path) =~ $agg_pattern ]] && \
    #    [[ ${BASH_REMATCH[1]} = $cores_total ]]
    # then
      cp $pod_stats_path $ALLOC_DIR/$f.csv
    # else
    #   >&2 echo Error: $pod_stats_path reports total number of pods \
    #     created \(${BASH_REMATCH[1]}\) "!=" number intended \($cores_total\). Skipping...
    # fi

    
  fi
done