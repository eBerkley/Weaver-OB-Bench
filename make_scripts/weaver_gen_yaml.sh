#!/bin/bash
sed -i "s#<DOCKER>#$DOCKER#g" $KUBE_GEN_YAML # Just in case...
yaml=$(weaver kube deploy $KUBE_GEN_YAML 2>>$LOGS_FILE) 
deployment=$(echo $yaml | sed 's/\/tmp\/kube_\([0-9a-z]\+\)\.yaml/\1/g')
echo version = $deployment | tee -a $LOGS_FILE
echo $deployment > $VERSION_FILE
cp $yaml $WEAVER_GEN_YAML
