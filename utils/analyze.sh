#!/bin/bash

cd $(dirname $0)
longest_title=0

get_metric() {
  filename="$1"
  metric="$2"
  grep $filename -e "$metric" | awk -F ',' '{print $3}'
}

echo name, cpi, icache misses,frontend latency, backend latency
for scheme in $(ls vtune_results); do
  for group in $(ls vtune_results/$scheme); do
    for cores in $(ls vtune_results/$scheme/$group); do
      if [[ $cores != "1" ]]; then continue; fi
      
      latest=$(ls vtune_results/$scheme/$group/$cores | tail -1)

      title=$scheme-$group-$cores

      title_len=${#title}
      if [[ $title_len -ge $longest_title ]]; then
        longest_title=$title_len
      fi
      printf $title
      for i in $(seq 1 $(( $longest_title - $title_len ))); do
        printf " "
      done

      printf "  "


      filename="vtune_results/$scheme/$group/$cores/$latest"

      cpi=$(get_metric $filename "CPI Rate")
      
      icache_misses=$(get_metric $filename "ICache Misses")

      retiring=$(get_metric $filename "Retiring")
      frontend=$(get_metric $filename "Front-End Bound")
      backend=$(get_metric $filename "Back-End Bound")
      
      echo $cpi, $icache_misses, $retiring #$frontend, $backend
      
    done
  done
done