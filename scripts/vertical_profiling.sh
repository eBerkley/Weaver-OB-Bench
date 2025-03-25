#!/bin/bash

# usage: ./vertical_profiling.sh adservice

# User could the SLO_FACTOR, STABILITY_COUNT and Query Time window as adjustment of methodogoly
# Set P99 > SLO_FACTOR * P50 as SLO violation, If the P99/P50 ratio keeps exceeding the SLO_FACTOR more than 
# the threshold which is defined by STABILITY_COUNT then we terminate the profiling

cd $(dirname "$0") || exit
sleep 15

logfile="../logs.txt"

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

SECONDS=0

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
    # kubectl top pod
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

  fi
}
iterations=0
#----------------------------------

METRIC_URL="http://localhost:9090"
INTERVAL=20
SLO_FACTOR=20.0
COMPONENT_NAME="${1:-main}"
COMPONENT_NAME="$(echo "$COMPONENT_NAME" | tr '[:upper:]' '[:lower:]')"
STABILITY_COUNT=3

declare -A COMPONENT_MAP=(
    [main]=""
    [cartCache]="github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService"
    [ProductCatalogService]="github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService"
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

if [[ "$COMPONENT_NAME" == "main" ]]; then
    QUERY_BASE="serviceweaver_http_request_latency_micros_bucket"
else
    QUERY_BASE="serviceweaver_method_latency_micros_bucket"
    LABEL_FILTER="{component=\"${COMPONENT_PATH}\"}"
    QUERY_BASE="${QUERY_BASE}${LABEL_FILTER}"
fi

# Raw queries
QUERY_P99="histogram_quantile(0.99, sum by (le) (rate(${QUERY_BASE}[30s])))"
QUERY_P50="histogram_quantile(0.50, sum by (le) (rate(${QUERY_BASE}[30s])))"

# Encode entire query, but preserve parentheses
ENCODED_P99=$(jq -rn --arg q "$QUERY_P99" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')
ENCODED_P50=$(jq -rn --arg q "$QUERY_P50" '$q|@uri' | sed 's/%28/(/g; s/%29/)/g')

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


P99=0
P50=1

COUNTER=$STABILITY_COUNT

while [[ "$COUNTER" -gt 0 ]]; do
    P99_VAL=$(fetch_value "$METRIC_URL/api/v1/query?query=$ENCODED_P99")
    if [[ $? -ne 0 ]]; then
        echo " $P99_VAL"
        echo " Invalid P99 value. Retrying again..."
        sleep 1
        continue
    fi

    P50_VAL=$(fetch_value "$METRIC_URL/api/v1/query?query=$ENCODED_P50")
    if [[ $? -ne 0 ]]; then
        echo " Invalid P50 value. Retrying again..."
        sleep 1
        continue
    fi

    write_cpu_util
    (( iterations+=1 ))
    log_debug_info $iterations >> $logfile
    # Assign only if values are valid
    P99=$P99_VAL
    P50=$P50_VAL

    ratio=$(awk "BEGIN {print $P99 / $P50}")
    echo "P99: $P99 µs | P50: $P50 µs, Ratio (P99 / P50): $ratio"

    violation=$(awk "BEGIN {print ($ratio > $SLO_FACTOR) ? 1 : 0}")
    if [[ "$violation" -eq 1 ]]; then
        ((COUNTER--))
        echo "SLO violation detected. Remaining tolerance: $COUNTER"
        # if [[ "$COUNTER" -le 0 ]]; then
        #     echo "SLO Violation: ratio exceeded $SLO_FACTOR for $STABILITY_COUNT consecutive times"
        #     break
        # fi
    else
        COUNTER=$STABILITY_COUNT
    fi

    sleep $INTERVAL
done

echo "Profiling terminated"

