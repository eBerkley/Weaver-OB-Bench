#!/bin/bash

if [[ -z $SCHEME ]]; then
  echo "\$SCHEME must be set."
  exit 1
fi

fname=$SCHEME_DIR/$SCHEME.yaml
echo $fname
echo                    | tee -a logs.txt
echo ===== $name =====  | tee -a logs.txt
echo                    | tee -a logs.txt

cp $KUBE_BASE_YAML $KUBE_GEN_YAML
sed -i "s#<DOCKER>#$DOCKER#g" $KUBE_GEN_YAML
cat $fname >> $KUBE_GEN_YAML


