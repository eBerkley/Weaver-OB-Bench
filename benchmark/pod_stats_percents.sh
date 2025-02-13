#!/bin/bash
cd $(dirname $0)/..

test_name=$1
file_path=benchmark/out/$test_name/stats/pod_stats.csv
out_path=benchmark/out/$test_name/stats/pod_stats_percents.tsv

if [[ ! -r $file_path ]]; then
  echo "Error: can not locate pod stats for test ($test_name) at $file_path" >&2
  exit 1
fi

print_tab () {
  str="$1"
  spacing="$2"
  strlen=${#str}

  printf "$str"
    for i in $(seq 1 $(( $spacing - $strlen ))); do
      printf " "
  done  
}
TITLE_PADDING=25
REPLICAS_PADDING=10
CPU_PADDING=25


printf "" > $out_path

csv_pattern="([a-z_ ]+),([0-9]+),([0-9]+)m,([0-9]+)m"

IFS=$'\n'


for line in $(cat $file_path); do
  if [[ $line =~ $csv_pattern ]]; then
    name=${BASH_REMATCH[1]}
    replicas=${BASH_REMATCH[2]}
    total_util=${BASH_REMATCH[3]}
    avg_util=${BASH_REMATCH[4]}
    
    total_percent=$(echo "scale=1; $total_util/10"|bc)%%
    avg_percent=$(echo "scale=1; $avg_util/10"|bc)%%

    print_tab $name $TITLE_PADDING        >> $out_path
    print_tab $replicas $REPLICAS_PADDING >> $out_path
    print_tab $total_percent $CPU_PADDING >> $out_path
    print_tab $avg_percent $CPU_PADDING   >> $out_path
    echo                                  >> $out_path

    # echo "$name,$replicas,$total_percent,$avg_percent" >> $out_path
  else
    # We assume we are talking about line 1.
    print_tab Podname $TITLE_PADDING                >> $out_path
    print_tab Replicas $REPLICAS_PADDING            >> $out_path
    print_tab "Total CPU Utilization" $CPU_PADDING  >> $out_path
    print_tab "Avg CPU Utilization" $CPU_PADDING    >> $out_path
    echo                                            >> $out_path

    # echo ${line::-1} >> $out_path
  fi

done