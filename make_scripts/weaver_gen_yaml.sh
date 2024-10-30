#!/bin/bash
sed -i "s#<DOCKER>#$DOCKER#g" $KUBE_GEN_YAML # Just in case...
sed -i "s#<OB_CORES>#$OB_CORES#g" $KUBE_GEN_YAML
sed -i "s#<OB_REPLICAS>#$OB_REPLICAS#g" $KUBE_GEN_YAML
yaml=$(weaver kube deploy $KUBE_GEN_YAML 2>>$LOGS_FILE) 
deployment=$(echo $yaml | sed 's/\/tmp\/kube_\([0-9a-z]\+\)\.yaml/\1/g')
echo version = $deployment | tee -a $LOGS_FILE
echo $deployment > $VERSION_FILE
echo $yaml | tee -a $LOGS_FILE
echo $WEAVER_GEN_YAML
cp $yaml $WEAVER_GEN_YAML
