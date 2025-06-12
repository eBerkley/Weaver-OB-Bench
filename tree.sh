#!/bin/bash

# Do not pass in the full name, e.g. M_Ch_R_...
# Just do the group name, e.g. M, MCh, ...

group=""
rmc=""

mode=""
for i in "$@"; do
  case $i in
    --cmp|cmp)
      mode=cmp
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
  schemes="M"
else
  res=$(basename $(ls benchmark/results | grep ^$group"_") .csv)
  if [[ $? != 0 ]] || [[ $res = ".csv" ]]; then
    schemes="" 
  fi
fi

if [[ $mode = "cmp" ]]; then
  if [[ -z $rmc ]]; then

    for a in $(./utils/next_grps.sh $group --full); do
      if $(ls benchmark/results | grep $a >/dev/null); then
        rmed=$(./utils/rm_comp.sh $a $rmc)
        if $(ls benchmark/results | grep $rmed >/dev/null); then
          python3 ./benchmark/analyze.py -m cmp -n $rmed -n2 $a
        fi
      fi
    done

  else # [[ ! -z $rmc ]];

    for a in $(./utils/next_grps.sh $group --full); do
      if $(ls benchmark/results | grep $a >/dev/null); then
        # python3 ./benchmark/analyze.py -m cmp -n $1 -n2 $a
        schemes+=" $a"
      fi
    done
    echo $schemes | python3 ./benchmark/analyze.py -m rank -u 10000 -v p50 # cmp_many    

  fi 
elif [[ -z $rmc ]]; then 

  for a in $(./utils/next_grps.sh $group --full); do
    if $(ls benchmark/results | grep $a >/dev/null); then
      # python3 ./benchmark/analyze.py -m cmp -n $1 -n2 $a
      schemes+=" $a"
    fi
  done

  echo $schemes | python3 ./benchmark/analyze.py -m cmp_many 

else # tree but with some components banished
  
  schemes=$(./utils/rm_comp.sh $group $rmc)
  if ! $(ls benchmark/results | grep $schemes >/dev/null); then schemes=""; fi

  for a in $(./utils/next_grps.sh $group --full); do
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