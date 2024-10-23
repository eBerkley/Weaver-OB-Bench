#!/bin/bash
cp $LOAD_BASE_YAML $LOAD_GEN_YAML

version=$(cat $VERSION_FILE)
sed -i "s#<DOCKER>#$DOCKER#g" $LOAD_GEN_YAML
sed -i "s/<VERSION>/$version/g" $LOAD_GEN_YAML
sed -i "s/<ADDR>/boutique-$version:80/g" $LOAD_GEN_YAML
sed -i "s/<LOADGEN_REPLICAS>/$LOADGEN_REPLICAS/g" $LOAD_GEN_YAML
sed -i "s/<LOADGEN_REPLICAS_ENV>/\"$LOADGEN_REPLICAS\"/g" $LOAD_GEN_YAML # necessary sadly
sed -i "s/<LOCUST_SHAPE>/$LOCUST_SHAPE/g" $LOAD_GEN_YAML

docker build $LOAD_SRC -t $DOCKER/loadgen:$version 2>>$LOGS_FILE
docker push $DOCKER/loadgen:$version >>$LOGS_FILE