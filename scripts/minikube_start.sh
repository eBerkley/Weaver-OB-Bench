#!/bin/bash


flags=""
flags+=' --cpus=max'

if [[ $BENCH_STATIC = 0 ]]; then # If we are NOT static, let kubernetes handle pinning to cores.
  flags+=' --feature-gates=CPUManagerPolicyAlphaOptions=true'
  flags+=' --extra-config=kubelet.cpu-manager-policy-options=align-by-socket=true'
  flags+=' --extra-config=kubelet.cpu-manager-policy=static'
  flags+=" --extra-config=kubelet.reserved-cpus=${KUBE_CORES:-0}"
fi 

minikube start $flags

minikube addons enable metrics-server
