#!/bin/bash

# Check if the script is run as root
# If not, re-run the script with sudo
if [[ $UID -ne 0 ]]; then
  sudo $0 $USER "$@"
  exit $?
fi


# Check if pod name is provided
if [ -z "$2" ]; then
  echo "Usage: $0 <pod-name>"
  exit 1
fi


username=$1
POD_NAME=$2

uset() {
  sudo -u $username PATH="$PATH:/home/$username/go/bin" $*
}

PROFILE_TIME=60
# mode=hotspots


# if [[ ! -e "/opt/intel/oneapi/vtune/latest/vtune-vars.sh" ]]; then
#   echo "VTune is not installed. Please install VTune to use this script."
#   exit 1
# fi

# source /opt/intel/oneapi/vtune/latest/vtune-vars.sh
# result_dir=/opt/intel/oneapi/vtune/vtune_results/analyze_pod

# create the result directory if it doesn't exist
# mkdir -p "$result_dir"


# Check if the pod exists
if ! uset kubectl get pod "$POD_NAME" &>/dev/null; then
  echo "Error: Pod '$POD_NAME' not found."
  exit 1
fi

OLD_VALUE=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Original kernel.perf_event_paranoid: $OLD_VALUE"
echo "Temporarily lowering kernel.perf_event_paranoid to -1..."
sysctl -w kernel.perf_event_paranoid=-1

cleanup () {
  sysctl -w kernel.perf_event_paranoid=$OLD_VALUE
}

trap cleanup SIGINT SIGTERM

OUTPUT_DIR="vtune_results"
mkdir -p "$OUTPUT_DIR"

for p in $(pgrep -f "/weaver/ob" | xargs --no-run-if-empty ps | awk '{print $1}' | tail -n +2); do
  hostname=$(cat /proc/$p/environ | strings | grep HOSTNAME)

  # Extract the pod name from the hostname
  if [[ $hostname =~ ^HOSTNAME=(.*) ]]; then
    hostname=${BASH_REMATCH[1]}
  else
    echo "Error: Unable to extract hostname from /proc/$p/environ"
    continue
  fi
  
  if [[ $hostname != $POD_NAME ]]; then
    # echo "Skipping pod: $hostname"
    continue
  fi

  echo "Profiling pod: $hostname"
  stat_output_file="$OUTPUT_DIR/${hostname}_stats.txt"
  record_output_file="$OUTPUT_DIR/${hostname}_record.data"
  
  # perf stat -o "$stat_output_file" \
        # -e instructions,cycles,L1-icache-load-misses \
        # -p "$p" 

  echo "Starting perf record for PID $p (Pod: $pod_name). Output: $record_output_file"
  perf record -o "$record_output_file" \
        -e instructions \
        -p "$p" &
  perf_pid=$!

  sleep $PROFILE_TIME

  kill -SIGINT "$perf_pid" 2>/dev/null
  wait "$perf_pid" 2>/dev/null
  
  echo "Perf record completed for PID $p (Pod: $pod_name). Output: $record_output_file"

  echo "Starting perf stat for PID $p (Pod: $pod_name). Output: $stat_output_file"
  perf stat -o "$stat_output_file" \
        -e instructions,cycles,L1-icache-load-misses \
        -p "$p" &

  perf_pid=$!
  
  sleep $PROFILE_TIME
  kill -SIGINT "$perf_pid" 2>/dev/null
  wait "$perf_pid" 2>/dev/null

  echo "Perf stat completed for PID $p (Pod: $pod_name). Output: $stat_output_file"

  chown -R $username "$OUTPUT_DIR"
  break

done


cleanup
