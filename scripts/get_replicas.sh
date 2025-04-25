#!/bin/bash

#################################################################################
# Use `kubectl top po` to get #replicas, cumulative cpu utilization, 
# and average cpu utilization for each of the loadgen workers and OB pods.
# if running this command with a parameter (e.g. `./scripts/get_replicas.sh 1`), 
# output will be formatted in csv form.
# Otherwise, it will be formatted as equally spaced tabs.
#################################################################################



# if docker isn't running, nothing gets written to stdout or stderr
# If metrics-server isn't available yet, it'll say in stderr
pod_list=$(kubectl top po 2>/dev/null)
# pod_list=$(cat scripts/sample.txt) # Used for testing when developing this script.

if [[ ${#pod_list} < 10 ]]; then 
  exit 1
fi

CSV_MODE=$1

if [[ -z $CSV_MODE ]]; then
  print_tab () {
    str="$1"
    spacing="$2"
    strlen=${#str}

    printf "$str"
      for i in $(seq 1 $(( $spacing - $strlen ))); do
        printf " "
    done
    
  }
else
  print_tab () {
    str="$1"
    #spacing="$2"
    printf "$str,"
  }
fi

TITLE_PADDING=25
REPLICAS_PADDING=10
CPU_PADDING=30
print_tab Podname $TITLE_PADDING
print_tab Replicas $REPLICAS_PADDING
print_tab "Total CPU Utilization" $CPU_PADDING
print_tab "Avg CPU Utilization" $CPU_PADDING
echo

ob_replicas=0
ob_util=0


for s in loadgenerator all all-but-main carts front back mainad checkoutemailpay adservice cartservice cartcache checkoutservice currencyservice emailservice main paymentservice productcatalogservice shippingservice recservice maincurrency checkship emailpaycache checkemailpaycache maincheck mainproduct mainrec recproduct largefront maincartsvc all-but-product all-but-stateful maincurrencycartsvc maincurrencycarts maincarts checkcurrency checkrec checkcartsvc maincurrencycheck maincheckship monocheck maincurrencyad; do
  if [[ $s = "loadgenerator" ]]; then
    pod_str="loadgenerator-worker"
  else
    pod_str="ob-$s-[a-z0-9]{8}"
  fi

  replicas=$(echo "$pod_list" | grep -P $pod_str) 
  
  num_replicas=$(echo "$pod_list" | grep -P $pod_str | wc -l)

  if [[ $num_replicas = 0 ]]; then continue; fi

  # echo $num_replicas
  usage=0
  for i in $(seq 1 $num_replicas); do
    _replica_usage=$(echo "$replicas" | sed -n "$i p" | awk '{print $2}' )
    replica_usage=${_replica_usage::-1}
    (( usage += replica_usage ))
  done
  avg=$((usage / num_replicas))
  print_tab $s $TITLE_PADDING
  print_tab $num_replicas $REPLICAS_PADDING
  print_tab "$usage"m $CPU_PADDING
  print_tab "$avg"m $CPU_PADDING
  echo
  # echo $s: $num_replicas, "$usage"m
  if [[ $s != "loadgenerator" ]]; then
    ((ob_replicas += num_replicas))
    ((ob_util += usage))
  fi
done

if [[ $ob_replicas = 0 ]]; then
  exit 1
fi

if [[ -z $CSV_MODE ]]; then
  echo '-------------------------------------------------------------------------------------'
fi

print_tab "ob aggregate" $TITLE_PADDING
print_tab $ob_replicas $REPLICAS_PADDING
print_tab "$ob_util"m $CPU_PADDING
print_tab $((ob_util / ob_replicas))m $CPU_PADDING
echo