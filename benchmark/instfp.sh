#!/bin/bash
cd $(dirname $0)/..

if [[ -n $2 ]]; then
  ./utils/parse_report/parse_report --i --file benchmark/instfp_stats/"$1".txt --file2 benchmark/instfp_stats/"$2".txt

else
  ./utils/parse_report/parse_report --i --file benchmark/instfp_stats/"$1".txt
fi