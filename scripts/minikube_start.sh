#!/bin/bash


flags=""

flags+=' --feature-gates=CPUManagerPolicyAlphaOptions=true'
flags+=' --extra-config=kubelet.cpu-manager-policy-options=align-by-socket=true'

flags+=' --cpus=max'

flags+=' --extra-config=kubelet.cpu-manager-policy=static'
flags+=" --extra-config=kubelet.reserved-cpus=${KUBE_CORES:-0}"


minikube start $flags

minikube addons enable metrics-server
sleep 30

