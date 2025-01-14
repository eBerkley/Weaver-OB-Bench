#!/bin/bash
cd $(dirname "$0") || exit
sleep 15

logfile="../logs.txt"

# podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')
full_podname=$(kubectl get pod -o name --selector app=loadgenerator )
podname="${full_podname#*/}"
echo load generator podname = $podname

mainpod=$(kubectl get deploy | grep '[mM]ain' | head -1 | awk '{print $1}')
if [[ -z "$mainpod" ]]; then
  mainpod=$(kubectl get deploy | grep 'all' | head -1 | awk '{print $1}')
  if [[ -z "$mainpod" ]]; then
    mainpod=$(kubectl get deploy | grep 'front' | head -1 | awk '{print $1}')
  fi
fi

SECONDS=0
debug_frequency=4 # 25% of time

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

  if [ $(( val % $debug_frequency )) -eq 0 ]; then

    # echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
  
    # kubectl logs -l="serviceweaver/name=$mainpod"
    # echo
    date -d@$SECONDS -u +%H:%M:%S
    kubectl top pod

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
while [ $size -le 5 ] || [ $size -ge 20 ]; do
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
  
done

kubectl cp $podname:/stats ../benchmark/stats

echo done.