#!/bin/bash

SCHEME_DIR="release/base/colocation"
BASE_KUBE="release/base/kube.yaml"
GEN_KUBE="release/generated/kube.yaml"


for fname in $SCHEME_DIR/*.yaml; do
    name=$(basename $fname .yaml)
    
    echo $fname
    echo $name
    cp $BASE_KUBE $GEN_KUBE
    cat $fname >> $GEN_KUBE

    ./benchmark/benchmark.sh

    mkdir benchmark/out/$name
    mv benchmark/imgs benchmark/out/$name/imgs
    mv benchmark/stats benchmark/out/$name/stats
    python3 benchmark/bar.py $name
    mkdir benchmark/imgs
    mkdir benchmark/stats

done