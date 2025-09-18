#!/bin/bash

METRIC_URL="http://localhost:9090/api/v1/query"
OUT_PATH="metric.json"

query () {
  local q=$1
  local url="$METRIC_URL?query=$q"
  echo $url
  curl -s $(jq -rn --arg q "$url" '$q|@uri' ) -o $OUT_PATH
}

# query "rate(serviceweaver_concurrent_method_count[30s])"
# query "sum(serviceweaver_concurrent_method_count) by (component)"
# con=serviceweaver_concurrent_method_count
suffix="{caller=\"*\"}"
percentile=50.0

metric="histogram_quantile(50.0,sum(
    rate(serviceweaver_internal_method_latency_micros_bucket[30s])
  ) by (component, method, le)
  )"
echo $metric
started=serviceweaver_started_method_count$suffix
finished=serviceweaver_finished_method_count$suffix
# query "sum($started) by (component) - sum($finished) by (component)"
query "$metric"