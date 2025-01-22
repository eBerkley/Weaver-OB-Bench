#!/bin/bash

# if docker isn't running, nothing gets written to stdout or stderr
pod_list=$(kubectl top po 2>/dev/null)
for s in all carts front mainad checkoutemailpay adservice cartservice cartcache checkoutservice currencyservice emailservice main paymentservice productcatalogservice shippingservice recservice; do
  pod_str="ob-$s-"
  
  replicas=$(echo "$pod_list" | grep $pod_str) 
  
  num_replicas=$(echo "$pod_list" | grep $pod_str | wc -l)
  # echo $num_replicas
  # for i in $(seq 1 $num_replicas); do
  #   replica_usage=$(echo "$lines" | sed -n "$i p" | awk '{print $2}' )
  # done

  if [[ $num_replicas -ne 0 ]]; then
    echo $s: $num_replicas
  fi

done