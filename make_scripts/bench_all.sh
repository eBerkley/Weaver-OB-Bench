#!/bin/bash

# cd $(dirname $0)/..

# SCHEME_DIR="release/base/colocation"
# BASE_KUBE="release/base/kube.yaml"
# GEN_KUBE="release/generated/kube.yaml"

# for fname in $SCHEME_DIR/microservices.yaml $SCHEME_DIR/monolith.yaml $SCHEME_DIR/all_but_main.yaml $SCHEME_DIR/mixed.yaml; do
# for fname in $SCHEME_DIR/*.yaml; do
for fname in $COLOCATION_FNAMES; do
    name=$(basename $fname .yaml)
    
    echo $fname
    echo                    | tee -a logs.txt
    echo ===== $name =====  | tee -a logs.txt
    echo                    | tee -a logs.txt

    # cp $KUBE_BASE_YAML $KUBE_GEN_YAML
    # cat $fname >> $KUBE_GEN_YAML

    # ./benchmark/benchmark.sh
    # make bench

    # mkdir benchmark/out/$name
    # mkdir benchmark/out/$name/imgs
    # mv benchmark/stats benchmark/out/$name/stats
    # mkdir benchmark/stats

    # python3 benchmark/bar.py $name

done