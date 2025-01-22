#!/bin/bash

cd $(dirname $0)

print_usage() {
  echo sudo ./utils/vtune.sh username [flags]
  echo "-h, --help              print this help message."
  #echo "-n=, --name=[r]         base name for each analysis result."
  echo "-s=, --scheme=          only output this scheme."
  echo "-g=, --group=           only output this group."
  echo "-c=, --cores=           only output this #cores."
  echo "-f, --frontend          report frontend bound instructions."
  echo "-b, --backend           report backend bound instructions."
  echo "--retiring=[true]       collect info on retiring instructions."
  echo "--bad-spec=[true]       collect info on bad speculation."
  echo "--mem-bound=[true]      collect info on memory bound instructions."
  echo "--core-bound=[true]     collect info on core bound instructions."
}

longest_title=0

get_metric() {
  filename="$1"
  metric="$2"
  grep $filename -e "$metric" | awk -F ',' '{print $3}'
}

for scheme in $(ls vtune_results); do
  if [[ -n $scheme_req ]] && [[ $scheme != $scheme_req ]]; then continue; fi
  
  for group in $(ls vtune_results/$scheme); do
    if [[ -n $group_req ]] && [[ $group != $group_req ]]; then continue; fi
    
    for cores in $(ls vtune_results/$scheme/$group); do
      if [[ -n $cores_req ]] && [[ $cores != $cores_req ]]; then continue; fi

      title=$scheme-$group-$cores

      title_len=${#title}
      if [[ $title_len -ge $longest_title ]]; then
        longest_title=$title_len
      fi

    done
  done
done

echo name, cpi, icache misses, frontend bound, backend bound, retiring, instructions retired

for scheme in $(ls vtune_results); do
  if [[ -n $scheme_req ]] && [[ $scheme != $scheme_req ]]; then continue; fi
  
  for group in $(ls vtune_results/$scheme); do
    if [[ -n $group_req ]] && [[ $group != $group_req ]]; then continue; fi
    
    for cores in $(ls vtune_results/$scheme/$group); do
      if [[ -n $cores_req ]] && [[ $cores != $cores_req ]]; then continue; fi

      # if [[ $cores != "1" ]]; then continue; fi

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

      frontend=$(get_metric $filename "Front-End Bound")
      backend=$(get_metric $filename "Back-End Bound")
      retiring=$(get_metric $filename "Retiring")
      retired=$(get_metric $filename "Instructions Retired")
      echo $cpi, $icache_misses, $frontend, $backend, $retiring, $retired
      
    done
  done
done