#!/bin/bash

cd $(dirname $0)/..

# Just in case
minikube addons enable metrics-server


./scripts/start.sh
sleep 10
./scripts/pull_stats.sh
./scripts/stop.sh

