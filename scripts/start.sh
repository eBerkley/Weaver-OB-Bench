#!/bin/bash

# minikube start --cpus=4 --memory 4096 --disk-size 32g



cd $(dirname $0)/..

./scripts/stop.sh

KUBE_YAML=release/generated/kube.yaml
WEAVER_GEN_YAML=release/generated/gen.yaml
LOAD_GEN_YAML=release/generated/loadgen.yaml

weaver generate src/...
cd src; go build -o ../release/generated; cd ..

yaml=$(weaver kube deploy $KUBE_YAML)

echo
echo yaml file = $yaml 

# extracts deployment name from filename: /tmp/kube_([0-9a-z]+).yaml
# eg /tmp/kube_6ef9d5d5.yaml --> 6ef9d5d5
deployment=$(echo $yaml | sed 's/\/tmp\/kube_\([0-9a-z]\+\)\.yaml/\1/g')

echo deployment id = $deployment 
echo

cp $yaml $WEAVER_GEN_YAML

# release/loadgen.yaml: sets loadgen image version, resets frontend address
./scripts/push.sh $deployment


sed -i "s/frontend:80/boutique-$deployment:80/g" $LOAD_GEN_YAML

# kubectl apply -f $LOAD_GEN_YAML

# echo
# echo http://boutique-$deployment:80
# echo kubectl port-forward service/boutique-$deployment 8080:80

if [[ "$1" = "test" ]]; then

  kubectl apply -f $WEAVER_GEN_YAML
  echo waiting to port-forward frontend... ^C to cancel.
  
  sleep 20
  kubectl port-forward service/boutique-$deployment 8080:80
  
  
  echo kubectl port-forward service/boutique-$deployment 8080:80
else

  kubectl apply -f $LOAD_GEN_YAML
  kubectl apply -f $WEAVER_GEN_YAML


  echo frontend address:
  echo http://boutique-$deployment:80
  echo
  # echo waiting to port-forward loadgenerator... ^C to cancel.

  # sleep 12
  # kubectl port-forward deployment/loadgenerator 8089:8089
  
  
  # kubectl port-forward deployment/loadgenerator 8089:8089

fi