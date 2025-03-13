#!/bin/bash
# dynamic_profile.sh
#
# This script dynamically monitors Service Weaver processes by polling for
# new PIDs matching the babysitter and application patterns. For each new PID,
# it launches a separate perf stat instance (bound to a specified CPU core) and
# writes the output to a uniquely named file (using pod name and role).
#
# Usage: sudo ./dynamic_profile.sh <cpu_core>
# Example: sudo ./dynamic_profile.sh 0
#


if [ "$#" -ne 1 ]; then
    echo "Usage: sudo $0 <cpu_core>"
    exit 1
fi

CPU_CORE=$1

# Ensure OUTPUT_DIR is set to your desired directory.
OUTPUT_DIR="/home/gz243/Weaver-OB-Bench/IF_collection"
mkdir -p $OUTPUT_DIR

# Save the current perf_event_paranoid value.
OLD_VALUE=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Original kernel.perf_event_paranoid: $OLD_VALUE"

echo "Temporarily lowering kernel.perf_event_paranoid to -1..."
sudo sysctl -w kernel.perf_event_paranoid=-1

# Define a cleanup function to revert settings and kill all perf instances.
cleanup() {
    echo -e "\nCleaning up..."
    for perf_pid in "${PERF_PIDS[@]}"; do
        kill -SIGINT "$perf_pid" 2>/dev/null
        wait "$perf_pid" 2>/dev/null
    done
    echo "Reverting kernel.perf_event_paranoid to $OLD_VALUE..."
    sudo sysctl -w kernel.perf_event_paranoid=$OLD_VALUE
    echo "Reverted kernel.perf_event_paranoid to $OLD_VALUE"
    exit 0
}

# Trap SIGINT and SIGTERM.
trap cleanup SIGINT SIGTERM

# Function to get pod name and role for a given PID.
get_pod_info() {
    local pid=$1
    local cgroup_line pod_uid pod_name cmd_line role

    # Extract the pod UID from the cgroup file.
    cgroup_line=$(grep -o 'kubepods[^/]*pod[^/]*\.slice' /proc/"$pid"/cgroup | head -n1)
    pod_uid=$(echo "$cgroup_line" | sed -n 's/.*pod\([0-9a-fA-F_]*\)\.slice.*/\1/p')
    pod_uid=$(echo "$pod_uid" | tr '_' '-')
    
    # Query kubectl for the pod name using the UID.
    pod_name=$(kubectl get pods --all-namespaces -o jsonpath="{.items[?(@.metadata.uid=='$pod_uid')].metadata.name}")
    if [ -z "$pod_name" ]; then
        pod_name="unknown"
    fi

    # Determine role by checking the command line.
    cmd_line=$(ps -p "$pid" -o args=)
    if echo "$cmd_line" | grep -qi "babysitter"; then
        role="babysitter"
    else
        role="service"
    fi

    echo "$pod_name" "$role"
}

# Declare an associative array to track which PIDs are already being profiled.
declare -A profile_map
# And an array to store the perf process IDs.
declare -a PERF_PIDS

echo "Starting dynamic monitoring for new processes..."
while true; do
    # Get current PIDs for babysitter and application processes.
    pids_babysitter=$(pgrep -f '/weaver/telemetry-local babysitter')
    pids_ob=$(pgrep -f '/weaver/ob')
    
    # Combine both lists.
    current_pids=()
    for pid in $pids_babysitter $pids_ob; do
        current_pids+=("$pid")
    done
    
    # For each current PID, if not already being profiled, launch a perf stat instance.
    for pid in "${current_pids[@]}"; do
        if [ -z "${profile_map[$pid]}" ]; then
            # Get pod info for naming the output file.
            read pod_name role <<< "$(get_pod_info "$pid")"
            output_file="${OUTPUT_DIR}/${pod_name}_${role}_${pid}.txt"
            echo "Starting profiling for PID $pid (Pod: $pod_name, Role: $role). Output: $output_file"
            sudo taskset -c $CPU_CORE perf stat -o "$output_file" \
                -e instructions,cycles,cache-references,cache-misses \
                -p "$pid" &
            perf_proc_pid=$!
            profile_map[$pid]=$perf_proc_pid
            PERF_PIDS+=($perf_proc_pid)
        fi
    done

    # Remove entries for PIDs that no longer exist.
    for pid in "${!profile_map[@]}"; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            echo "PID $pid no longer exists. Removing from monitoring."
            unset profile_map[$pid]
        fi
    done

    sleep 10  # Polling interval (adjust as needed)
done
