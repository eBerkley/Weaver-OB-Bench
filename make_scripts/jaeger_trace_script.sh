#!/bin/bash

# Configuration
JAEGER_SERVICE_NAME="jaeger"  # Kubernetes service name for Jaeger
JAEGER_NAMESPACE="default"   # Kubernetes namespace where Jaeger is deployed
LOCAL_PORT=16686             # Local port for port forwarding
FETCH_INTERVAL=10            # Time in seconds between fetches
OUTPUT_FILE="./jaeger_traces/traces.json" # File to save trace data
EXCLUDED_SERVICE="jaegertracing/all-in-one"  # Service to exclude

# Ensure the output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Start Kubernetes port forwarding
echo "Starting Kubernetes port forwarding for Jaeger..."
kubectl port-forward svc/${JAEGER_SERVICE_NAME} -n ${JAEGER_NAMESPACE} ${LOCAL_PORT}:16686 &
PORT_FORWARD_PID=$!
echo "Port forwarding started. PID: ${PORT_FORWARD_PID}"

# Trap to clean up port forwarding on exit
trap "echo 'Stopping port forwarding...'; kill ${PORT_FORWARD_PID}; exit" INT TERM

# Initialize timestamps
LAST_FETCH_TIME=$(($(date +%s%N)/1000))  # Current time in microseconds

echo "Starting Jaeger trace exporter..."
echo "Data will be saved to: $OUTPUT_FILE"
echo "Fetching traces every $FETCH_INTERVAL seconds."

while true; do
  CURRENT_TIME=$(($(date +%s%N)/1000))  # Current time in microseconds
  
  # Fetch traces from Jaeger API with time filtering
  JAEGER_API_URL="http://localhost:${LOCAL_PORT}/api/traces?start=${LAST_FETCH_TIME}&end=${CURRENT_TIME}"
  
  # Filter traces to exclude the Jaeger service
  TEMP_FILE=$(mktemp)
  curl -s "${JAEGER_API_URL}" | jq --arg excluded "$EXCLUDED_SERVICE" '
    .data[] | select(.processes[].serviceName != $excluded)' > "$TEMP_FILE"
  
  if [[ $? -eq 0 ]]; then
    echo "Successfully fetched traces at $(date)."

    # Add timestamps to the output
    TIMESTAMPED_OUTPUT=$(mktemp)
    jq -n --argjson traces "$(cat "$TEMP_FILE")" \
          --arg start "$LAST_FETCH_TIME" \
          --arg end "$CURRENT_TIME" \
          '{start_time: $start, end_time: $end, traces: $traces}' > "$TIMESTAMPED_OUTPUT"
    
    # Append new traces with timestamps to the output file
    if [[ -s "$TEMP_FILE" ]]; then
      jq -s 'add' "$TIMESTAMPED_OUTPUT" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
      echo "Appended new traces with timestamps to $OUTPUT_FILE."
    else
      echo "No new traces found."
    fi
    rm -f "$TIMESTAMPED_OUTPUT"
  else
    echo "Failed to fetch traces at $(date)."
  fi

  # Update last fetch time
  LAST_FETCH_TIME=$CURRENT_TIME
  
  # Clean up temporary file
  rm -f "$TEMP_FILE"
  
  # Wait before the next fetch
  sleep "$FETCH_INTERVAL"
done
