#!/bin/bash

# Ensure the Jaeger traces directory is clean
if [ -d "./jaeger_traces" ]; then
    rm -rf "./jaeger_traces"
fi
mkdir -p "./jaeger_traces"

# Set Jaeger-related variables
JAEGER_SERVICE_NAME="jaeger"
JAEGER_NAMESPACE="default"
LOCAL_PORT=16686
OUTPUT_DIR="./jaeger_traces"
SERVICE_NAME="ob"  # Service to filter traces

# Start Kubernetes port forwarding for Jaeger
echo "Starting Kubernetes port forwarding for Jaeger..."
kubectl port-forward svc/${JAEGER_SERVICE_NAME} -n ${JAEGER_NAMESPACE} ${LOCAL_PORT}:16686 &
PORT_FORWARD_PID=$!
trap "echo 'Stopping port forwarding...'; kill ${PORT_FORWARD_PID}; exit" INT TERM

# Wait for port-forwarding to be established
sleep 1

# Function to fetch Jaeger traces
fetch_jaeger_traces () {
  TIMESTAMP=$(date +'%Y%m%d_%H%M%S')              # Unique timestamp for the file name
  FETCH_FILE="${OUTPUT_DIR}/traces_${TIMESTAMP}.json"  # File name based on the timestamp
  JAEGER_API_URL="http://localhost:${LOCAL_PORT}/api/traces?service=${SERVICE_NAME}"

  echo "Fetching Jaeger traces..."
  curl -X GET -s "${JAEGER_API_URL}" > "$FETCH_FILE"

  if [[ $? -eq 0 ]]; then
    if [[ -s "$FETCH_FILE" ]]; then
      echo "Fetched traces and saved to $FETCH_FILE."
    else
      echo "No new traces found in this fetch."
      rm -f "$FETCH_FILE"  # Remove empty file
    fi
  else
    echo "Failed to fetch traces at $(date)."
    rm -f "$FETCH_FILE"  # Remove file on failure
  fi
}

# Manually fetch traces once
fetch_jaeger_traces

# Terminate the port-forward process
echo "Stopping port forwarding..."
kill ${PORT_FORWARD_PID}

echo "Done."