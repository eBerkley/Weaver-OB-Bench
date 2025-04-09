#!/bin/bash
cd $(dirname "$0") || exit
sleep 15
echo pull_stats.sh
source stats_utils/all_stats.sh


echo load generator podname = $podname

rm -f 'pod_stats.csv'

finish () {
  kubectl cp $podname:/stats ../benchmark/stats
  mv pod_stats.csv ../benchmark/stats/pod_stats.csv
}

trap finish EXIT

loadgen_wait

SECONDS=0

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv


log_debug_info() {  
  local val=$1

  if [ $(( val % $DEBUG_FREQUENCY )) -eq 0 ]; then

    # echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
    
    date -d@$SECONDS -u +%H:%M:%S
    
    ./get_replicas.sh
    code=$?
    if [[ $code = 0 ]]; then
      ./get_replicas.sh 1 >pod_stats.csv
      echo
    else
      rm -f pod_stats.csv
    fi
    
    # echo "=*=*=*=*=*=*=*=*= END DEBUG. =*=*=*=*=*=*=*=*="

  fi
}

iterations=0

strs=$(get_lines $timestamp_file 3)
str=$(echo "$strs" | tail -1)
size=${#str}
echo $strs

# usage: loop_continue SIZE
#   we should terminate => echo 0
#   else => echo 1
if [[ $LOCUST_SHAPE = 'scaleload' ]]; then
  loop_continue () {
    local size=$1

    if [[ $(./check_capacity.sh 2>> $logfile) = 1 ]]; then
      echo we are at capacity. Preparing to terminate... >&2
      echo 0
    else

      if [[ $size -gt 5 ]] && [[ $size -lt 28 ]]; then
        echo 0
        echo we are not at capacity, but size = $size. Preparing to terminate... >&2
      else 
        echo 1
      fi
    
    fi
  }

else
  loop_continue () {
    local size=$1

    if [[ $size -gt 5 ]] && [[ $size -lt 31 ]]; then
      echo size = $size. Preparing to terminate... >&2
      echo 0
    else
      echo 1
    fi
  }

fi

continue_result=$(loop_continue $size)
while [[ $continue_result = 1 ]]; do
  write_cpu_util
  
  sleep 10
  strs=$(get_lines $timestamp_file 3)
  str=$(echo "$strs" | tail -1)
  size=${#str}
  if [[ $size != 0 ]]; then echo "$strs" | tee -a $logfile; fi
  
  
  (( iterations+=1 ))
  log_debug_info $iterations >> $logfile
  continue_result=$(loop_continue $size)

done

if [[ $SECONDS -lt 150 ]]; then
  # We assume if we terminated within a minute, something wrong happened.
  # We wait a while to let user debug before killing everything off.
  # Should never affect regular load tests.
  echo Terminated after only "$SECONDS"s. assuming something wrong happened. >&2
  echo Sleeping for 1k seconds. Use this time to debug the problem, and then manually terminate the test. >&2
  
  sleep 1000
fi

echo done.

# Calls `finish` on exit.