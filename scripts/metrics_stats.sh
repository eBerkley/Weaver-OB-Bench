#!/bin/bash

# Runs for INITIAL_RUNTIME seconds, and then collects the following metrics:
# p99/p50 service latency for all components
# p99/p50 request latency (not from load generator)
# 

cd $(dirname "$0") || exit
sleep 15

FINAL_METRICS_DURATION=${FINAL_METRICS_DURATION:-60s}

# Get vars / fns for all stat collecters
source stats_utils/all_stats.sh

echo load generator podname = $podname

rm -f 'pod_stats.csv'
# Add this at the top
terminate=false

# Modify the trap handler to set the flag and still call finish
finish () {
  echo "Caught interrupt. Finishing up..."
  terminate=true
  kill "${PF_PID}" 2>/dev/null
  wait "${PF_PID}" 2>/dev/null
  kubectl cp $podname:/stats ../benchmark/stats
  mv pod_stats.csv ../benchmark/stats/pod_stats.csv
  exit 0
}

trap finish EXIT SIGINT SIGTERM

SECONDS=0

loadgen_wait

SECONDS=0
# Start port-forwarding Prometheus service 
echo "Starting port-forward to Prometheus..."
# kubectl wait --timeout=1h --for=condition=Ready svc/prometheus
kubectl port-forward svc/prometheus 9090:80 &
PF_PID=$!

SECONDS=0

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

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

iterations=0

# str=$(get_lines $timestamp_file)
# size=${#str}
# echo $str

strs=$(get_lines $timestamp_file 3)

str=$(echo "$strs" | tail -1)
size=${#str}
if [[ $size != 0 ]]; then echo "$strs" | tee -a $logfile; fi

while [[ $size -lt 5 ]] || [[ $size -gt 28 ]]; do
  if [ "$terminate" = true ]; then
    echo "Termination requested. Breaking loop."
    break
  fi
  
  write_cpu_util
  
  sleep 10
  strs=$(get_lines $timestamp_file 3)
  str=$(echo "$strs" | tail -1)
  size=${#str}
  # echo "DEBUG: str='$str'"
  # echo "DEBUG: size=$size"

  if [[ $size != 0 ]]; then echo "$strs" | tee -a $logfile; fi
  
  (( iterations+=1 ))
  log_debug_info $iterations >> $logfile
  
done


metric_no_sys () {
  local metric=$1
  new_metric="rate($metric{component!=\"github.com/eberkley/weaver/weaveletControl\",component!=\"github.com/eberkley/weaver/deployerControl\"}[$FINAL_METRICS_DURATION])"
  jq -rn --arg q "$new_metric" '$q|@uri'
}

get_service_percentile () {
  local percentile=$1
  metric="histogram_quantile($percentile, sum(rate(serviceweaver_method_latency_micros_bucket{component!=\"github.com/eberkley/weaver/weaveletControl\",component!=\"github.com/eberkley/weaver/deployerControl\"}[$FINAL_METRICS_DURATION])) by (component, le))"
  jq -rn --arg q "$metric" '$q|@uri'
}

get_http_percentile () {
  local percentile=$1
  metric="histogram_quantile($percentile, sum(rate(serviceweaver_http_request_latency_micros_bucket[$FINAL_METRICS_DURATION])) by (label, le))"
  jq -rn --arg q "$metric" '$q|@uri'
}

get_internal_percentile () {
  local percentile=$1
  local metric="histogram_quantile($percentile, sum(rate(serviceweaver_internal_method_latency_micros_bucket[$FINAL_METRICS_DURATION])) by (component, method, le))"
  jq -rn --arg q "$metric" '$q|@uri'
  
}

get_internal_aggregate_percentile () {
  local percentile=$1
  local metric="histogram_quantile($percentile, sum(rate(serviceweaver_internal_method_latency_micros_bucket[$FINAL_METRICS_DURATION])) by (component, le))"
  jq -rn --arg q "$metric" '$q|@uri'
}


# "serviceweaver_http_request_count_bucket"
# "serviceweaver_http_request_latency_micros_bucket"
# "serviceweaver_method_latency_micros_bucket"

# Create an output directory for JSON files.
output_dir="../metrics_collection"
mkdir -p "${output_dir}"

query_metric () {
  local name=$1
  local metric=$2
  curl -s "http://localhost:9090/api/v1/query?query=${metric}" -o "${output_dir}/${name}.json"
}

# Query each metric and save the output into separate JSON files.

query_metric "request_counts" $(jq -rn --arg q "sum(rate(serviceweaver_http_request_count[$FINAL_METRICS_DURATION])) by (label)" '$q|@uri')
query_metric "serviceweaver_method_count" $(metric_no_sys "serviceweaver_method_count")
query_metric "serviceweaver_method_bytes_request_sum" $(metric_no_sys "serviceweaver_method_bytes_request_sum")
query_metric "serviceweaver_method_bytes_reply_sum" $(metric_no_sys "serviceweaver_method_bytes_reply_sum")  






p99_service_latency="$(get_service_percentile 0.99)"
p50_service_latency="$(get_service_percentile 0.50)"
p99_request_latency="$(get_http_percentile 0.99)"
p50_request_latency="$(get_http_percentile 0.50)"

query_metric "p99_service_latency" $p99_service_latency
query_metric "p50_service_latency" $p50_service_latency
query_metric "p99_request_latency" $p99_request_latency
query_metric "p50_request_latency" $p50_request_latency


query_metric "p99_internal_latency" "$(get_internal_percentile 0.99)"
query_metric "p50_internal_latency" "$(get_internal_percentile 0.50)"

query_metric "p99_internal_aggregate_latency" "$(get_internal_aggregate_percentile 0.99)"
query_metric "p50_internal_aggregate_latency" "$(get_internal_aggregate_percentile 0.50)"

# Terminate the port-forward process.
echo "Terminating port-forward..."
kill "${PF_PID}"

python3 ../benchmark/prometheus_metrics.py \
  "${output_dir}/request_counts.json" \
  "${output_dir}/serviceweaver_method_bytes_reply_sum.json" \
  "${output_dir}/serviceweaver_method_bytes_request_sum.json" \
  "${output_dir}/serviceweaver_method_count.json"\
  "${output_dir}/p50_service_latency.json"\
  "${output_dir}/p99_service_latency.json"\
  "${output_dir}/p50_request_latency.json"\
  "${output_dir}/p99_request_latency.json"\
  "${output_dir}/p50_internal_latency.json"\
  "${output_dir}/p99_internal_latency.json"\
  "${output_dir}/p50_internal_aggregate_latency.json"\
  "${output_dir}/p99_internal_aggregate_latency.json"

echo "All metric data collected and compiled in the '${output_dir}' directory."

echo done.

finish
