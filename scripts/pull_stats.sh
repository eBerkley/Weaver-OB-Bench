#!/bin/bash
cd $(dirname "$0") || exit
sleep 15

logfile="../logs.txt"

podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')

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


get_line () {
  kubectl logs --tail 1 $podname
}

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

write_cpu_util () {
  cores=$(./get_cores.sh)
  echo $SECONDS,$cores >> ../benchmark/stats/cpu.csv
}

log_debug_info() {  
  local val=$1

  if [ $(( val % $debug_frequency )) -eq 0 ]; then

    echo "=*=*=*=*=*=*=*=*= DEBUG INFO =*=*=*=*=*=*=*=*="
  
    kubectl logs -l="serviceweaver/name=$mainpod"
    echo
    kubectl top pod

    echo "=*=*=*=*=*=*=*=*= END DEBUG. =*=*=*=*=*=*=*=*="

  fi
}

reprint="\e[1A\e[K"

iterations=0

str=$(get_line)
size=${#str}
echo $str
while [ $size -ge 20 ]; do
  write_cpu_util
  
  sleep 10
  str=$(get_line)
  size=${#str}

  echo -e $reprint$str
  echo $str >> $logfile

  (( iterations+=1 ))
  log_debug_info $iterations >> $logfile
  
done

kubectl cp $podname:/stats ../benchmark/stats

echo done.