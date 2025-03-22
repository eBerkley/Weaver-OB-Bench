#!/bin/bash
cores=${1:-36}

out_path=benchmark/out
fscheme_path=release/base/colocation

cfg_pattern="([a-z\-]+)_([0-9a-z\-]+)_([0-9]+)"

UNRAN=""
OLD=""
NOT_STATIC=""
VALID=""

for s in $fscheme_path/*; do
  if [[ ! -d $s ]]; then continue; fi
  scheme=$(basename $s)
  for c in $s/*; do
    
    if [[ $c = "$s/spec.yaml" ]]; then continue; fi
    cscheme=$(basename $c .cfg)
    fullname="$scheme"_"$cscheme"_$cores

    if [[ ! -e $out_path/$fullname ]]; then
      UNRAN+="$fullname, "
      continue
    fi
    if [[ ! -r "$out_path/$fullname/info.txt" ]]; then
      OLD+="$fullname, "
      continue
    fi

    if [[ $(grep BENCH_TYPE "$out_path/$fullname/info.txt") != "BENCH_TYPE=STATIC" ]]; then
      NOT_STATIC+="$fullname, "
      continue
    fi
    VALID+="$fullname, "
  done
done

echo unran: $UNRAN
echo valid: $VALID
echo old: $OLD
echo not static: $NOT_STATIC
