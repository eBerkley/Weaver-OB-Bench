#!/bin/bash

# Check if the script is run as root
# If not, re-run the script with sudo

if [[ $UID -ne 0 ]]; then
  sudo -E taskset -c 5-25 $0 $USER $VTUNE_GROUP_NAME $VTUNE_DURATION $LOCUST_CONST_USERS "$@"
  exit $?
fi

# CHANGE
toplev=/home/etb74/pmu-tools/toplev 
echo testing toplev:
$toplev --version --force-cpu spr

username=$1
groupname=$2
duration=$3
load_level=$4

echo duration   = $duration
echo group name = $groupname
echo load level = $load_level

cd $(dirname "$0") || exit
sleep 5
echo perf_stats.sh
# Actually doesn't even work for the most part.
# source stats_utils/all_stats.sh



uset() {
  sudo -u $username PATH="$PATH:/home/$username/go/bin" $*
}



echo load gen podname = $podname

# groupname=$VTUNE_GROUP_NAME
# duration=$VTUNE_DURATION # in seconds


if ! uset kubectl get po | grep "ob-$groupname" &>/dev/null; then
  echo "Error: Pod '$POD_NAME' not found."
  exit 1
fi

OLD_VALUE=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Original kernel.perf_event_paranoid: $OLD_VALUE"
echo "Temporarily lowering kernel.perf_event_paranoid to -1..."
sysctl -w kernel.perf_event_paranoid=-1


cleanup() {
  echo "Reverting kernel.perf_event_paranoid to $OLD_VALUE..."
  sudo sysctl -w kernel.perf_event_paranoid=$OLD_VALUE
  echo "Cleanup done."
  exit 0
}
trap cleanup SIGINT SIGTERM

OUTPUT_DIR="vtune_results"
mkdir -p "$OUTPUT_DIR"

wait_constload() {
  echo beginning to wait for constload...
  str=$(uset kubectl logs --tail 1 -l app=loadgenerator)
  size=${#str}
  echo $str
  local reprint_str="\e[1A\e[K"
  while [ $size -le 5 ] || [ $size -ge 90 ]; do 
    str=$(uset kubectl logs --tail 1 -l app=loadgenerator)
    size=${#str}
    echo -e $reprint_str$str
    sleep 10
  done

  echo done waiting.
}

events_1=instructions,cycles,L1-icache-load-misses,branch-misses,dTLB-loads
events_2=L1-dcache-loads,L1-dcache-load-misses,LLC-loads,LLC-load-misses
events_3=dTLB-load-misses,iTLB-load-misses,branch-instructions,context-switches
events_4=l2_request.all,l2_request.miss,l2_rqsts.all_code_rd,faults
prof_pod () {
  pid=$1

  echo Preparing to profile $groupname
  stat_output_file="$(pwd)/$OUTPUT_DIR/comp-${groupname}-new_stats.txt"
  toplev_output_file="$(pwd)/$OUTPUT_DIR/comp-${groupname}-new_toplev.txt"
  mv $stat_output_file $stat_output_file.old
  mv $toplev_output_file $toplev_output_file.old

  # record_output_file="$(pwd)/$OUTPUT_DIR/${hostname}_${load_level}_stats.txt"
  local real_duration=0
  (( real_duration = 1000 * $duration ))

  cpus=$(cat /proc/$pid/status | grep Cpus_allowed_list | awk '{print $2}')

  flags=""
  flags+=" -o $stat_output_file" # output location
  # flags+=" -e instructions,cycles,L1-icache-load-misses,L1-dcache-load-misses,LLC-load-misses,branch-misses" # cpi + l1i-mpki
  flags+=" --cpu $cpus" # attach to running pod process
  # flags+=" -d -d -d" # more detailed events, L1, LLC, dTLB, iTLB events.
  # flags+=" --timeout $real_duration" # How long does it run?
  # flags+=" --per-cache" # maybe do this on altra?
  
  # echo preparing to run toplev
  toplev_flags="-v --no-multiplex --no-desc"
  toplev_flags+=" --force-cpu spr -- --cpu $cpus"
  toplev_flags+=" --timeout $real_duration"
  
  # return

  echo toplev flags: $toplev_flags "(-o $toplev_output_file)"
  $toplev $toplev_flags 2>$toplev_output_file
  echo "finished running toplev."

  echo preparing to run perf.

  echo "$flags -e $events_1"

  perf stat $flags -e $events_1&
  perf_pid=$!
  sleep $duration
  kill -SIGINT "$perf_pid"
  wait $perf_pid
  
  echo preparing second run:
  echo "$flags --append -e $events_2"
  perf stat $flags --append -e $events_2 &
  perf_pid=$!
  sleep $duration
  kill -SIGINT "$perf_pid"
  wait $perf_pid

  echo preparing third run:
  echo "$flags --append -e $events_3"
  perf stat $flags --append -e $events_3&
  perf_pid=$!
  sleep $duration
  kill -SIGINT "$perf_pid"
  wait $perf_pid

  echo preparing final run:
  echo "$flags --append -e $events_4"
  perf stat $flags --append -e $events_4&
  perf_pid=$!
  sleep $duration
  kill -SIGINT "$perf_pid"
  wait $perf_pid

  chown -R $username "$OUTPUT_DIR"
  echo perf stat complete.

}

sleep 10
wait_constload

# for c in m ch r s a cu ca e pa cc pr; do
  # groupname=$c
for p in $(pgrep -f "/weaver/ob" | xargs --no-run-if-empty ps | awk '{print $1}' | tail -n +2); do
  hostname=$(cat /proc/$p/environ | strings | grep HOSTNAME)

  # Extract the pod name from the hostname
  if [[ $hostname =~ ^HOSTNAME=(.*) ]]; then
    hostname=${BASH_REMATCH[1]}
  else
    echo "Error: Unable to extract hostname from /proc/$p/environ"
    continue
  fi
  
  if [[ ! $hostname =~ "ob-$groupname-" ]]; then
    echo "Skipping pod: $hostname"
    continue
  fi
  echo found pod: $hostname
  prof_pod $p 
  break
  
done
# done

# sleep 100000
cleanup

echo All done!
