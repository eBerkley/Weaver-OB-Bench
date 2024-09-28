#!/bin/bash

# cd $(dirname $0)/..

# SCHEME_DIR="release/base/colocation"
# BASE_KUBE="release/base/kube.yaml"
# GEN_KUBE="release/generated/kube.yaml"

loop_body () {
  local fname=$1
  local name=$2

  echo $fname
  date +%T                | tee -a logs.txt
  echo ===== $name =====  | tee -a logs.txt
  echo                    | tee -a logs.txt

  cp $KUBE_BASE_TOML $KUBE_GEN_TOML
  cat $fname >> $KUBE_GEN_TOML

  # ./benchmark/benchmark.sh
  make bench

  # if there are already results in here
  if [ -d "benchmark/out/$name" ]; then
    rm -rf benchmark/out_old/$name
    mv benchmark/out/$name benchmark/out_old/$name
  fi
  mkdir benchmark/out/$name
  mkdir benchmark/out/$name/imgs
  mv benchmark/stats benchmark/out/$name/stats
  mkdir benchmark/stats

  python3 benchmark/bar.py $name | tee -a logs.txt
}

# =*=*=*=*=*=*=*=*=*=*= PICK ONE =*=*=*=*=*=*=*=*=*=*=

# ===== Specify tests =====
for name in frontend monolith mixed; do
  fname=$SCHEME_DIR/$name.toml
# =========================

# ======== Run all ========
# for fname in $COLOCATION_FNAMES; do
#   name=$(basename $fname .toml)
# =========================

  loop_body $fname $name
done