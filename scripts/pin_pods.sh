#!/bin/bash

CORES_PER_SOCKET=36 # Change!!


# What is allocated to kubernetes runtime?
KUBE_CORES=${KUBE_CORES:-"0-2"} # Should start with 0.

KUBE_RESERVED=$(( $(echo $KUBE_CORES | sed -E "s/[0-9]+-//g") + 1 )) # 0-2 => 3

locust_inc=$KUBE_RESERVED
OB_inc=$CORES_PER_SOCKET


C_SCHEME=${C_SCHEME:-"1core"}

all_pods="$(kubectl get po -o name)"

bind_pod() {
  local pod_name=$1
  local cores=$2
  local proc_name=$3
  # Explanation:
  # Exec into pod, pass next two lines to bash:
  #   set the root process to run on specified cores
  #   find processID as it appears in pod's pid namespace, 
  #     then set it to run on those cores too.
  kubectl exec "$pod_name" --stdin -- /bin/bash <<EOF
    taskset -cp $cores 1 
    pgrep -f "$proc_name" | xargs -I % taskset -cp $cores %
EOF
}

# Used with OB pods.
# if we are allocing 3 cores, and OB_inc is 37, return "37,38,39"
# also sets OB_inc to 39. Needs to be set to 40 by code below.
core_string() {
  local cores=$1
  local out_str=OB_inc
  for i in $(seq 2 $cores); do 
    (( OB_inc += 1 ))
    out_str+=",$OB_inc"
  done
  echo $out_str
}

IFS=$'\n'

for pod in $(echo "$all_pods" | grep loadgenerator); do
  bind_pod $pod $locust_inc locust
  (( locust_inc += 1 ))
done

#################
# OB BINDINGS!! #
#################
OB_inc=$(( locust_inc > OB_inc ? locust_inc : OB_inc ))

CSCHEME_PATH="release/base/colocation/$SCHEME/$C_SCHEME.cfg"
pattern="([a-z_\-]+)=([0-9]+)"
for alloc in $(cat $CSCHEME_PATH); do
  if [[ $alloc =~ $pattern ]]; then
    pod_name=${BASH_REMATCH[1]}
    cores=${BASH_REMATCH[2]}
    for pod in $(echo "$all_pods" | grep $pod_name); do

      bind_pod $pod $(core_string $cores) "/weaver/ob"
      (( OB_inc += 1 ))
    
    done
  fi
done

