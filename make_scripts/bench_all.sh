#!/bin/bash

# Use tmp logs file as aggregate of logs
cat $LOGS_FILE > $TMP_LOGS

# We delete at start, just in case.
# minikube delete

if [[ $BENCH_TYPE = "STATIC" ]]; then
  echo We will be pinning kube-system processes to their own cores before running any benchmark.
  echo This requires sudo.
  sudo echo
fi

# Once every n benchmarks, clear docker cache 
# prevents running out of space.
DOCKER_CACHE_CLEAR_FREQ=3

i=0

maybe_clear_cache () {
  (( i++ ))
  # if [ $(( i % $DOCKER_CACHE_CLEAR_FREQ )) -eq 0 ]; then
  #   minikube delete
  #   docker system prune -af
  # fi
}

loop_body () {

  local fname=$1
  local name=$2
  local cfg=$3

  maybe_clear_cache

  
  # Create the dir that the next batch of stats will use
  mkdir -p benchmark/stats

  start_time=$(date)
  make bench

  end_time=$(date)

  # Terminate the benchmark
  # kubectl delete all --all
  
  sleep 15

  # if there are already results in here
  if [ -d "benchmark/out/$cfg" ]; then
    rm -rf benchmark/out_old/$cfg
	  mkdir -p benchmark/out_old
    mv benchmark/out/$cfg benchmark/out_old/$cfg
  fi

  # Create the dir results will be stored in
  mkdir -p benchmark/out/$cfg
  
  if [ "$TRACE_ENABLE" = "true" ]; then
    cp jaeger_traces benchmark/out/$cfg/jaeger_traces
  elif [ "$METRICS_PROFILE" = "true" ]; then
    cp metrics_collection benchmark/out/$cfg/metrics
  elif [ "$INSTFP_ENABLE" = "true" ]; then
    cp inst_fp_collection benchmark/out/$cfg/instfp_collection
  fi

  if [ "$RUNTIME_METRIC_ENABLE" = "true" ]; then
    mv metrics_collection/$SCHEME metrics_collection/$cfg
  fi
  # Move the stats dir into the dir created above
  mv benchmark/stats benchmark/out/$cfg/stats

  # Create aggregated.csv that only has the aggregate latency stats
  echo "Timestamp,User Count,Type,Name,Requests/s,Failures/s,50%,66%,75%,80%,90%,95%,98%,99%,99.9%,99.99%,100%,Total Request Count,Total Failure Count,Total Median Response Time,Total Average Response Time,Total Min Response Time,Total Max Response Time,Total Average Content Size" > benchmark/out/$cfg/stats/aggregated.csv
  
  cat benchmark/out/$cfg/stats/lat_stats_history.csv | grep "Aggregated" >> benchmark/out/$cfg/stats/aggregated.csv
  
  
  # Append logs from this run into tmp
  cat $LOGS_FILE >> $TMP_LOGS
  # Save logs from this run into out dir
  cp $LOGS_FILE benchmark/out/$cfg/logs.txt

  # Write info into dir
  echo start: $start_time              >benchmark/out/$cfg/info.txt
  echo end: $end_time                 >>benchmark/out/$cfg/info.txt
  echo config.cfg:                    >>benchmark/out/$cfg/info.txt
  cat CONFIG.cfg                      >>benchmark/out/$cfg/info.txt
  echo                                >>benchmark/out/$cfg/info.txt 
  echo .env:                          >>benchmark/out/$cfg/info.txt 
  grep -ve '#' .env | grep -e '[A-Z]' >>benchmark/out/$cfg/info.txt 

  echo locust.env:                          >>benchmark/out/$cfg/info.txt
  grep -ve '#' locust.env | grep -e '[A-Z]' >>benchmark/out/$cfg/info.txt 
  
  # Clear logs for use with next run
  printf "" > $LOGS_FILE

}

# =*=*=*=*=*=*=*=*=*=*= PICK ONE =*=*=*=*=*=*=*=*=*=*=

# ============ Run All cfg files =============
for cfg in cfgs/*; do
  
  # Update the value of $SCHEME
  source $cfg 
  
	echo $cfg
	cp $cfg CONFIG.cfg 
	fname=$SCHEME_DIR/$SCHEME.yaml
	name=$(basename $fname .yaml)

# ============================================

# Note: Currently, is not actually supported.
# ======== Run all colocation schemes ========
# for fname in $COLOCATION_FNAMES; do
#   name=$(basename $fname .yaml)
# ============================================


  loop_body $fname $name $(basename $cfg .cfg)
done

# Update logs file as aggregate
cat $TMP_LOGS > $LOGS_FILE
# Remove temp logs
rm $TMP_LOGS

# Finished.
# minikube delete