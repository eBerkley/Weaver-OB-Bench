#!/bin/bash

# cd $(dirname $0)/..

loop_body () {
  local name=$1
  export SCHEME=$name
  ./make_scripts/pre_bench.sh
  # make bench
  ./scripts/pull_stats.sh 
	echo deleting deployment...
	./scripts/stop.sh >/dev/null
  ./make_scripts/post_bench.sh
}

# =*=*=*=*=*=*=*=*=*=*= PICK ONE =*=*=*=*=*=*=*=*=*=*=

# ===== Specify tests =====
for name in frontend monolith mixed; do
# =========================

# ======== Run all ========
# for fname in $COLOCATION_FNAMES; do
#   name=$(basename $fname .yaml)
# =========================

  loop_body $name
done