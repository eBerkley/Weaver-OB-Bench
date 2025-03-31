#!/bin/bash
cd $(dirname "$0") || exit
sleep 10

logfile="../logs.txt"


source stats_utils/all_stats.sh

echo load generator podname = $podname

rm -f 'pod_stats.csv'
finish () {
  kubectl cp $podname:/stats ../benchmark/stats
  mv pod_stats.csv ../benchmark/stats/pod_stats.csv
}

trap finish EXIT

SECONDS=0

#---------------------------------------
# Start port-forwarding Prometheus service 
echo "Starting port-forward to Prometheus..."
# kubectl wait --timeout=1h --for=condition=Ready svc/prometheus
kubectl port-forward svc/prometheus 9090:80 >/dev/null &
PF_PID=$!

METRIC_URL="http://localhost:9090"

COMPONENT_NAME="${FIXED:-main}"
COMPONENT_NAME="$(echo "$COMPONENT_NAME" | tr '[:upper:]' '[:lower:]')"
echo BENCHMARKING COMPONENT $COMPONENT_NAME | tee -a $logfile
COMPONENT_PATH="${COMPONENT_MAP[$COMPONENT_NAME]}"
if [[ -z "$COMPONENT_PATH" && "$COMPONENT_NAME" != "main" ]]; then
    echo "Unknown component or typo: $COMPONENT_NAME"
    exit 1
fi

parse_svc_latency () {
  local component=$1
  local path="../metrics_collection/p50_svc_latency.csv"
  local pattern="[^,]+,([0-9.]+)"

  if [[ $component = "" ]]; then
    component="github.com/eberkley/weaver/Main"
  fi

  local line=$(grep -e $component $path)
  if [[ $line =~ $pattern ]]; then
    val=${BASH_REMATCH[1]}
    echo $(awk "BEGIN {printf \"%.3f\", $val}")
  else
    echo "unable to parse line $line."
    return 1
  fi
}

parse_internal_latency () {
  local component=$1
  local path="../metrics_collection/internal_latency.csv"
  local pattern="[^,]+,*,([0-9.]+)"
  if [[ $component = "" ]]; then
    component="github.com/eBerkley/weaver/Main"
  fi

  for line in $(grep -e $component $path); do
    if [[ $line =~ $pattern ]]; then
      val=${BASH_REMATCH[1]}
      echo $(awk "BEGIN {printf \"%.3f\", $val}")
      return 0
    fi
  done
}

LOWLOAD_SVC_P50=$(parse_svc_latency $COMPONENT_PATH)
# LOWLOAD_SVC_P50=$(parse_internal_latency $COMPONENT_PATH)
if [[ $? -eq 1 ]]; then
  echo ERROR: $LOWLOAD_SVC_P50 | tee -a $logfile
  exit 1
fi
echo LOW LOAD P50 SVC LATENCY: $LOWLOAD_SVC_P50 | tee -a $logfile

SVC_SLO_FACTOR=${SVC_SLO_FACTOR:-15.0}
STABILITY_COUNT=12

# is_violating p99_latency
# Returns 1 if violating, 0 otherwise.
is_violating () {
  local p99=$1
  local ratio=$(awk "BEGIN {print $p99 / $LOWLOAD_SVC_P50}")
  awk "BEGIN {print ($ratio > $SVC_SLO_FACTOR) ? 1 : 0}"
}

# Build Prometheus queries
if [[ "$COMPONENT_NAME" == "main" ]]; then
    QUERY_BASE="serviceweaver_http_request_latency_micros_bucket"
else
    QUERY_BASE="serviceweaver_method_latency_micros_bucket{component=\"${COMPONENT_PATH}\"}"
fi

# if [[ "$COMPONENT_NAME" == "main" ]]; then
#   QUERY_BASE="serviceweaver_internal_method_latency_micros_bucket{component=\"github.com/eBerkley/weaver/Main\"}"
# else
#   QUERY_BASE="serviceweaver_internal_method_latency_micros_bucket{component=\"$COMPONENT_PATH\"}"
# fi

QUERY_P99="histogram_quantile(0.99, sum by (le) (rate(${QUERY_BASE}[30s])))"
QUERY_P50="histogram_quantile(0.50, sum by (le) (rate(${QUERY_BASE}[30s])))"

ENCODED_P99=$(jq -rn --arg q "$QUERY_P99" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
ENCODED_P50=$(jq -rn --arg q "$QUERY_P50" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')

# CSV initialization
csvdir=../vertical_profs/${COMPONENT_NAME}
mkdir -p $csvdir
CSV_FILE="${csvdir}/latency_MPS_${COMPONENT_NAME}_${FIXED_WIDTH}_${FIXED_HEIGHT}.csv"
echo "timestamp,p50_us,p99_us,MPS,util" > "$CSV_FILE"

# Fetch Prometheus value helper
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
    if [[ "$COMPONENT_NAME" == "main" ]]; then
        local raw_query="sum(rate(serviceweaver_http_request_count[30s]))"
    else
        local raw_query="sum(rate(serviceweaver_method_count{component=\"${COMPONENT_PATH}\"}[30s]))"
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

fetch_util() {
  local comp_name=$1
  local fname='pod_stats.csv'
  local pattern='[a-z\-]+,[0-9]+,[0-9]+m,([0-9]+m)'
  line="$(grep -E "^$comp_name" $fname 2>/dev/null)"
  # echo fetch_util: comp_name=$comp_name, line=$line >>$logfile
  if [[ $line  =~ $pattern ]]; then
    echo ${BASH_REMATCH[1]}
  else
    echo "NaN"
  fi
}

# Monitoring loop
P99=0
P50=0
#---------------------------------------

SECONDS=0

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

log_debug_info() {  
  local val=$1

  # if [ $(( val % $DEBUG_FREQUENCY )) -eq 0 ]; then

    # echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
  
    # kubectl logs -l="serviceweaver/name=$mainpod"
    # echo
    # date -d@$SECONDS -u +%H:%M:%S
    # echo
    ./get_replicas.sh
    code=$?
    if [[ $code = 0 ]]; then
      ./get_replicas.sh 1 >pod_stats.csv
      echo
    else
      rm -f pod_stats.csv
    fi
    
    # echo "=*=*=*=*=*=*=*=*= END DEBUG. =*=*=*=*=*=*=*=*="

  # fi
}

iterations=0

strs=$(get_lines $timestamp_file 3)

str=$(echo "$strs" | tail -1)
size=${#str}
if [[ $size != 0 ]]; then echo "$strs" | tee -a $logfile; fi

COUNTER=$STABILITY_COUNT

# If application saturates before component, that's a fine termination condition too.
while [ $COUNTER -gt 0 ] && ( [[ $size -lt 5 ]] || [[ $size -gt 28 ]] ); do
  strs=$(get_lines $timestamp_file 3)
  str=$(echo "$strs" | tail -1)
  size=${#str}
  if [[ $size != 0 ]]; then echo "$strs" | tee -a $logfile; fi

  P99_VAL=$(fetch_value "$METRIC_URL/api/v1/query?query=$ENCODED_P99")
  if [[ $? -ne 0 ]]; then
      echo "$P99VAL Invalid P99 value. Retrying..."
      sleep 10
      continue
  fi

  P50_VAL=$(fetch_value "$METRIC_URL/api/v1/query?query=$ENCODED_P50")
  if [[ $? -ne 0 ]]; then
      echo "Invalid P50 value. Retrying..."
      sleep 10
      continue
  fi
  
  # Note: here, log_debug_info ALWAYS runs. 
  # Because we want util constantly updating.
  log_debug_info $iterations >> $logfile

  P99=$P99_VAL
  P50=$P50_VAL

  MPS=$(fetch_mps)
  util=$(fetch_util $COMPONENT_NAME)

  P99=$(awk "BEGIN {printf \"%.3f\", $P99_VAL}")
  P50=$(awk "BEGIN {printf \"%.3f\", $P50_VAL}")
  MPS=$(awk "BEGIN {printf \"%.3f\", $MPS}")

  # Log to console
  echo "P99: $P99 µs | P50: $P50 µs | MPS: $MPS | util: $util "

  # Write to Component latency CSV
  realtime=$(date --iso-8601=seconds)
  echo "$realtime,$P50,$P99,$MPS,$util" >> "$CSV_FILE"

  write_cpu_util
  
  violation=$(is_violating $P99)
  if [[ "$violation" = "1" ]]; then
    ((COUNTER--))
    echo "SLO violation detected. Remaining tolerance: $COUNTER"
  else
    COUNTER=$STABILITY_COUNT
  fi

  sleep 10

  
  (( iterations+=1 ))
  
done

kill "${PF_PID}"

echo done.
