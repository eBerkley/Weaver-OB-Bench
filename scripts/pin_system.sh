#!/bin/bash

KUBE_CORES=${KUBE_CORES:-"0-2"} # Should start with 0.

echo "Binding Kubernetes system components to cores: $KUBE_CORES"

# Function to bind all PIDs of a given process name
bind_process() {
  local process_name=$1
  local pids=$(pgrep -f $process_name)  # Use -f to match full command line
  
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      original_affinity=$(taskset -cp $pid | awk '{print $NF}')
      echo "Binding $process_name (PID: $pid) to cores $KUBE_CORES"

      sudo taskset -cp $KUBE_CORES $pid
      
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
