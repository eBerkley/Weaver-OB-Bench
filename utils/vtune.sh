#!/bin/bash
cd $(dirname $0)

username=$1 # needed...

if [[ $UID -ne 0 ]]; then
  echo error: must run as root.
  exit
fi

if [[ -z $username ]]; then
  echo usage: sudo vtune.sh username
  exit
fi

PROFILE_TIME=180
ANALYSIS_TYPE=uarch-exploration

source ../.env

source /opt/intel/oneapi/vtune/latest/vtune-vars.sh
result_dir=/opt/intel/oneapi/vtune/vtune_results/analyze_pod

uset() {
  sudo -u $username $*
}

uset kubectl delete all --all

wait_constload() {
  str=$(uset kubectl logs --tail 1 -l app=loadgenerator)
  size=${#str}
  echo $str
  local reprint_str="\e[1A\e[K"
  while [ $size -ge 90 ]; do 
    str=$(uset kubectl logs --tail 1 -l app=loadgenerator)
    size=${#str}
    echo -e $reprint_str$str
    sleep 10
  done
}

for cfg in ../cfgs/*; do
  source $cfg
  echo $SCHEME-$OB_CORES
  # Deploy...
  uset cp $cfg ../CONFIG.cfg
  uset make -C .. deploy
  uset kubectl wait po -l app=loadgenerator --for=condition=Ready
  
  # Wait until constload shape has hit constant rps
  wait_constload
  
  # Begin profiling.
  # for p in $(pgrep -f "/weaver/ob"); do
  # :/
  for p in $(pgrep -f "/weaver/ob" | xargs --no-run-if-empty ps | awk '{print $1}' | tail -n +2); do
    echo $p
    # will be something like 'HOSTNAME=ob-all-8huhsds-y8h23urh...'
    hostname=$(cat /proc/$p/environ | strings | grep HOSTNAME)
    
    # Extract the 'all' part of 'HOSTNAME=ob-all-8huhsds-y8h23urh...'
    fusion_group=$(echo $hostname | gawk 'match($0, /=ob-([^-]*)/, a) {print a[1]}')

    # Get set of cores this process runs under
    cpus=$(cat /proc/$p/status | grep Cpus_allowed_list | awk '{print $2}')

    # the dir that this run will go to. Will be the same for collecting and reporting.
    specific_result_dir="$result_dir/$SCHEME-$fusion_group-$OB_CORES/r@@@{at}"

    # Run using hw sampling
    collect_flags=" -knob sampling-mode=hw"
    
    # Set how long until it terminates
    collect_flags+=" --duration=$PROFILE_TIME"
    
    # Add src files
    collect_flags+=" -source-search-dir=../src"
    
    # Add binary 
    collect_flags+=" -search-dir=../release/generated"
    
    # enable stack collection
    collect_flags+=" -knob enable-stack-collection=true"
    
    # put the collected metrics in a specific dir
    collect_flags+=" -r $specific_result_dir"
    
    # Only collect metrics on cpus proc runs on
    # collect_flags+=" -cpu-mask $cpus"
    
    echo
    echo Executing vtune $ANALYSIS_TYPE on $SCHEME-$fusion_group-$OB_CORES...
    echo 

    # Collect specified metrics on process using flags specified
    vtune -collect $ANALYSIS_TYPE $collect_flags  -target-pid=$p

    result_name=$(ls $result_dir/$SCHEME-$fusion_group-$OB_CORES | tail)

    uset mkdir -p vtune_results/$SCHEME/$fusion_group/$OB_CORES/$ANALYSIS_TYPE
    
    vtune -report $ANALYSIS_TYPE -r $specific_result_dir -format=csv > vtune_results/$SCHEME/$fusion_group/$OB_CORES/$ANALYSIS_TYPE/$result_name.csv
  done # p
  
  # once all pods have been profiled, stop this deployment.
  uset kubectl delete all --all

done # cfg
