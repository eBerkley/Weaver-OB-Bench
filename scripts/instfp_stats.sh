#!/bin/bash
# pull_inst.sh
#
# This script  dynamically attaches perf stat and perf record to Service Weaver processes 
# (both babysitter and application). Perf output files are named with the 
# corresponding pod name, role, and PID.
#
# Usage: ./instfp_stats.sh <directory where you want to store the profiling data>
# Example: ./instfp_stats.sh ./
#
# Ensure OUTPUT_DIR is set to your desired directory (absolute path).
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 [output_directory]"
    exit 1
fi

TOP_DIR=$(readlink -f "$1")

OUTPUT_DIR="${TOP_DIR}/inst_fp_collection"
rm -rf "$OUTPUT_DIR"/*

echo "Using OUTPUT_DIR: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

CPU_CORE=0-2

mkdir -p $OUTPUT_DIR
# Change to the script's directory.
cd "$(dirname "$0")" || exit

# Initial sleep to allow pods to settle.
sleep 10

logfile="../logs.txt"

# Get load generator pod name.
full_podname=$(kubectl get pod -o name --selector app=loadgenerator )
podname="${full_podname#*/}"
echo "load generator podname = $podname"

# Determine main deployment (fallbacks if needed).
mainpod=$(kubectl get deploy | grep '[mM]ain' | head -1 | awk '{print $1}')
if [[ -z "$mainpod" ]]; then
  mainpod=$(kubectl get deploy | grep 'all' | head -1 | awk '{print $1}')
  if [[ -z "$mainpod" ]]; then
    mainpod=$(kubectl get deploy | grep 'front' | head -1 | awk '{print $1}')
  fi
fi

SECONDS=0
debug_frequency=4  # Debug info printed every 4 iterations.

echo "waiting for loadgenerator to be ready..." | tee -a "$logfile"
kubectl wait --timeout=1h --for=condition=Ready pod/"$podname"
sleep 1
echo "loadgenerator ready. Time elapsed = $SECONDS seconds." | tee -a "$logfile"
echo | tee -a "$logfile"

# Reset timer.
SECONDS=0

# Function: get_lines [optional: number of tail lines]
get_lines () {
  kubectl logs --tail ${1:-1} "$podname"
}

echo Seconds,CPU Cores > ../benchmark/stats/cpu.csv

log_debug_info() {  
  local val=$1
  if [ $(( val % debug_frequency )) -eq 0 ]; then
    date -d@"$SECONDS" -u +%H:%M:%S
    kubectl top pod
  fi
}

timestamp="[$(date +'%a %h %d %T %Y')] "
iterations=0

str=$(get_lines)
size=${#str}
echo "$str"
last_str=""

# --- Set up dynamic perf monitoring ---
# Declare associative arrays to track profiled PIDs.
declare -A perf_map       # For perf stat
declare -A record_map     # For perf record
# Arrays to store perf process PIDs.
declare -a PERF_PIDS
declare -a RECORD_PIDS

# Define function to get pod name and role for a given PID.
get_pod_info() {
    local pid=$1
    local cgroup_line pod_uid pod_name cmd_line role

    # Extract the cgroup line that includes the pod UID.
    cgroup_line=$(grep -o 'kubepods[^/]*pod[^/]*\.slice' /proc/"$pid"/cgroup | head -n1)
    pod_uid=$(echo "$cgroup_line" | sed -n 's/.*pod\([0-9a-fA-F_]*\)\.slice.*/\1/p')
    # Convert underscores to dashes.
    pod_uid=$(echo "$pod_uid" | tr '_' '-')
    
    # Query kubectl for the pod name using the UID.
    pod_name=$(kubectl get pods --all-namespaces -o jsonpath="{.items[?(@.metadata.uid=='$pod_uid')].metadata.name}")
    if [ -z "$pod_name" ]; then
        pod_name="unknown"
    fi

    # Determine role by inspecting the command line.
    cmd_line=$(ps -p "$pid" -o args=)
    if echo "$cmd_line" | grep -qi "babysitter"; then
        role="babysitter"
    else
        role="service"
    fi

    echo "$pod_name" "$role"
}

# Lower kernel's perf_event_paranoid setting.
OLD_VALUE=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Original kernel.perf_event_paranoid: $OLD_VALUE"
echo "Temporarily lowering kernel.perf_event_paranoid to -1..."
sudo sysctl -w kernel.perf_event_paranoid=-1

# Define cleanup function to kill all perf instances and revert kernel settings.
cleanup() {
    echo -e "\nCleaning up..."
    for perf_pid in "${PERF_PIDS[@]}"; do
        kill -SIGINT "$perf_pid" 2>/dev/null
        wait "$perf_pid" 2>/dev/null
    done
    for rec_pid in "${RECORD_PIDS[@]}"; do
        kill -SIGINT "$rec_pid" 2>/dev/null
        wait "$rec_pid" 2>/dev/null
    done
    echo "Reverting kernel.perf_event_paranoid to $OLD_VALUE..."
    sudo sysctl -w kernel.perf_event_paranoid=$OLD_VALUE
    echo "Reverted kernel.perf_event_paranoid to $OLD_VALUE"
    exit 0
}

# Trap SIGINT and SIGTERM.
trap cleanup SIGINT SIGTERM

# --- Main loop: Collect CPU util and dynamic perf monitoring ---
while [ $size -le 5 ] || [ $size -ge 20 ]; do
    sleep 10

    # --- Dynamic Perf Monitoring ---
    # Get current PIDs for babysitter and application processes.
    pids_babysitter=$(pgrep -f '/weaver/weaver-kube babysitter')
    pids_ob=$(pgrep -f '/weaver/ob')
    current_pids=()
    for pid in $pids_babysitter $pids_ob; do
        current_pids+=("$pid")
    done

    # For each current PID, if not already being profiled, launch both perf stat and perf record.
    for pid in "${current_pids[@]}"; do
        if [ -z "${perf_map[$pid]}" ]; then
            read pod_name role <<< "$(get_pod_info "$pid")"
            # Set output file names.
            stat_output_file="${OUTPUT_DIR}/${pod_name}_${role}_${pid}.txt"
            record_output_file="${OUTPUT_DIR}/${pod_name}_${role}_${pid}_record.data"
            
            echo "Starting perf stat for PID $pid (Pod: $pod_name, Role: $role). Output: $stat_output_file"
            sudo taskset -c $CPU_CORE perf stat -o "$stat_output_file" \
                 -e instructions,cycles,L1-icache-load-misses \
                 -p "$pid" &
            perf_proc_pid=$!
            perf_map[$pid]=$perf_proc_pid
            PERF_PIDS+=($perf_proc_pid)
            
            echo "Starting perf record for PID $pid (Pod: $pod_name, Role: $role). Record file: $record_output_file"
            # sudo taskset -c $CPU_CORE perf record -e cycles -F 99 -p "$pid" -o "$record_output_file" &
            # sudo taskset -c $CPU_CORE perf record -e instructions:u,instructions:k -c 10000 -p "$pid" -o "$record_output_file" &
            sudo taskset -c $CPU_CORE perf record -e instructions -c 10000 -p "$pid" -o "$record_output_file" &
            record_proc_pid=$!
            record_map[$pid]=$record_proc_pid
            RECORD_PIDS+=($record_proc_pid)
        fi
    done

    # Remove entries for PIDs that no longer exist.
    for pid in "${!perf_map[@]}"; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            echo "PID $pid no longer exists. Removing from monitoring."
            unset perf_map[$pid]
            unset record_map[$pid]
        fi
    done

    # --- End Dynamic Perf Monitoring ---

    # Pull log lines from the loadgenerator pod.
    strs=$(get_lines 2)
    str=$(echo "$strs" | tail -1)
    strPrev=$(echo "$strs" | head -1)
    size=${#str}

    if [[ $strPrev != $last_str ]]; then
        echo -e "$timestamp$strPrev"
        echo "$strPrev" >> "$logfile"   
        if [[ $str != $last_str ]]; then
            echo "$str"
            echo "$str" >> "$logfile"
        fi
    elif [[ $str != $last_str ]]; then
        echo -e "$timestamp$str"
        echo "$str" >> "$logfile"
    fi

    last_str=$str
    (( iterations+=1 ))
    log_debug_info "$iterations" >> "$logfile"
done


for perf_pid in "${PERF_PIDS[@]}"; do
    kill -SIGINT "$perf_pid" 2>/dev/null
    wait "$perf_pid" 2>/dev/null
done
for rec_pid in "${RECORD_PIDS[@]}"; do
    kill -SIGINT "$rec_pid" 2>/dev/null
    wait "$rec_pid" 2>/dev/null
done
echo "Reverting kernel.perf_event_paranoid to $OLD_VALUE..."
sudo sysctl -w kernel.perf_event_paranoid=$OLD_VALUE
echo "Reverted kernel.perf_event_paranoid to $OLD_VALUE"


echo "Main loop ended. Processing all perf record files for instruction footprint analysis..."
echo Component-Attribute,Unique Instruction Count >> "$OUTPUT_DIR"/results.csv
# Iterate over each file in the OUTPUT_DIR with "_record.data" in its name.
for record_file in "$OUTPUT_DIR"/*_record.data; do
    # Check if the file exists (in case no files were generated)
    if [ -e "$record_file" ]; then
        # Derive the base name by removing the '_record.data' suffix.
        base_name="${record_file%_record.data}"
        # report_output_file="${base_name}_report.txt"
        script_output_file="${base_name}_script.txt"

        # echo "Generating perf report for $record_file -> $report_output_file"
        # sudo perf report -i "$record_file" > "$report_output_file"
        # sudo perf report --stdio --sort=symbol -i "$record_file" > "$report_output_file"

        echo "Generating perf script for $record_file -> $script_output_file"
        sudo perf script -i "$record_file" > "$script_output_file"

        instruction_footprint_file="${base_name}_unique_inst.txt"

        # sed -n 's/.*instructions:[uk]:[[:space:]]*\(.*\)/\1/p' "$script_output_file" | sort | uniq > "$instruction_footprint_file"
        sed -n 's/.*instructions:[[:space:]]*\(.*\)/\1/p' "$script_output_file" | sort -u > "$instruction_footprint_file"
        rm -rf "$script_output_file"

        # Extract component information from the file name.
        filename=$(basename "$record_file")
        without_ob="${filename#ob-}"
        component_name=$(echo "$without_ob" | cut -d'-' -f1)
        comp_attr=$(echo "$without_ob" | cut -d'_' -f2)
        # Combine to get something like "component-babysitter"
        component_attr="${component_name}-${comp_attr}"

        # Decide which grep pattern to use based on the component attribute.
        if [ "$comp_attr" = "babysitter" ]; then
            grep_pattern="/weaver/weaver-kube"
        else
            grep_pattern="/weaver/ob"
        fi

        # Count the number of unique instruction lines matching the pattern.
        unique_inst_count=$(grep "$grep_pattern" "$instruction_footprint_file" | wc -l)

        # Append the component attribute and the unique instruction count to a CSV file.
        echo "$component_attr, $unique_inst_count" >> "$OUTPUT_DIR"/results.csv

        # rm -rf "$record_file" "$instruction_footprint_file"
        rm -rf "$record_file"
    fi
done

echo "done."


