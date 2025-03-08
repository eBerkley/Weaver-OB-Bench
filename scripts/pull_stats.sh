#!/bin/bash
cd $(dirname "$0") || exit
sleep 15

logfile="../logs.txt"

full_podname=$(kubectl get pod -o name --selector app=loadgenerator )
podname="${full_podname#*/}"
echo load generator podname = $podname

rm -f 'pod_stats.csv'

finish () {
  kubectl cp $podname:/stats ../benchmark/stats
  mv pod_stats.csv ../benchmark/stats/pod_stats.csv
}

trap finish EXIT


mainpod=$(kubectl get deploy | grep '[mM]ain' | head -1 | awk '{print $1}')
if [[ -z "$mainpod" ]]; then
  mainpod=$(kubectl get deploy | grep 'all' | head -1 | awk '{print $1}')
  if [[ -z "$mainpod" ]]; then
    mainpod=$(kubectl get deploy | grep 'front' | head -1 | awk '{print $1}')
  fi
fi

SECONDS=0
DEBUG_FREQUENCY=5 # 20% of time

echo waiting for loadgenerator to be ready...                 | tee -a $logfile
kubectl wait --timeout=1h --for=condition=Ready pod/$podname
sleep 1
echo loadgenerator ready. Time elapsed = $SECONDS seconds.    | tee -a $logfile
echo                                                          | tee -a $logfile

SECONDS=0

# usage: get_lines [num lines = 1]
get_lines () {
  kubectl logs --tail ${1:-1} $podname
}

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

write_cpu_util () {
  cores=$(./get_cores.sh)
  echo $SECONDS,$cores >> ../benchmark/stats/cpu.csv
}

log_debug_info() {  
  local val=$1

  if [ $(( val % $DEBUG_FREQUENCY )) -eq 0 ]; then

    # echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
  
    # kubectl logs -l="serviceweaver/name=$mainpod"
    # echo
    date -d@$SECONDS -u +%H:%M:%S
    # kubectl top pod
    # echo
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

timestamp="[$(date +'%a %h %d %T %Y')] "
reprint="\e[1A\e[K"

iterations=0

str=$(get_lines)
size=${#str}
echo $str
last_str=""

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
  strs=$(get_lines 2)
  str=$(echo "$strs" | tail -1)
  strPrev=$(echo "$strs" | head -1)
  size=${#str}
  
  if [[ $strPrev != $last_str ]]; then
    echo -e $timestamp$strPrev
    echo $strPrev >> $logfile   

    if [[ $str != $last_str ]]; then
      echo $str
      echo $str >> $logfile
    fi

  elif [[ $str != $last_str ]]; then
    echo -e  $timestamp$str
    echo $str >> $logfile
  fi


  last_str=$str
  
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