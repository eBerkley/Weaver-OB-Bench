#!/bin/bash
TOML=$1

cd $(dirname $0)/..


cp release/base/kube.yaml release/generated/kube.yaml
sed -i "s/TOML_FILE/$TOML/g" release/generated/kube.yaml

# yaml=$(weaver kube deploy $KUBE_YAML)
# deployment=$(echo $yaml | sed 's/\/tmp\/kube_\([0-9a-z]\+\)\.yaml/\1/g')
# echo $deployment > $VERSION_FILE # remember what version we are on;
# cp $yaml $WEAVER_GEN_YAML