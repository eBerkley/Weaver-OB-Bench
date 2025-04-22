#!/bin/bash

# This script profiles the instruction and cycle footprint of each Service Weaver component
# (both the control‑plane “babysitter” and the application “ob” process) in a Kubernetes deployment.
# We use a default of 10 000 CPU cycles between samples (`-c 10000`) to balance overhead and accuracy.
# Different components have different activity levels.
# Lighter components need longer profiling durations to accumulate enough samples 
# Heavier or chatty components may require **shorter** durations to avoid excessive data collection.
# Adjust these durations to ensure each component collects a representative instruction footprint.

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 [output_directory]"
    exit 1
fi

TOP_DIR=$(readlink -f "$1")
OUTPUT_DIR="${TOP_DIR}/inst_fp_collection_seq"
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"/*

CPU_CORE=0-2

declare -A COMPONENTS=(
    [main]="main"
    [adservice]="adservice"
    [cartservice]="cartservice"
    [cartcache]="cartcache"
    [checkoutservice]="checkoutservice"
    [currencyservice]="currencyservice"
    [emailservice]="emailservice"
    [paymentservice]="paymentservice"
    [productcatalogservice]="productcatalogservice"
    [recservice]="recservice"
    [shippingservice]="shippingservice"
)

# declare -A SAMPLE_COUNTS=(
#     [main]=10000
#     [adservice]=10000
#     [cartservice]=10000
#     [cartcache]=10000
#     [checkoutservice]=10000
#     [currencyservice]=10000
#     [emailservice]=10000
#     [paymentservice]=10000
#     [productcatalogservice]=10000
#     [recservice]=10000
#     [shippingservice]=10000
# )

declare -A PROFILE_DURATIONS=(
    [main]=50
    [adservice]=50
    [cartservice]=50
    [cartcache]=50
    [checkoutservice]=50
    [currencyservice]=50
    [emailservice]=90
    [paymentservice]=90
    [productcatalogservice]=50
    [recservice]=50
    [shippingservice]=50
)

declare -A PROFILE_BS_DURATIONS=(
    [main]=60
    [adservice]=60
    [cartservice]=60
    [cartcache]=120
    [checkoutservice]=60
    [currencyservice]=60
    [emailservice]=90
    [paymentservice]=120
    [productcatalogservice]=90
    [recservice]=120
    [shippingservice]=60
)

# perf_event_paranoid
OLD_VALUE=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Temporarily lowering kernel.perf_event_paranoid to -1..."
sudo sysctl -w kernel.perf_event_paranoid=-1

cleanup() {
    echo "Reverting kernel.perf_event_paranoid to $OLD_VALUE..."
    sudo sysctl -w kernel.perf_event_paranoid=$OLD_VALUE
    echo "Cleanup done."
    exit 0
}
trap cleanup SIGINT SIGTERM

get_component_name() {
    local pod_name=$1
    for key in "${!COMPONENTS[@]}"; do
        if [[ "$pod_name" == *"$key"* ]]; then
            echo "${COMPONENTS[$key]}"
            return
        fi
    done
    echo "unknown"
}

get_pod_info() {
    local pid=$1
    cgroup_line=$(grep -o 'kubepods[^/]*pod[^/]*\.slice' /proc/"$pid"/cgroup | head -n1)
    pod_uid=$(echo "$cgroup_line" | sed -n 's/.*pod\([0-9a-fA-F_]*\)\.slice.*/\1/p' | tr '_' '-')
    pod_name=$(kubectl get pods --all-namespaces -o jsonpath="{.items[?(@.metadata.uid=='$pod_uid')].metadata.name}")
    [[ -z "$pod_name" ]] && pod_name="unknown"
    echo "$pod_name"
}
sleep 100
# --- Profile babysitter processes ---
mapfile -t pids_babysitter < <(pgrep -f '/weaver/weaver-kube babysitter')
for pid in "${pids_babysitter[@]}"; do
    if ! ps -p "$pid" > /dev/null; then continue; fi
    pod_name=$(get_pod_info "$pid")
    comp_name=$(get_component_name "$pod_name")
    if [[ "$comp_name" == "unknown" ]]; then
        echo "Skipping unknown component: $pod_name"
        continue
    fi
    profile_secs="${PROFILE_BS_DURATIONS[$comp_name]}"
    output_base="${OUTPUT_DIR}/${pod_name}_babysitter_${pid}"
    echo "Profiling babysitter (PID=$pid, Pod=$pod_name)..."
    sudo taskset -c $CPU_CORE perf record -e instructions,cycles -c 10000 -p "$pid" -o "${output_base}.data" -- sleep "$profile_secs"
    sudo perf report --stdio --sort=symbol -i "${output_base}.data" > "${output_base}_report.txt"
    rm -f "${output_base}.data"
    echo ""
done

# --- Profile service (ob) components ---
mapfile -t pids_ob < <(pgrep -f '/weaver/ob')
for pid in "${pids_ob[@]}"; do
    if ! ps -p "$pid" > /dev/null; then continue; fi
    pod_name=$(get_pod_info "$pid")
    comp_name=$(get_component_name "$pod_name")
    if [[ "$comp_name" == "unknown" ]]; then
        echo "Skipping unknown component: $pod_name"
        continue
    fi
    # sample_count="${SAMPLE_COUNTS[$comp_name]}"
    profile_secs="${PROFILE_DURATIONS[$comp_name]}"
    output_base="${OUTPUT_DIR}/${pod_name}_service_${pid}"
    echo "Profiling $comp_name (PID=$pid, Pod=$pod_name)..."
    sudo taskset -c $CPU_CORE perf record -e instructions,cycles -c 10000 -p "$pid" -o "${output_base}.data" -- sleep "$profile_secs"
    sudo perf report --stdio --sort=symbol -i "${output_base}.data" > "${output_base}_report.txt"
    rm -f "${output_base}.data"
    echo ""
done

cleanup

