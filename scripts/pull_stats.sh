#!/bin/bash
cd $(dirname $0)
sleep 15
podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')

SECONDS=0

echo waiting for loadgenerator to be ready...
kubectl wait --timeout=1h --for=condition=Ready pod/$podname
sleep 1
echo loadgenerator ready. Time elapsed = $SECONDS seconds.
echo

SECONDS=0


get_line () {
  kubectl logs --tail 1 $podname
}

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

log_cpu_util () {
  cores=$(./get_cores.sh)
  echo $SECONDS,$cores >> ../benchmark/stats/cpu.csv
}

reprint="\e[1A\e[K"

str=$(get_line)
size=${#str}
echo $str
while [ $size -ge 20 ]; do
  log_cpu_util
  
  sleep 10
  str=$(get_line)
  size=${#str}

  echo -e $reprint$str | tee -a ../logs.txt
  
done

kubectl cp $podname:/stats ../benchmark/stats

echo done.