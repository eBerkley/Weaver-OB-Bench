#!/bin/bash

# Runs for INITIAL_RUNTIME seconds, and then collects the following metrics:
# p99/p50 service latency for all components
# p99/p50 request latency (not from load generator)
# 
echo runtime_metrics_stats.sh

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
  
  # Only try to handle the first interrupt. 
  # If we receive more, give up.
  if [[ $terminate = "false" ]]; then
    terminate=true
    kill "${PF_PID}" 2>/dev/null
    wait "${PF_PID}" 2>/dev/null
    kubectl cp $podname:/stats ../benchmark/stats
    mv pod_stats.csv ../benchmark/stats/pod_stats.csv
  fi
  
  exit 0
}

trap finish EXIT SIGINT SIGTERM

SECONDS=0

loadgen_wait

SECONDS=0
# Start port-forwarding Prometheus service 
echo "Starting port-forward to Prometheus..."
# kubectl wait --timeout=1h --for=condition=Ready svc/prometheus
kubectl port-forward svc/prometheus 9090:80 >/dev/null &
PF_PID=$!

METRIC_URL="http://localhost:9090"

SECONDS=0

mkdir -p ../metrics_collection/$SCHEME
METRICS_DIR="../metrics_collection/$SCHEME"

for c in main cartcache productcatalogservice adservice cartservice checkoutservice currencyservice emailservice paymentservice recservice shippingservice; do
  
  echo "timestamp,p50_us,p99_us,MPS,Replicas,Util,External Concurrence,Internal Concurrence,Errors Per Sec" > "$METRICS_DIR/$c.csv"

done

fetch_value() {
    local url="$1"
    local value=$(curl -s "$url" | jq -r '.data.result[0].value[1]')
    if [[ "$value" == "null" || -z "$value" ]]; then
        sleep 1
        value=$(curl -s "$url" | jq -r '.data.result[0].value[1]')
        if [[ "$value" == "null" || -z "$value" ]]; then
            echo "No data for $url after retry."
            return 1
        fi
    fi
    echo "$value"
    return 0
}

# Fetch total MPS for the component
fetch_mps() {
    local component_name=$1
    local component_path="${COMPONENT_MAP[$component_name]}"

    if [[ "$component_name" == "main" ]]; then
        local raw_query="sum(rate(serviceweaver_http_request_count[30s]))"
    else
        local raw_query="sum(rate(serviceweaver_method_count{component=\"${component_path}\"}[30s]))"
    fi

    local encoded_query=$(jq -rn --arg q "$raw_query" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
    local url="$METRIC_URL/api/v1/query?query=$encoded_query"
    local value=$(curl -s "$url" | jq -r '.data.result[0].value[1]')
    if [[ "$value" == "null" || -z "$value" ]]; then
        # echo "0"
        echo "$value"
    else
        echo "$value"
    fi
}

fetch_concurrence () {
  
  local component_name=$1
  local component_path="${COMPONENT_MAP[$component_name]}"

  if [[ "$component_name" == "main" ]]; then
    local external_suffix="{component=\"github.com/eBerkley/weaver/Main\"}"
    local internal_suffix="{component=\"github.com/eBerkley/weaver/Main\"}"
  else
    local external_suffix="{caller!=\"*\",component=\"${component_path}\"}"
    local internal_suffix="{caller=\"*\",component=\"${component_path}\"}"
  fi

  local external_raw_query="sum(serviceweaver_started_method_count${external_suffix}) - sum(serviceweaver_finished_method_count${external_suffix})"
  local internal_raw_query="sum(serviceweaver_started_method_count${internal_suffix}) - sum(serviceweaver_finished_method_count${internal_suffix})"
  
  local external_encoded_query=$(jq -rn --arg q "$external_raw_query" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
  local internal_encoded_query=$(jq -rn --arg q "$internal_raw_query" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
  local external_url="$METRIC_URL/api/v1/query?query=$external_encoded_query"
  local internal_url="$METRIC_URL/api/v1/query?query=$internal_encoded_query"

  local external_value=$(curl -s "$external_url" | jq -r '.data.result[0].value[1]')
  local internal_value=$(curl -s "$internal_url" | jq -r '.data.result[0].value[1]')
  # if [[ "$external_value" == "null" || -z "$external_value" ]]; then # Assume we would have the same problem
    echo "$external_value" #| tee -a $logfile
    echo "$internal_value" #| tee -a $logfile
  # else
    # echo "$value"
  # fi
}

fetch_util() {
  local comp_name=$1
  local fname='pod_stats.csv'
  local pattern='[a-z\-]+,([0-9]+),[0-9]+m,([0-9]+m)'
  line="$(grep -E "^$comp_name" $fname 2>/dev/null)"
  # echo fetch_util: comp_name=$comp_name, line=$line >>$logfile
  if [[ $line  =~ $pattern ]]; then
    echo ${BASH_REMATCH[1]}
    echo ${BASH_REMATCH[2]}
  else
    echo "NaN"
    echo "NaN"
  fi
}

fetch_p99() {
  local comp_name=$1
  local component_path="${COMPONENT_MAP[$comp_name]}"
  local query_base
  if [[ "$comp_name" == "main" ]]; then
    query_base="serviceweaver_http_request_latency_micros_bucket"
  else
    query_base="serviceweaver_method_latency_micros_bucket{component=\"${component_path}\"}"
  fi
  local query="histogram_quantile(0.99, sum by (le) (rate(${query_base}[30s])))"
  local encoded=$(jq -rn --arg q "$query" '$q|@uri')
  fetch_value "$METRIC_URL/api/v1/query?query=$encoded"
}

fetch_p50() {
  local comp_name=$1
  local component_path="${COMPONENT_MAP[$comp_name]}"
  local query_base
  if [[ "$comp_name" == "main" ]]; then
    query_base="serviceweaver_http_request_latency_micros_bucket"
  else
    query_base="serviceweaver_method_latency_micros_bucket{component=\"${component_path}\"}"
  fi
  local query="histogram_quantile(0.50, sum by (le) (rate(${query_base}[30s])))"
  local encoded=$(jq -rn --arg q "$query" '$q|@uri')
  fetch_value "$METRIC_URL/api/v1/query?query=$encoded"
}

fetch_errors() {
  local component_name=$1
    local component_path="${COMPONENT_MAP[$component_name]}"
  
    if [[ "$component_name" == "main" ]]; then
        local raw_query="sum(rate(serviceweaver_http_error_count[30s]))"
    else
        local raw_query="sum(rate(serviceweaver_method_error_count{component=\"${component_path}\"}[30s]))"
    fi

    local encoded_query=$(jq -rn --arg q "$raw_query" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
    local url="$METRIC_URL/api/v1/query?query=$encoded_query"
    local value=$(curl -s "$url" | jq -r '.data.result[0].value[1]')
    if [[ "$value" == "null" || -z "$value" ]]; then
        # echo "0"
        echo "$value"
    else
        echo "$value"
    fi
}

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

log_debug_info() {  
  local val=$1

  if [ $(( val % 3 )) -eq 0 ]; then

    # echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
  
    # kubectl logs -l="serviceweaver/name=$mainpod"
    # echo
    realtime=$(date --iso-8601=seconds)
    # date -d@$SECONDS -u +%H:%M:%S
    echo $realtime
    echo
    ./get_replicas.sh
    code=$?
    if [[ $code = 0 ]]; then
      ./get_replicas.sh 1 >pod_stats.csv
      echo
    else
      rm -f pod_stats.csv
    fi
    
    for c in main cartcache productcatalogservice adservice cartservice checkoutservice currencyservice emailservice paymentservice recservice shippingservice; do

      local P99_VAL=$(fetch_p99 $c)
      if [[ $? -ne 0 ]]; then
        echo "$P99_VAL Invalid P99 value. Retrying..."
        return 0
      fi
      local P50_VAL=$(fetch_p50 $c)
      if [[ $? -ne 0 ]]; then
        echo "$P50_VAL Invalid P50 value. Retrying..."
        return 0
      fi

      local MPS=$(fetch_mps $c)
      repls_util=$(fetch_util $c)
      util=$(echo "$repls_util" | tail -n 1)
      repls=$(echo "$repls_util" | head -n 1)
      concurrency="$(fetch_concurrence $c)"
      ext=$(echo "$concurrency" | head -n 1)
      int=$(echo "$concurrency" | tail -n 1)

      eps=$(fetch_errors $c)

      P99=$(awk "BEGIN {printf \"%.3f\", $P99_VAL}")
      P50=$(awk "BEGIN {printf \"%.3f\", $P50_VAL}")
      MPS=$(awk "BEGIN {printf \"%.3f\", $MPS}")
      EPS=$(awk "BEGIN {printf \"%.3f\", $eps}")
      echo "$realtime,$P50,$P99,$MPS,$repls,$util,$ext,$int,$EPS" >> "$METRICS_DIR/$c.csv"
    done
    
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


# metric_no_sys () {
#   local metric=$1
#   new_metric="rate($metric{component!=\"github.com/eberkley/weaver/weaveletControl\",component!=\"github.com/eberkley/weaver/deployerControl\"}[$FINAL_METRICS_DURATION])"
#   jq -rn --arg q "$new_metric" '$q|@uri'
# }

# get_service_percentile () {
#   local percentile=$1
#   metric="histogram_quantile($percentile, sum(rate(serviceweaver_method_latency_micros_bucket{component!=\"github.com/eberkley/weaver/weaveletControl\",component!=\"github.com/eberkley/weaver/deployerControl\"}[$FINAL_METRICS_DURATION])) by (component, le))"
#   jq -rn --arg q "$metric" '$q|@uri'
# }

# get_http_percentile () {
#   local percentile=$1
#   metric="histogram_quantile($percentile, sum(rate(serviceweaver_http_request_latency_micros_bucket[$FINAL_METRICS_DURATION])) by (label, le))"
#   jq -rn --arg q "$metric" '$q|@uri'
# }

# get_internal_percentile () {
#   local percentile=$1
#   local metric="histogram_quantile($percentile, sum(rate(serviceweaver_internal_method_latency_micros_bucket[$FINAL_METRICS_DURATION])) by (component, method, le))"
#   jq -rn --arg q "$metric" '$q|@uri'
  
# }

# get_internal_aggregate_percentile () {
#   local percentile=$1
#   local metric="histogram_quantile($percentile, sum(rate(serviceweaver_internal_method_latency_micros_bucket[$FINAL_METRICS_DURATION])) by (component, le))"
#   jq -rn --arg q "$metric" '$q|@uri'
# }


# # "serviceweaver_http_request_count_bucket"
# # "serviceweaver_http_request_latency_micros_bucket"
# # "serviceweaver_method_latency_micros_bucket"

# # Create an output directory for JSON files.
# output_dir="../metrics_collection"
# mkdir -p "${output_dir}"

# query_metric () {
#   local name=$1
#   local metric=$2
#   curl -s "http://localhost:9090/api/v1/query?query=${metric}" -o "${output_dir}/${name}.json"
# }

# # Query each metric and save the output into separate JSON files.

# query_metric "request_counts" $(jq -rn --arg q "sum(rate(serviceweaver_http_request_count[$FINAL_METRICS_DURATION])) by (label)" '$q|@uri')
# query_metric "serviceweaver_method_count" $(metric_no_sys "serviceweaver_method_count")
# query_metric "serviceweaver_method_bytes_request_sum" $(metric_no_sys "serviceweaver_method_bytes_request_sum")
# query_metric "serviceweaver_method_bytes_reply_sum" $(metric_no_sys "serviceweaver_method_bytes_reply_sum")  






# p99_service_latency="$(get_service_percentile 0.99)"
# p50_service_latency="$(get_service_percentile 0.50)"
# p99_request_latency="$(get_http_percentile 0.99)"
# p50_request_latency="$(get_http_percentile 0.50)"

# query_metric "p99_service_latency" $p99_service_latency
# query_metric "p50_service_latency" $p50_service_latency
# query_metric "p99_request_latency" $p99_request_latency
# query_metric "p50_request_latency" $p50_request_latency


# query_metric "p99_internal_latency" "$(get_internal_percentile 0.99)"
# query_metric "p50_internal_latency" "$(get_internal_percentile 0.50)"

# query_metric "p99_internal_aggregate_latency" "$(get_internal_aggregate_percentile 0.99)"
# query_metric "p50_internal_aggregate_latency" "$(get_internal_aggregate_percentile 0.50)"

# # Terminate the port-forward process.
# echo "Terminating port-forward..."
# kill "${PF_PID}"

# python3 ../benchmark/prometheus_metrics.py \
#   "${output_dir}/request_counts.json" \
#   "${output_dir}/serviceweaver_method_bytes_reply_sum.json" \
#   "${output_dir}/serviceweaver_method_bytes_request_sum.json" \
#   "${output_dir}/serviceweaver_method_count.json"\
#   "${output_dir}/p50_service_latency.json"\
#   "${output_dir}/p99_service_latency.json"\
#   "${output_dir}/p50_request_latency.json"\
#   "${output_dir}/p99_request_latency.json"\
#   "${output_dir}/p50_internal_latency.json"\
#   "${output_dir}/p99_internal_latency.json"\
#   "${output_dir}/p50_internal_aggregate_latency.json"\
#   "${output_dir}/p99_internal_aggregate_latency.json"

# echo "All metric data collected and compiled in the '${output_dir}' directory."

# echo done.

finish
