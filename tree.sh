#!/bin/bash

# Do not pass in the full name, e.g. M_Ch_R_...
# Just do the group name, e.g. M, MCh, ...

# Note: This file is meant to aid in feeding data in to benchmark/analyze.py. 
# Best way to use it is to just run ./tree.sh M, and it'll print out the best
# M group for every metric.

group=""
rmc=""

mode=""
for i in "$@"; do
  case $i in
    --cmp|cmp)
      mode=cmp
      ;;
    --avg|avg)
      mode=avg
      ;;
    --all|all)
      mode=all
      ;;
    *)
      if [[ -z $group ]]; then
        group=$i
      else
        rmc=$i
      fi
  esac
done

schemes=$group


if [[ $group = "Ch" ]]; then
  schemes="M_Ch_R_S_A_Cu_Ca_E_Pa_Cc_Pr"
else
  res=$(basename $(ls benchmark/results | grep -E ^$group"_"[a-zA-Z_]+.csv) .csv)
  if [[ $? != 0 ]] || [[ $res = ".csv" ]]; then
    schemes="" 
  else
    schemes=$res
  fi
fi

if [[ $mode = "all" ]]; then

  for a in $(ls benchmark/results); do
    # if echo $a | grep "_" >/dev/null; then
    if grep $(basename $a .csv) grpFile.txt >/dev/null; then
      schemes+=" $(basename $a .csv)"
    # else
      # echo $a
    fi
  done
  # echo $schemes | python3 ./benchmark/analyze.py -m cmp_many # -v p50
  echo $schemes | python3 ./benchmark/analyze.py -m graph_many -n Aggregate # -v p50
  exit 0

elif [[ $mode = "avg" ]]; then

  if [[ -n $rmc ]]; then
    # schemes=$(./utils/rm_comp.sh $group $rmc)
    # if ! $(ls benchmark/results | grep $schemes >/dev/null); then schemes=""; fi

    for a in $(./utils/next_grps.sh $group --full --all); do
      rmed=$(./utils/rm_comp.sh $a $rmc) # Technically doing this with rmc = Ch would result in fake schemes, e.g. ME.
      if $(ls benchmark/results | grep $rmed >/dev/null); then # This line fixes that.
        
        # Only add rmed to schemes if it does not exist in schemes already.
        found=0
        old_IFS=$IFS
        IFS=$' '
        for s in $schemes; do if [[ $s = $rmed ]]; then found=1; break; fi done
        IFS=$old_IFS
        if [[ $found = 0 ]]; then schemes+=" $rmed"; fi

      fi
    done
  else
    for a in $(./utils/next_grps.sh $group --all --full); do
      if $(ls benchmark/results | grep $a >/dev/null); then
        # python3 ./benchmark/analyze.py -m cmp -n $1 -n2 $a
        schemes+=" $a"
      fi
    done
  fi # -z $rmc

  echo $schemes | python3 ./benchmark/analyze.py -m avg 

elif [[ $mode = "cmp" ]]; then
  if [[ ! -z $rmc ]]; then

    for a in $(./utils/next_grps.sh $group --full --all); do
      if $(ls benchmark/results | grep $a >/dev/null); then
        rmed=$(./utils/rm_comp.sh $a $rmc)
        if $(ls benchmark/results | grep $rmed >/dev/null); then
          python3 ./benchmark/analyze.py -m cmp -n $rmed -n2 $a
        fi
      fi
    done

  else # [[ -z $rmc ]];

    for a in $(./utils/next_grps.sh $group --all --full); do
      if $(ls benchmark/results | grep $a >/dev/null); then
        schemes+=" $a"
      fi
    done
    echo $schemes | python3 ./benchmark/analyze.py -m rank -u 30000 -v p99 # cmp_many    

  fi 
elif [[ -z $rmc ]]; then 
  # for a in $(ls benchmark/results); do
  #   schemes+=" $(basename $a .csv)"
  # done

  for a in $(./utils/next_grps.sh $group --full --all); do
    if $(ls benchmark/results | grep $a >/dev/null); then
      # python3 ./benchmark/analyze.py -m cmp -n $1 -n2 $a
      schemes+=" $a"
    fi
  done
  #  NOTE: adding back the v p50 will make it output in csv form.
  echo $schemes | python3 ./benchmark/analyze.py -m cmp_many # -v p50

else # tree but with some components banished
  
  schemes=$(./utils/rm_comp.sh $group $rmc)
  if ! $(ls benchmark/results | grep $schemes >/dev/null); then schemes=""; fi

  for a in $(./utils/next_grps.sh $group --full --all); do
    rmed=$(./utils/rm_comp.sh $a $rmc) # Technically doing this with rmc = Ch would result in fake schemes, e.g. ME.
    if $(ls benchmark/results | grep $rmed >/dev/null); then # This line fixes that.
      found=0

      old_IFS=$IFS
      IFS=$' '
      for s in $schemes; do
        if [[ $s = $rmed ]]; then found=1; break; fi
      done
      IFS=$old_IFS

      if [[ $found = 0 ]]; then
      # if ! $(echo $schemes | grep -E -e "$rmed" ); then
        schemes+=" $rmed"
      fi
    fi
  done

  echo $schemes | python3 ./benchmark/analyze.py -m cmp_many
fi