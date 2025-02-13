#!/bin/bash

CORES_PER_SOCKET=36 # Change!!
# What is allocated to kubernetes runtime?
KUBE_CORES=${KUBE_CORES:-"0-2"} # Should start with 0.

KUBE_RESERVED=$(( $(echo $KUBE_CORES | sed -E "s/[0-9]+-//g") + 1 )) # 0-2 => 3

locust_inc=$KUBE_RESERVED
OB_inc=$CORES_PER_SOCKET

all_pods="$(kubectl get po -o name)"

bind_pod() {
  local pod_name=$1
  local cores=$2
  local proc_name=$3

  kubectl exec "$pod_name" --stdin -- /bin/bash <<EOF
    taskset -cp $cores 1
    pgrep -f "$proc_name" | xargs -I % taskset -cp $cores %
EOF
}

IFS=$'\n'
for pod in $all_pods; do
  echo $pod
  # continue

  if [[ $(echo $pod | grep loadgenerator) ]] ; then
    bind_pod $pod $locust_inc locust
    (( locust_inc += 1 ))

  else

    OB_inc=$(( locust_inc > OB_inc ? locust_inc : OB_inc ))
    
    bind_pod $pod $OB_inc "/weaver/ob"
    (( OB_inc += 1 ))
  fi
done