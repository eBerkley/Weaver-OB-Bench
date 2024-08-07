#!/bin/bash

TOML=$1

cd $(dirname $0)/..


BASE=./release/base/kube.yaml
GEN=./release/generated/kube.yaml

cp $BASE $GEN

sed -i "s/TOML_FILE/$TOML/g" $GEN




