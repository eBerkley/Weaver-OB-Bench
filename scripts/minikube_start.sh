#!/bin/bash
cd $(dirname $0)

# ./stop.sh
# minikube delete


flags=""

flags+=' --feature-gates=CPUManagerPolicyAlphaOptions=true'
flags+=' --extra-config=kubelet.cpu-manager-policy-options=align-by-socket=true'

flags+=' --cpus=max'

flags+=' --extra-config=kubelet.cpu-manager-policy=static'
flags+=' --extra-config=kubelet.reserved-cpus=0'

# flags+=' --extra-config=kubelet.kube-reserved="{cpu: 200m, memory: 200Mi, ephemeral-storage: 1Gi, pid=1000}"'
# flags+=' --extra-config=kubelet.system-reserved="{cpu: 750m, memory: 1000Mi, ephemeral-storage: 1Gi, pid=1000}"'


minikube start $flags

minikube addons enable metrics-server
sleep 30


# minikube dashboard
# kubectl label nodes minikube type=master
# kubectl label nodes minikube-m02 type=worker
