#!/bin/bash

# With the assumption that this definition will only be used down a directory
export logfile="../logs.txt"

# podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')
full_podname=$(kubectl get pod -o name --selector app=loadgenerator )

export podname="${full_podname#*/}"

mainpod=$(kubectl get deploy | grep '[mM]ain' | head -1 | awk '{print $1}')
if [[ -z "$mainpod" ]]; then
  mainpod=$(kubectl get deploy | grep 'all' | head -1 | awk '{print $1}')
  if [[ -z "$mainpod" ]]; then
    mainpod=$(kubectl get deploy | grep 'front' | head -1 | awk '{print $1}')
  fi
fi

export mainpod

export DEBUG_FREQUENCY=5 # 20% of time

loadgen_wait () {
  SECONDS=0
  echo waiting for loadgenerator to be ready...                 | tee -a $logfile
  kubectl wait --timeout=1h --for=condition=Ready pod/$podname
  sleep 1
  echo loadgenerator ready. Time elapsed = $SECONDS seconds.    | tee -a $logfile
  echo                                                          | tee -a $logfile
}
export -f loadgen_wait

timestamp_file=$(mktemp)
echo 0 >$timestamp_file
echo $timestamp_file

rm_timestamp_file () {
  rm $timestamp_file
}

trap rm_timestamp_file EXIT

# usage: get_lines timestamp_file [num lines = 1]
get_lines () {
  local timestamp_file=$1
  local tail_lines=${2:-1}
  last_timestamp=$(cat $timestamp_file)
  local lines=$(kubectl logs --tail $tail_lines $podname)
  
  local first_new=$(echo "$lines" | wc -l)
  local ret_lines=0

  for i in $(seq 1 $first_new); do
    
    # loadgenerator logs are of the form "[yyyy-mm-dd hh:mm:ss,xxx]" where xxx is a number that increments with each log? I think...
    local cur_line=$(echo "$lines" | sed -n "$i p")
    local id=$(echo $cur_line | sed -nE 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},([0-9]{3})\][^\n]+/\1/p')
    if [[ $id = "" ]]; then
      ret_lines=$((first_new + 1 - i))
      break
    fi

    id="10#$id"
    # values like "039" don't seem to work without prefix because base interpretation.
    if ( [[ $id -gt $last_timestamp ]] \
        && [[ $(( id - last_timestamp )) -lt 750 ]] ) \
      || ([[ $id -lt 250 ]] \
        && [[  $last_timestamp -gt 750 ]]) || [[ $last_timestamp -eq 0 ]]; then
      
      ret_lines=$((first_new + 1 - i))
      break
    fi    
  done
  
  local last_line=$(echo "$lines" | tail -1)

  last_timestamp="10#$(echo $last_line | sed -nE 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},([0-9]{3})\][^\n]+/\1/p')"

  echo $last_timestamp >$timestamp_file
  # return all of the new lines
  echo "$lines" | tail -n $ret_lines # | sed -nE 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}\]([^\n]+)/\1/p'
}

export -f get_lines

write_cpu_util () {
  local cores=$(./get_cores.sh)
  echo $SECONDS,$cores >> ../benchmark/stats/cpu.csv
}

export -f write_cpu_util

export timestamp="[$(date +'%a %h %d %T %Y')] "

# -x flag makes declare export.
declare -Ax COMPONENT_MAP=(
    [main]=""
    [cartcache]="github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService"
    [productcatalogservice]="github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService"
    [adservice]="github.com/eBerkley/Weaver-OB-Bench/adservice/AdService"
    [cartservice]="github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService"
    [checkoutservice]="github.com/eBerkley/Weaver-OB-Bench/checkoutservice/CheckoutService"
    [currencyservice]="github.com/eBerkley/Weaver-OB-Bench/currencyservice/CurrencyService"
    [emailservice]="github.com/eBerkley/Weaver-OB-Bench/emailservice/EmailService"
    [paymentservice]="github.com/eBerkley/Weaver-OB-Bench/paymentservice/PaymentService"
    [recservice]="github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService"
    [shippingservice]="github.com/eBerkley/Weaver-OB-Bench/shippingservice/ShippingService"
)
