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

#---------------------------------------
# Start port-forwarding Prometheus service 
echo "Starting port-forward to Prometheus..."
# kubectl wait --timeout=1h --for=condition=Ready svc/prometheus
kubectl port-forward svc/prometheus 9090:80 &
PF_PID=$!

METRIC_URL="http://localhost:9090"
INTERVAL=20
SLO_FACTOR=20.0

COMPONENT_NAME="${1:-main}"
COMPONENT_NAME="$(echo "$COMPONENT_NAME" | tr '[:upper:]' '[:lower:]')"

declare -A COMPONENT_MAP=(
    [main]=""
    [cartcache]="github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService"
    [productcatalogservice]="github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService"
    [adservice]="github.com/eBerkley/Weaver-OB-Bench/adservice/AdService"
    [cartservice]="github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService"
    [checkoutservice]="github.com/eBerkley/Weaver-OB-Bench/checkoutservice/CheckoutService"
    [currencyservice]="github.com/eBerkley/Weaver-OB-Bench/currencyservice/CurrencyService"
    [emailservice]="github.com/eBerkley/Weaver-OB-Bench/emailservice/EmailService"
    [paymentservice]="github.com/eBerkley/Weaver-OB-Bench/paymentservice/PaymentService"
    [recommendationservice]="github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService"
    [shippingservice]="github.com/eBerkley/Weaver-OB-Bench/shippingservice/ShippingService"
)

COMPONENT_PATH="${COMPONENT_MAP[$COMPONENT_NAME]}"
if [[ -z "$COMPONENT_PATH" && "$COMPONENT_NAME" != "main" ]]; then
    echo "Unknown component or typo: $COMPONENT_NAME"
    exit 1
fi

# Build Prometheus queries
if [[ "$COMPONENT_NAME" == "main" ]]; then
    QUERY_BASE="serviceweaver_http_request_latency_micros_bucket"
else
    QUERY_BASE="serviceweaver_method_latency_micros_bucket{component=\"${COMPONENT_PATH}\"}"
fi

QUERY_P99="histogram_quantile(0.99, sum by (le) (rate(${QUERY_BASE}[30s])))"
QUERY_P50="histogram_quantile(0.50, sum by (le) (rate(${QUERY_BASE}[30s])))"

ENCODED_P99=$(jq -rn --arg q "$QUERY_P99" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
ENCODED_P50=$(jq -rn --arg q "$QUERY_P50" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')

# CSV initialization
CSV_FILE="../benchmark/stats/latency_MPS_${COMPONENT_NAME}.csv"
echo "timestamp,p50_us,p99_us,MPS" > "$CSV_FILE"

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

# Monitoring loop
P99=0
P50=0
#---------------------------------------

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
  P99=$P99_VAL
  P50=$P50_VAL

  MPS=$(fetch_mps)

  P99=$(awk "BEGIN {printf \"%.3f\", $P99_VAL}")
  P50=$(awk "BEGIN {printf \"%.3f\", $P50_VAL}")
  MPS=$(awk "BEGIN {printf \"%.3f\", $MPS}")

  # Log to console
  echo "P99: $P99 µs | P50: $P50 µs | MPS: $MPS"

  # Write to Component latency CSV
  realtime=$(date --iso-8601=seconds)
  echo "$realtime,$P50,$P99,$MPS" >> "$CSV_FILE"


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
  "serviceweaver_method_bytes_request_sum"
  "serviceweaver_method_bytes_reply_sum"
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

