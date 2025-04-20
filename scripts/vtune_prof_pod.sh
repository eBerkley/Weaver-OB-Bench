#!/bin/bash

# Check if the script is run as root
# If not, re-run the script with sudo
if [[ $UID -ne 0 ]]; then
  sudo $0 $USER "$@"
  exit $?
fi


# Check if pod name is provided
if [ -z "$2" ]; then
  echo "Usage: $0 <pod-name>"
  exit 1
fi


username=$1
POD_NAME=$2

uset() {
  sudo -u $username PATH="$PATH:/home/$username/go/bin" $*
}

PROFILE_TIME=120
mode=hotspots


if [[ ! -e "/opt/intel/oneapi/vtune/latest/vtune-vars.sh" ]]; then
  echo "VTune is not installed. Please install VTune to use this script."
  exit 1
fi

source /opt/intel/oneapi/vtune/latest/vtune-vars.sh
result_dir=/opt/intel/oneapi/vtune/vtune_results/analyze_pod

# create the result directory if it doesn't exist
mkdir -p "$result_dir"


# Check if the pod exists
if ! kubectl get pod "$POD_NAME" &>/dev/null; then
  echo "Error: Pod '$POD_NAME' not found."
  exit 1
fi

for p in $(pgrep -f "/weaver/ob" | xargs --no-run-if-empty ps | awk '{print $1}' | tail -n +2); do
  hostname=$(cat /proc/$p/environ | strings | grep HOSTNAME)

  # Extract the pod name from the hostname
  pod_name=$(echo $hostname | gawk 'match($0, /=ob-([^-]*)/, a) {print a[1]}')
  if [[ $pod_name != $POD_NAME ]]; then
    continue
  fi
  echo "Profiling pod: $pod_name"
  specific_result_dir="$result_dir/$pod_name@@@{at}"

  collect_flags=""
  collect_flags+=" --duration $PROFILE_TIME"
  collect_flags+=" -source-search-dir=./src"
  collect_flags+=" -search-dir=./release/generated"
  # collect_flags+=" -knob sampling-mode=hw"
  collect_flags+=" --output-dir $specific_result_dir"

  echo "VTune collect flags: $collect_flags"
  vtune -collect $mode $collect_flags -target-pid $p

  report_path="vtune_results/$pod_name"
  mkdir -p $report_path

  vtune -report summary \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path/report.csv
  vtune -report hotspots \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path/hotspots.csv
  vtune -report callstacks \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path /callstacks.csv
  vtune -report memory-access \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path/memory-access.csv
  vtune -report memory-bandwidth \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path/memory-bandwidth.csv
  vtune -report memory-allocation \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path/memory-allocation.csv
  vtune -report memory-consumption \
    -r $specific_result_dir \
    -format csv \
    -report-output $report_path/memory-consumption.csv

  chown -R $username:$username $report_path

done