#!/bin/bash
cd $(dirname "$0") || exit
sleep 15

logfile="../logs.txt"

# podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')
full_podname=$(kubectl get pod -o name --selector app=loadgenerator )
podname="${full_podname#*/}"
echo load generator podname = $podname

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
DEBUG_FREQUENCY=5 # 20% of time

echo waiting for loadgenerator to be ready...                 | tee -a $logfile
kubectl wait --timeout=1h --for=condition=Ready pod/$podname
sleep 1
echo loadgenerator ready. Time elapsed = $SECONDS seconds.    | tee -a $logfile
echo                                                          | tee -a $logfile

# Start port-forwarding Prometheus service 
echo "Starting port-forward to Prometheus..."
# kubectl wait --timeout=1h --for=condition=Ready svc/prometheus
kubectl port-forward svc/prometheus 9090:80 &
PF_PID=$!

SECONDS=0

# usage: get_lines [num lines = 1]
get_lines () {
  kubectl logs --tail ${1:-1} $podname
}

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

write_cpu_util () {
  cores=$(./get_cores.sh)
  echo $SECONDS,$cores >> ../benchmark/stats/cpu.csv
}

log_debug_info() {  
  local val=$1

  if [ $(( val % $DEBUG_FREQUENCY )) -eq 0 ]; then

    # echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
  
    # kubectl logs -l="serviceweaver/name=$mainpod"
    # echo
    date -d@$SECONDS -u +%H:%M:%S
    kubectl top pod
    echo
    ./get_replicas.sh
    ./get_replicas.sh 1 >pod_stats.csv
    echo
    
    # echo "=*=*=*=*=*=*=*=*= END DEBUG. =*=*=*=*=*=*=*=*="

  fi
}

timestamp="[$(date +'%a %h %d %T %Y')] "
reprint="\e[1A\e[K"

iterations=0

str=$(get_lines)
size=${#str}
echo $str
last_str=""
# while [ $size -le 5 ] || [ $size -ge 20 ]; do
while [ $SECONDS -le $INITIAL_RUNTIME ]; do
  write_cpu_util
  
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

# Wait a few seconds for port-forward to be established.
sleep 30

# List of metrics to query.
metrics=(
  "serviceweaver_http_request_count"
  "serviceweaver_http_request_latency_micros_bucket"
  "serviceweaver_method_count"
  "serviceweaver_method_bytes_request_bucket"
  "serviceweaver_method_bytes_reply_bucket"
  "serviceweaver_method_latency_micros_bucket"
)

# Create an output directory for JSON files.
output_dir="../metrics_collection"
mkdir -p "${output_dir}"

# Query each metric and save the output into separate JSON files.
for metric in "${metrics[@]}"; do
  echo "Querying metric: ${metric}"
  curl -s "http://localhost:9090/api/v1/query?query=${metric}" -o "${output_dir}/${metric}.json"
done

# Terminate the port-forward process.
echo "Terminating port-forward..."
kill "${PF_PID}"

python3 ../benchmark/prometheus_metrics.py \
  "${output_dir}/serviceweaver_http_request_count.json" \
  "${output_dir}/serviceweaver_method_bytes_reply_sum.json" \
  "${output_dir}/serviceweaver_method_bytes_request_sum.json" \
  "${output_dir}/serviceweaver_method_count.json"


echo "All metric data collected and compiled in the '${output_dir}' directory."

echo done.
