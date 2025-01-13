#!/bin/bash

# Use tmp logs file as aggregate of logs
cat $LOGS_FILE > $TMP_LOGS



loop_body () {

  local fname=$1
  local name=$2
  local cfg=$3


  
  # Create the dir that the next batch of stats will use
  mkdir -p benchmark/stats

  # run the benchmark
  make bench_once

  # Terminate the benchmark
  kubectl delete all --all

  # if there are already results in here
  if [ -d "benchmark/out/$name-$cfg" ]; then
    rm -rf benchmark/out_old/$name-$cfg
	  mkdir -p benchmark/out_old
    mv benchmark/out/$name-$cfg benchmark/out_old/$name-$cfg
  fi

  # Create the dir results will be stored in
  mkdir -p benchmark/out/$name-$cfg
  
  # Move the stats dir into the dir created above
  mv benchmark/stats benchmark/out/$name-$cfg/stats

  # Create aggregated.csv that only has the aggregate latency stats
  cat benchmark/out/$name-$cfg/stats/lat_stats_history.csv | grep -o "Aggregated[^\n]*" > benchmark/out/$name-$cfg/stats/aggregated.csv

  # Append logs from this run into tmp
  cat $LOGS_FILE >> $TMP_LOGS
  # Save logs from this run into out dir
  cp $LOGS_FILE benchmark/out/$name-$cfg/logs.txt
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


  loop_body $fname $name $cfg
done

# Update logs file as aggregate
cat $TMP_LOGS > $LOGS_FILE
# Remove temp logs
rm $TMP_LOGS
