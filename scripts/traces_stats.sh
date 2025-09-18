#!/bin/bash
cd $(dirname "$0") || exit
sleep 15

echo traces_stats.sh

STATS_DIR="../benchmark/stats"
mkdir -p "$STATS_DIR"

# Get vars / fns for all stat collecters
source stats_utils/all_stats.sh

# Detect the load generator pod name
full_podname=$(kubectl get pod -o name --selector app=loadgenerator)
podname="${full_podname#*/}"
echo "Load generator podname = $podname"

rm -f 'pod_stats.csv'

finish () {
  kubectl cp $podname:/stats ../benchmark/stats
  mv pod_stats.csv ../benchmark/stats/pod_stats.csv
}

trap finish EXIT

SECONDS=0
debug_frequency=4 # 25% of time

loadgen_wait


if [ -d "../jaeger_traces" ]; then
    # If the directory exists, remove it
    rm -rf "../jaeger_traces"
fi

# Create the directory (whether it was removed or not)
mkdir -p "../jaeger_traces"


# Start Kubernetes port forwarding for Jaeger
JAEGER_SERVICE_NAME="jaeger"
JAEGER_NAMESPACE="default"
LOCAL_PORT=16686
FETCH_INTERVAL=10
# OUTPUT_FILE="../jaeger_traces/traces.json"
OUTPUT_DIR="../jaeger_traces"
SERVICE_NAME="ob"           # Service to filter traces

echo "Starting Kubernetes port forwarding for Jaeger..."
kubectl port-forward svc/${JAEGER_SERVICE_NAME} -n ${JAEGER_NAMESPACE} ${LOCAL_PORT}:16686 &
PORT_FORWARD_PID=$!
trap "echo 'Stopping port forwarding...'; kill ${PORT_FORWARD_PID}; exit" INT TERM

LAST_FETCH_TIME=$(($(date +%s%N)/1000))  # Current time in microseconds


SECONDS=0

log_debug_info() {
  local val=$1
  if [ $(( val % $debug_frequency )) -eq 0 ]; then
    date -d@$SECONDS -u +%H:%M:%S
    kubectl top po 2>/dev/null | awk 'NR==1 || $1 !~ /^loadgenerator/'
    echo
    ./get_replicas.sh
    code=$?
    if [[ $code = 0 ]]; then
      ./get_replicas.sh 1 >pod_stats.csv
      echo
    else
      rm -f pod_stats.csv
    fi
  fi
}

fetch_jaeger_traces () {
  CURRENT_TIME=$(($(date +%s%N)/1000))  # Current time in microseconds
  JAEGER_API_URL="http://localhost:${LOCAL_PORT}/api/traces?service=${SERVICE_NAME}"
  TIMESTAMP=$(date --iso-8601=seconds)  # Unique timestamp for the file name
  FETCH_FILE="${OUTPUT_DIR}/traces_${TIMESTAMP}.json"  # File name based on the timestamp

  # Fetch the data
  curl -X GET -s "${JAEGER_API_URL}" > "$FETCH_FILE"

  if [[ $? -eq 0 ]]; then
    if [[ -s "$FETCH_FILE" ]]; then
      echo "Fetched traces and saved to $FETCH_FILE."
    else
      echo "No new traces found in this fetch."
      rm -f "$FETCH_FILE"  # Remove empty file
    fi
  else
    echo "Failed to fetch traces at $(date)."
    rm -f "$FETCH_FILE"  # Remove file on failure
  fi

  LAST_FETCH_TIME=$CURRENT_TIME  # Update last fetch time
}



# Main loop
echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

strs=$(get_lines $timestamp_file 30)
str=$(echo "$strs" | tail -1)
size=${#str}
echo "$strs" | tee -a $logfile

while [ $size -le 5 ] || [ $size -ge 20 ]; do
  write_cpu_util
  fetch_jaeger_traces
  sleep 10
  strs=$(get_lines $timestamp_file 8)
  str=$(echo "$strs" | tail -1)
  size=${#str}
  if [[ $size != 0 ]]; then echo "$strs" | tee -a $logfile; fi

  (( iterations+=1 ))
  log_debug_info $iterations >> $logfile

done

if [[ $SECONDS -lt 150 ]]; then
  # We assume if we terminated within a minute, something wrong happened.
  # We wait a while to let user debug before killing everything off.
  # Should never affect regular load tests.
  echo Terminated after only "$SECONDS"s. assuming something wrong happened. >&2
  echo Sleeping for 1k seconds. Use this time to debug the problem, and then manually terminate the test. >&2
  
  sleep 1000
fi

Echo "Post-processing jaeger traces..."
python3 ../benchmark/jaeger_trace.py "${OUTPUT_DIR}"

# rm -rf "${OUTPUT_DIR}"/*.json

echo "Done."

