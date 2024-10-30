#!/bin/bash

# if docker isn't running, nothing gets written to stdout or stderr

for s in all carts front mainad checkoutemailpay adservice cartservice checkoutservice currencyservice emailservice main paymentservice productcatalogservice shippingservice; do

  replicas=$(kubectl get pod 2>/dev/null | grep $s | wc -l) 
  if [[ $replicas -ne 0 ]]; then
    echo $s: $replicas
  fi

done