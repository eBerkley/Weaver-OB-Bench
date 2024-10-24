#!/bin/bash

# cd $(dirname $0)/..

# SCHEME_DIR="release/base/colocation"
# BASE_KUBE="release/base/kube.yaml"
# GEN_KUBE="release/generated/kube.yaml"

loop_body () {
  local fname=$1
  local name=$2
  local cfg=$3

  echo $fname
  echo                    | tee -a logs.txt
  echo ===== $name =====  | tee -a logs.txt
  echo                    | tee -a logs.txt

  cp $KUBE_BASE_YAML $KUBE_GEN_YAML
  sed -i "s#<DOCKER>#$DOCKER#g" $KUBE_GEN_YAML
  cat $fname >> $KUBE_GEN_YAML
  kubectl delete all --all

  # ./benchmark/benchmark.sh
  make bench
  # if there are already results in here
  if [ -d "benchmark/out/$name" ]; then
    rm -rf benchmark/out_old/$name
	mkdir -p benchmark_out_old
    mv benchmark/out/$name-$cfg benchmark/out_old/$name-$cfg
  fi
  mkdir -p benchmark/out/$name-$cfg
  #mkdir -p benchmark/out/$name-$cfg/imgs
  mv benchmark/stats benchmark/out/$name-$cfg/stats
  cat benchmark/out/$name-$cfg/stats/lat_stats_history.csv | grep -o "Aggregated[^\n]*" > benchmark/out/$name-$cfg/stats/aggregated.csv
  mkdir -p benchmark/stats

  #python3 benchmark/bar.py $name | tee -a logs.txt
}

# =*=*=*=*=*=*=*=*=*=*= PICK ONE =*=*=*=*=*=*=*=*=*=*=

# ===== Specify tests =====
for cfg in cfgs/*;
do
	echo $cfg
	cp $cfg CONFIG.cfg
	fname=$SCHEME_DIR/monolith.yaml
	name=$(basename $fname .yaml)
# =========================

# ======== Run all ========
# for fname in $COLOCATION_FNAMES; do
#   name=$(basename $fname .yaml)
# =========================

  loop_body $fname $name $cfg
done
