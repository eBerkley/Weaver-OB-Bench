#!/bin/bash

CORES_PER_SOCKET=36 # Change!!
# What is allocated to kubernetes runtime?
KUBE_CORES=${KUBE_CORES:-"0-2"} # Should start with 0.


KUBE_RESERVED=$(( $(echo $KUBE_CORES | sed -E "s/[0-9]+-//g") + 1 )) # 0-2 => 3

locust_inc=$KUBE_RESERVED
OB_inc=$CORES_PER_SOCKET

DEBUG_MODE=$1

echo "Binding Kubernetes system components to cores: $KUBE_CORES"

# Function to bind all PIDs of a given process name
bind_process() {
  local process_name=$1
  local pids=$(pgrep -f $process_name)  # Use -f to match full command line
  
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      original_affinity=$(taskset -cp $pid | awk '{print $NF}')
      echo "Binding $process_name (PID: $pid) to cores $KUBE_CORES"
      if [[ -z $DEBUG_MODE ]]
      then sudo taskset -cp $KUBE_CORES $pid
      else sudo taskset -cp $pid; fi

      echo
    done
  else
    echo "Warning: No running process found for $process_name"
  fi
}

bind_process "kube-apiserver"
bind_process "kube-controller-manager"
bind_process "kube-scheduler"
bind_process "etcd"
bind_process "kube-proxy"
bind_process "coredns"
bind_process "storage-provisioner"
bind_process "metrics-server"

echo "Binding current process \$\$ (PID: $$) to cores $KUBE_CORES"
taskset -cp $KUBE_CORES $$

for p in $(pgrep -f "locust"); do
  cores=$(taskset -cp $p | awk '{print $NF}')
  
  if [[ -z $DEBUG_MODE ]]; then 
    
    sudo taskset -cp $locust_inc $p > /dev/null
    cores2=$(taskset -cp $p | awk '{print $NF}')
    echo loadgen \($p\) : $cores '-->' $cores2

    (( locust_inc += 1 ))

  else 

    echo loadgen \($p\) : $cores

  fi
done

OB_inc=$(( locust_inc > CORES_PER_SOCKET ? locust_inc : CORES_PER_SOCKET ))

for p in $(pgrep -f "/weaver/ob"); do
  cores=$(taskset -cp $p | awk '{print $NF}')
  hostname=$(sudo cat /proc/$p/environ | strings | grep HOSTNAME)
  fusion_group=$(echo $hostname | gawk 'match($0, /=ob-([^-]*)/, a) {print a[1]}')

  if [[ -z $DEBUG_MODE ]]; then 
    ppid=$(ps -o ppid= $p )

    sudo taskset -cp $OB_inc $p > /dev/null
    sudo taskset -cp $OB_inc $ppid > /dev/null


    cores2=$(taskset -cp $p | awk '{print $NF}')
    (( OB_inc += 1 ))
    echo $fusion_group \($p\) : $cores '-->' $cores2
  else

    echo $fusion_group \($p\) : $cores
  
  fi


done
