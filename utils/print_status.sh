#!/bin/bash

# Get the number of schemes that are done, 
# have allocs collected, in cfgs, or have not been touched.

done=""
in_progress=""
partial=""
not_started=""

n_done=0
n_in_progress=0
n_partial=0
n_not_started=0

for l in $(cat grpFile.txt); do
  name=${l## }
  if [[ $(ls benchmark/out | grep $name) != "" ]] && [[ ! $(grep BENCH_TYPE=ALLOC benchmark/out/$name/info.txt ) ]]; then
    done="$done\n$name"
    (( n_done++ ))
  elif [[ $(ls cfgs | grep $name ) != "" ]]; then
    in_progress="$in_progress\n$name"
    (( n_in_progress++ ))
  elif [[ $(ls alloc | grep $name) != "" ]]; then
    partial="$partial\n$name"
    (( n_partial++ ))
  else 
    not_started="$not_started\n$name"
    (( n_not_started++ ))
  fi
done
sep=------------------------------
echo -e "Done: $n_done\n$sep$done\n"
echo -e "In Progress: $n_in_progress\n$sep$in_progress\n"
echo -e "Partial: $n_partial\n$sep$partial\n"
echo -e "Not Started: $n_not_started\n$sep$not_started"

echo -e "\nBreakdown:\n$sep"

echo "Done:        $n_done"
echo "In Progress: $n_in_progress"
echo "Partial:     $n_partial"
echo "Not Started: $n_not_started"