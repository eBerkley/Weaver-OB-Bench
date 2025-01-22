#!/bin/bash
cd $(dirname $0)

print_usage() {
  echo sudo ./utils/report.sh [username] [flags]
  echo "-h, --help              print this help message."
  echo "-m, --mode=<mode>       set which vtune report type to use. Defaults to summary."
  echo "-q, --query             for each scheme/group/cores dir found, ask user which report to use."
  echo "                        otherwise, uses last alphabetical."
  echo "-s, --scheme=<scheme>   only use reports with this scheme."
  echo "-g, --group=<group>     only use reports with this group."
  echo "-c, --cores=<cores>     only use reports with this #cores."
  exit 0
}

ask=0
for i in "$@"
do
case $i in
    -m=*|--mode=*)
    mode="${i#*=}"

    ;;
    -q|--query)
    ask=1
    
    ;;
    -h|--help)
    print_usage
    ;;

    -s=*|--scheme=*)
    scheme_req="${i#*=}"
    ;;

    -g=*|--group=*)
    group_req="${i#*=}"
    ;;

    -c=*|--cores=*)
    cores_req="${i#*=}"
    ;;

    *)
    username=$i
    ;;
esac
done


mode=${mode:-summary}
echo $ask
echo $mode

source /opt/intel/oneapi/vtune/latest/vtune-vars.sh
result_dir=/opt/intel/oneapi/vtune/vtune_results/analyze_pod

for a in $(ls $result_dir); do 
  
  scheme=$(echo $a | awk -F '-' '{print $1}')
  group=$(echo $a | awk -F '-' '{print $2}')
  cores=$(echo $a | awk -F '-' '{print $3}')
  
  if [[ -n $scheme_req ]] && [[ $scheme_req != $scheme ]]; then continue; fi
  if [[ -n $group_req ]] && [[ $group_req != $group ]]; then continue; fi
  if [[ -n $cores_req ]] && [[ $cores_req != $cores ]]; then continue; fi
 
  if [[ $ask = "1" ]]; then
    echo $a
    i=0
    for l in $(ls $result_dir/$a ); do
      i=$(( $i+1 ))
      echo $i: $l
    done
    read linenum
    
    # if [[ $linenum = "0" ]]; then continue; fi

    result_name=$(ls $result_dir/$a | sed -n "$linenum"p 2>/dev/null )
    if [[ -z $result_name ]]; then
      echo skipped...
      echo
      continue
    fi
  else
    result_name=$(ls $result_dir/$a | tail -1)
  fi

  echo vtune_results/$scheme/$group/$cores/"$result_name"_"$mode".csv
  
  mkdir -p vtune_results/$scheme/$group/$cores
  vtune -report $mode -r $result_dir/$a/$result_name -format=csv -csv-delimiter=comma -report-output=vtune_results/$scheme/$group/$cores/"$result_name"_"$mode".csv
  
  if [[ -n $username ]]; then
    chown $username vtune_results/$scheme/$group/$cores/"$result_name"_"$mode".csv
  fi
  
done