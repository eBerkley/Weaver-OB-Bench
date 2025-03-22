#!/bin/bash
cd $(dirname "$0") || exit
sleep 15

logfile="../logs.txt"
STATS_DIR="../benchmark/stats"
mkdir -p "$STATS_DIR"

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

mainpod=$(kubectl get deploy | grep '[mM]ain' | head -1 | awk '{print $1}')
if [[ -z "$mainpod" ]]; then
  mainpod=$(kubectl get deploy | grep 'all' | head -1 | awk '{print $1}')
  if [[ -z "$mainpod" ]]; then
    mainpod=$(kubectl get deploy | grep 'front' | head -1 | awk '{print $1}')
  fi
fi

SECONDS=0
debug_frequency=4 # 25% of time

echo "Waiting for loadgenerator to be ready..." | tee -a $logfile
kubectl wait --timeout=1h --for=condition=Ready pod/$podname
sleep 1
echo "Loadgenerator ready. Time elapsed = $SECONDS seconds." | tee -a $logfile
echo | tee -a $logfile



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

# Helper functions
get_lines() {
  kubectl logs --tail "${1:-1}" "$podname"
}

write_cpu_util() {
  cores=$(./get_cores.sh)
  echo "$SECONDS,$cores" >> "$STATS_DIR/cpu.csv"
}

log_debug_info() {
  local val=$1
  if [ $(( val % $debug_frequency )) -eq 0 ]; then
    date -d@$SECONDS -u +%H:%M:%S
    kubectl top pod
  fi
}

fetch_jaeger_traces () {
  CURRENT_TIME=$(($(date +%s%N)/1000))  # Current time in microseconds
  JAEGER_API_URL="http://localhost:${LOCAL_PORT}/api/traces?service=${SERVICE_NAME}"
  TIMESTAMP=$(date +'%Y%m%d_%H%M%S')  # Unique timestamp for the file name
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

timestamp="[$(date +'%a %h %d %T %Y')] "
reprint="\e[1A\e[K"

iterations=0
str=$(get_lines)
size=${#str}
last_str=""
while [ $size -le 5 ] || [ $size -ge 20 ]; do
  write_cpu_util
  fetch_jaeger_traces
  sleep 10

  strs=$(get_lines 2)
  str=$(echo "$strs" | tail -1)
  strPrev=$(echo "$strs" | head -1)
  size=${#str}

  if [[ $strPrev != $last_str ]]; then
    echo -e $timestamp$strPrev
    echo $strPrev >> $logfile   

    if [[ $str != $last_str ]]; then
      echo $str
      echo $str >> $logfile
    fi

  elif [[ $str != $last_str ]]; then
    echo -e  $timestamp$str
    echo $str >> $logfile
  fi

  last_str=$str
  
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

echo "Done."

