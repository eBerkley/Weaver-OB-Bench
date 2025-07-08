#!/bin/bash

# This file resets all of the config values in the generated loadgen.yaml file, ``
# and then sets them based on current env variables.

# ***Note***: if weaver_gen_yaml.sh is ran *after* this script is ran,
# the deployment ***WILL NOT*** work.


# Reset config values
cp $LOAD_BASE_YAML $LOAD_GEN_YAML

# See what the OB app will be deployed as
version=$(cat $VERSION_FILE)

# Docker repo
sed -i "s#<DOCKER>#$DOCKER#g" $LOAD_GEN_YAML

# Docker image version
sed -i "s/<VERSION>/$version/g" $LOAD_GEN_YAML

# This is why weaver_gen_yaml.sh must be ran first, 
# if it is ran after the address will not be up to date and traffic can't be sent.
sed -i "s/<ADDR>/boutique-$version:80/g" $LOAD_GEN_YAML 

# Tell kubernetes how many worker replicas to make
sed -i "s/<LOADGEN_REPLICAS>/$LOADGEN_REPLICAS/g" $LOAD_GEN_YAML

# Tell loadgen master instance how many worker replicas to expect.
# The config constants do need to be set separately as far as I can tell.
sed -i "s/<LOADGEN_REPLICAS_ENV>/\"$LOADGEN_REPLICAS\"/g" $LOAD_GEN_YAML 

# Tell the locust instances which of the loadshapes to run.
sed -i "s/<LOCUST_SHAPE>/$LOCUST_SHAPE/g" $LOAD_GEN_YAML

sed -i "s/<LOCUST_CONN_POOL>/\"$LOCUST_CONN_POOL\"/g" $LOAD_GEN_YAML
sed -i "s/<LOCUST_REQ_RATE>/\"$LOCUST_REQ_RATE\"/g" $LOAD_GEN_YAML

sed -i "s/<LOCUST_CONST_USERS>/\"$LOCUST_CONST_USERS\"/g" $LOAD_GEN_YAML

# Set the wait time for the rampload shape
sed -i "s#<LOCUST_WAIT_TIME>#\"$LOCUST_WAIT_TIME\"#g" $LOAD_GEN_YAML

# Set the ramp duration for the rampload shape
sed -i "s#<LOCUST_RAMP_DURATION>#\"$LOCUST_RAMP_DURATION\"#g" $LOAD_GEN_YAML

# Set how many values to use when calculating variance for stable_rampload shape
sed -i "s#<LOCUST_VARIANCE_WINDOW>#\"$LOCUST_VARIANCE_WINDOW\"#g" $LOAD_GEN_YAML

# Set max variance before ramping up for stable_rampload shape
sed -i "s#<LOCUST_MAX_VARIANCE>#\"$LOCUST_MAX_VARIANCE\"#g" $LOAD_GEN_YAML     

sed -i "s#<LOCUST_STABLE_P99>#\"$LOCUST_STABLE_P99\"#g" $LOAD_GEN_YAML

sed -i "s#<LOCUST_LOW_LOAD_USERS>#\"$LOCUST_LOW_LOAD_USERS\"#g" $LOAD_GEN_YAML

sed -i "s#<LOCUST_SLO_RATIO>#\"$LOCUST_SLO_RATIO\"#g" $LOAD_GEN_YAML

# set max tail latency for terminating tests.
sed -i "s#<LOCUST_MAX_TAIL>#\"$LOCUST_MAX_TAIL\"#g" $LOAD_GEN_YAML

# set number of users to add for low load
sed -i "s#<LOCUST_SLOWLOAD_RAMP>#\"$LOCUST_SLOWLOAD_RAMP\"#g" $LOAD_GEN_YAML

# Set the latency stat export frequency
sed -i "s#<LOCUST_CSV_INTERVAL>#\"$LOCUST_CSV_INTERVAL\"#g" $LOAD_GEN_YAML

sed -i "s#<LOCUST_SLOWER_PAUSE>#\"$LOCUST_SLOWER_PAUSE\"#g" $LOAD_GEN_YAML

sed -i "s#<LOCUST_RAMP_RATE>#\"$LOCUST_RAMP_RATE\"#g" $LOAD_GEN_YAML

sed -i "s#<LOCUST_PHASE2_USERS>#\"$LOCUST_PHASE2_USERS\"#g" $LOAD_GEN_YAML
sed -i "s#<LOCUST_SLOWLOAD_RAMP2>#\"$LOCUST_SLOWLOAD_RAMP2\"#g" $LOAD_GEN_YAML
sed -i "s#<LOCUST_RAMP_RATE2>#\"$LOCUST_RAMP_RATE2\"#g" $LOAD_GEN_YAML

# If we are going to be adding replicas, 
# ensure connections are periodically reset to route traffic to new main components.
if [[ $BENCH_TYPE = "STATIC" ]] || [[ $LOCUST_RESET_CONN = "0" ]]; then
  sed -i "s#<LOCUST_RESET_CONN>#\"0\"#g" $LOAD_GEN_YAML
else # $BENCH_TYPE != "STATIC"
  sed -i "s#<LOCUST_RESET_CONN>#\"1\"#g" $LOAD_GEN_YAML
fi

sed -i "s#<LOCUST_CHECKOUT_MOD>#\"$LOCUST_CHECKOUT_MOD\"#g" $LOAD_GEN_YAML

# Build the image and push it to docker
docker build $LOAD_SRC -t $DOCKER/loadgen:$version >>$DEBUG_OUTPUT 2>&1
docker push $DOCKER/loadgen:$version >>$DEBUG_OUTPUT
