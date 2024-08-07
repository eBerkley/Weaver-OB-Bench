#!/bin/bash

cd $(dirname $0)

# generate a new set of inputs
./getInputs.py

cd ..

WEAVER=../onlineboutique
GRPC=../microservices-demo

remove_orphans() {
  kill $(ps -ef | grep 'scripts/start.sh test' | awk '{print $2}')
  kill $(ps -ef | grep 'kubectl port-forward service' | awk '{print $2}')
}

# just in case
remove_orphans

# --- get weaver outputs

./"$WEAVER"/scripts/start.sh test&

sleep 60

python3 ./test/getOutputs.py weaver

./"$WEAVER"/scripts/stop.sh
remove_orphans

# --- get gRPC outputs

./"$GRPC"/scripts/start.sh test&

sleep 60

python3 ./test/getOutputs.py grpc

./"$GRPC"/scripts/stop.sh
remove_orphans

echo 
echo
echo "---------------------------------------------------------"
echo "                   Running Full Test...                  "
echo "---------------------------------------------------------"
echo
echo

./test/diffAll.sh