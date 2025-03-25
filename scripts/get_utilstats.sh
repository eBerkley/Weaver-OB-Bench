#!/bin/bash

# Get CPU usage from all pods and format into a readable or CSV format

pod_list=$(kubectl top po 2>/dev/null)
if [[ ${#pod_list} -lt 10 ]]; then 
  echo "Error: pod list too short or metrics not available." >&2
  exit 1
fi

CSV_MODE=$1
declare -A max_cpu_map
declare -A pod_order_counter_map
declare -A replica_order_map

print_header() {
  if [[ -z $CSV_MODE ]]; then
    printf "%-25s %-45s %-10s %-12s %-5s\n" "Podname" "Replica" "CPU (m)" "Max CPU (m)" "Order"
  else
    echo "Podname,Replica,CPU (m),Max CPU (m),Order"
  fi
}

print_row() {
  if [[ -z $CSV_MODE ]]; then
    printf "%-25s %-45s %-10s %-12s %-5s\n" "$1" "$2" "$3" "$4" "$5"
  else
    echo "$1,$2,$3,$4,$5"
  fi
}

# Extract a meaningful podname group from full replica name
shorten_podname() {
  full="$1"
  if [[ "$full" == loadgenerator* ]]; then
    echo "loadgenerator"
  elif [[ "$full" =~ ^ob-([a-z]+)service.*$ ]]; then
    echo "${BASH_REMATCH[1]}service"
  elif [[ "$full" =~ ^ob-([a-z]+).* ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$full" | sed -E 's/-[a-z0-9]{8,}$//' | sed -E 's/-[a-z0-9]{8,}$//'
  fi
}

entries=()

while IFS= read -r line; do
  pod=$(echo "$line" | awk '{print $1}')
  raw_cpu=$(echo "$line" | awk '{print $2}')
  [[ -z "$pod" || -z "$raw_cpu" ]] && continue

  # Normalize CPU (convert to millicores)
  if [[ "$raw_cpu" == *m ]]; then
    cpu="${raw_cpu::-1}"
  else
    cpu=$(awk "BEGIN { printf(\"%d\", $raw_cpu * 1000) }")
  fi

  short_name=$(shorten_podname "$pod")

  # Update max CPU per pod group
  prev_max=${max_cpu_map[$short_name]:-0}
  if (( cpu > prev_max )); then
    max_cpu_map[$short_name]=$cpu
  fi

  # Assign replica order per group
  key="$short_name/$pod"
  if [[ -z "${replica_order_map[$key]}" ]]; then
    ((pod_order_counter_map[$short_name]++))
    replica_order_map[$key]=${pod_order_counter_map[$short_name]}
  fi

  entries+=("$short_name|$pod|${cpu}m|${max_cpu_map[$short_name]}m|${replica_order_map[$key]}")
done <<< "$(echo "$pod_list" | tail -n +2)"

# Apply custom sort weight
weighted_entries=()
for entry in "${entries[@]}"; do
  podname=$(cut -d'|' -f1 <<< "$entry")

  if [[ "$podname" == "loadgenerator" ]]; then
    weight="00"
  elif [[ "$podname" == "main" ]]; then
    weight="99"
  else
    weight="50"
  fi

  weighted_entries+=("$weight|$entry")
done

# Sort by weight, then by podname
IFS=$'\n' sorted=($(printf "%s\n" "${weighted_entries[@]}" | sort -t'|' -k1,1 -k2,2))
unset IFS

# Print result
print_header
for entry in "${sorted[@]}"; do
  entry="${entry#*|}"  # Remove weight prefix
  IFS='|' read -r podname replica cpu max_cpu order <<< "$entry"
  print_row "$podname" "$replica" "$cpu" "$max_cpu" "$order"
done
