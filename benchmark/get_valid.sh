#!/bin/bash

path=benchmark/out

NOT_STATIC=""
OLD=""
NOT_CAPACITY=""
VALID=""

cfg_pattern="([a-z\-]+)_([0-9a-z\-]+)_([0-9]+)"

for d in $path/*; do
  name=$(basename $d)

  if [[ ! $name =~ $cfg_pattern ]]; then continue; fi
  

  scheme=${BASH_REMATCH[1]}
  cscheme=${BASH_REMATCH[2]}
  cores=${BASH_REMATCH[3]}
  
  if [[ ! -r "$d/info.txt" ]]; then
    OLD+="$name, "
    continue
  fi

  cap=$(./scripts/check_capacity.sh $d/stats/pod_stats.csv $scheme $cscheme $cores)
  code=$?

  if [[ $cap = 0 ]] || [[ $code = 1 ]]; then
    NOT_CAPACITY+="$name, "
    continue
  fi

  if [[ $(grep BENCH_STATIC "$d/info.txt") = "BENCH_STATIC=0" ]]; then
    NOT_STATIC+="$name, "
    continue
  fi

  VALID+="$name, "
  
done

echo valid: $VALID
echo old: $OLD
echo not static: $NOT_STATIC
echo not at capacity: $NOT_CAPACITY