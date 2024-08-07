#!/bin/bash

yaml=$(weaver kube deploy $KUBE_GEN_YAML)
echo $yaml
deployment=$(echo $yaml | sed 's/\/tmp\/kube_\([0-9a-z]\+\)\.yaml/\1/g')
echo $deployment
echo $deployment > $VERSION_FILE
cp $yaml $WEAVER_GEN_YAML