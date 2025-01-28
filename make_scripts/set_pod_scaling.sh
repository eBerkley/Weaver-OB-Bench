#!/bin/bash

# SCALING_SPEC_FILE="release/base/scalingSpec.yaml"
# SCALING_DEFS_FILE="release/base/colocation/scalingdefs.cfg"
# GROUPS_FILE=release/generated/groups.yaml

SCHEME_FILE=$SCHEME_DIR/$SCHEME.yaml

cp $SCHEME_FILE $GROUPS_FILE


get_group_names () {
  local pattern="- name: ([a-z_]+)"
  IFS=$'\n'

  for line in $(grep -e '- name:' $SCHEME_FILE); do
    if [[ $line =~ $pattern ]]; then echo ${BASH_REMATCH[1]}; fi
  done
}

for name in $(get_group_names); do
  pattern="$name=([A-Z]+)"
  if [[ $(grep -e $name $SCALING_DEFS_FILE ) =~ $pattern ]]; then
    type=${BASH_REMATCH[1]}
  else
    type=FALLBACK
  fi  

  # -e expressions, in order:
  # 1: define MIN_REPLICAS to be that of the scaling type
  # 2: define MAX_REPLICAS to be the default for scaling benchmarks, OB_REPLICAS
  # 3: define AVERAGE_UTILIZATION to be that of the scaling type

  scaling_spec=$(\
    sed -z -e s#\<MIN_REPLICAS\>#\<"$type"_MIN_REPLICAS\>#g \
    -e s#\<MAX_REPLICAS\>#\<OB_REPLICAS\>#g \
    -e s#\<AVERAGE_UTILIZATION\>#\<"$type"_SCALE_UTIL\>#g \
    $SCALING_SPEC_FILE )

  # sed seems to have issues replacing a search pattern with a string that has multiple lines and tab indents. 
  # str2 is str without the indents and literal newlines.
  # After the for loop is done, we fix the indentation.
  str=s/\<"$name"_SCALING_SPEC\>/$scaling_spec
  str2=$(echo "$str" | awk '{printf "%s\\n", $0}')
  sed -i "$str2/g" $GROUPS_FILE
  
done

# This just fixes the indentation of all the scalingSpec lines.
sed -i  -e "s/scalingSpec/\t\tscalingSpec/g" \
        -e "s/minReplicas/\t\tminReplicas/g" \
        -e "s/maxReplicas/\t\tmaxReplicas/g" \
        -e "s/metrics/\t\tmetrics/g" \
        -e "s/- type/\t\t- type/g" \
        -e "s/resource/\t\tresource/g" \
        -e "s/name: cpu/\t\tname: cpu/g" \
        -e "s/target/\t\t\ttarget/g" \
        -e "s/type: Utilization/\t\t\ttype: Utilization/g" \
        -e "s/averageUtilization/\t\t\taverageUtilization/g" \
        $GROUPS_FILE