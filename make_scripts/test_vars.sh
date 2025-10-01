#!/bin/bash

# Print information about env variables set by files in `SocialWeaver/cfg`.

declare -A overriden
declare -A normal

var_pat="^([a-zA-Z_]+)=([^#\ ]*)"


for f in $CFG_FILES; do
  while read a; do
    if [[ $a =~ $var_pat ]]; then
      var_name=${BASH_REMATCH[1]}
      var_set=${BASH_REMATCH[2]}
    else
      continue
    fi
    var_value=${!var_name}
    if [[ $var_value = $var_set ]]; then
      normal[$var_name]=$var_value
    else
      overriden[$var_name]=$var_value
    fi
  done <$f
done 

echo OVERRIDEN:
for a in ${!overriden[@]}; do
  echo $a=${overriden[$a]}
done

echo
echo normal:
for a in ${!normal[@]}; do
  echo $a=${normal[$a]}
done

