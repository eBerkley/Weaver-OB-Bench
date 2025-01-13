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

# Set the wait time for the rampload shape
sed -i "s#<LOCUST_WAIT_TIME>#\"$LOCUST_WAIT_TIME\"#g" $LOAD_GEN_YAML

# Set the ramp duration for the rampload shape
sed -i "s#<LOCUST_RAMP_DURATION>#\"$LOCUST_RAMP_DURATION\"#g" $LOAD_GEN_YAML



# Build the image and push it to docker
docker build $LOAD_SRC -t $DOCKER/loadgen:$version >>$DEBUG_OUTPUT 2>&1
docker push $DOCKER/loadgen:$version >>$DEBUG_OUTPUT
