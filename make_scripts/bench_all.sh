#!/bin/bash



loop_body () {

  local fname=$1
  local name=$2
  local cfg=$3
  
  make bench_once
  
  # if there are already results in here
  if [ -d "benchmark/out/$name" ]; then
    rm -rf benchmark/out_old/$name
	mkdir -p benchmark_out_old
    mv benchmark/out/$name-$cfg benchmark/out_old/$name-$cfg
  fi
  mkdir -p benchmark/out/$name-$cfg
  #mkdir -p benchmark/out/$name-$cfg/imgs
  mv benchmark/stats benchmark/out/$name-$cfg/stats
  cat benchmark/out/$name-$cfg/stats/lat_stats_history.csv | grep -o "Aggregated[^\n]*" > benchmark/out/$name-$cfg/stats/aggregated.csv
  mkdir -p benchmark/stats

}

# =*=*=*=*=*=*=*=*=*=*= PICK ONE =*=*=*=*=*=*=*=*=*=*=

# ===== Specify tests =====
for cfg in cfgs/*;
do
	echo $cfg
	cp $cfg CONFIG.cfg
	fname=$SCHEME_DIR/$SCHEME.yaml
	name=$(basename $fname .yaml)

# =========================

# ======== Run all ========
# for fname in $COLOCATION_FNAMES; do
#   name=$(basename $fname .yaml)
# =========================


  loop_body $fname $name $cfg
done

