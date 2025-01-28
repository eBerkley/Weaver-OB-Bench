#!/bin/bash

SCALING_SPEC_FILE='release/base/scalingSpec.yaml'
GROUPS_FILE=release/generated/groups.yaml

SCHEME_FILE=$SCHEME_DIR/${SCHEME:-$1}.yaml

# One of the files in alloc/
alloc_lines=$(cat ${ALLOC_FILE:-$2})


cp $SCHEME_FILE $GROUPS_FILE

pattern="([a-z_]+),([0-9]+),([0-9]+)m,([0-9]+)m"

for l in $alloc_lines; do
  if [[ $l =~ $pattern ]]; then
    podname=${BASH_REMATCH[1]}
    replicas=${BASH_REMATCH[2]}
    # total_util=${BASH_REMATCH[3]}
    # avg_util=${BASH_REMATCH[4]}
    
    scaling_spec=$(\
      sed -e "s#<MIN_REPLICAS>#$replicas#g" \
        -e "s#<MAX_REPLICAS>#$replicas#g" \
        -e "s#<AVERAGE_UTILIZATION>#100#g" \
        $SCALING_SPEC_FILE)

    
    # sed seems to have issues replacing a search pattern with a string that has multiple lines and tab indents. 
    # str2 is str without the indents and literal newlines.
    # After the for loop is done, we fix the indentation.
    str=s/\<"$podname"_SCALING_SPEC\>/$scaling_spec
    str2=$(echo "$str" | awk '{printf "%s\\n", $0}')
    sed -i "$str2/g" $GROUPS_FILE
  fi
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