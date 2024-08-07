#!/bin/bash

cd $(dirname $0)/..

kubectl delete -f release/generated/gen.yaml
kubectl delete -f release/generated/loadgen.yaml