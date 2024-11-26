#!/bin/bash
cd $(dirname $0)

source /opt/intel/oneapi/vtune/latest/vtune-vars.sh
result_dir=/opt/intel/oneapi/vtune/vtune_results/analyze_pod
for a in $(ls $result_dir); do 
  echo $a; 
  scheme=$(echo $a | awk -F '-' '{print $1}')
  group=$(echo $a | awk -F '-' '{print $2}')
  cores=$(echo $a | awk -F '-' '{print $3}')
  echo vtune_results/$scheme/$group/$cores/r000ue.csv
  # ls $result_dir/$a

  result_name=$(ls $result_dir/$a | tail -1)
  echo $result_name
  mkdir -p vtune_results/$scheme/$group/$cores
  vtune -report summary -r $result_dir/$a/r@@@ue -format=csv -csv-delimiter=comma -report-output=vtune_results/$scheme/$group/$cores/$result_name.csv
  chown $1 vtune_results/$scheme/$group/$cores/$result_name.csv
done