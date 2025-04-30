#!/bin/bash


flags=""
flags+=' --cpus=max'
flags+=' --disk-size=15g'

if [[ $BENCH_TYPE != "STATIC" ]]; then # If we are NOT static, let kubernetes handle pinning to cores.
  flags+=' --feature-gates=CPUManagerPolicyAlphaOptions=true'
  flags+=' --extra-config=kubelet.cpu-manager-policy-options=align-by-socket=true'
  flags+=' --extra-config=kubelet.cpu-manager-policy=static'
  flags+=" --extra-config=kubelet.reserved-cpus=${KUBE_CORES:-0}"
fi 

minikube start $flags

minikube addons enable metrics-server
# kubectl apply -f release/base/metrics-server.yaml
