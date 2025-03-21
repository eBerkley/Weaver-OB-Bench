#!/bin/bash

SCALING_SPEC_FILE=${SCALING_SPEC_FILE:-'release/base/scalingSpec.yaml'}
GROUPS_FILE=${GROUPS_FILE:-'release/generated/groups.yaml'}

SCHEME_FILE=$SCHEME_DIR/${SCHEME:-$1}/spec.yaml

# One of the files in alloc/
alloc_lines=$(cat ${ALLOC_FILE:-$2})


cp $SCHEME_FILE $GROUPS_FILE

# pattern="([a-z_\-]+),([0-9]+),([0-9]+)m,([0-9]+)m"
pattern="([a-z_\-]+)=([0-9]+)"

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
    # echo $str2\g
    # Now we do the stuff for statefulSpec attributes.
    stateful_spec="
    statefulSpec:
      replicas: $replicas"

    str=s/\<"$podname"_STATEFUL_SPEC\>/$stateful_spec
    str2=$(echo "$str" | awk '{printf "%s\\n", $0}')
    # echo "$str2/g"
    sed -i "$str2/g" $GROUPS_FILE
  fi
done

# This just fixes the indentation of all the scalingSpec lines.
sed -i  -e "s/scalingSpec/    scalingSpec/g" \
        -e "s/minReplicas/    minReplicas/g" \
        -e "s/maxReplicas/    maxReplicas/g" \
        -e "s/behavior/    behavior/g"\
        -e "s/scaleDown/    scaleDown/g"\
        -e "s/selectPolicy/    selectPolicy/g"\
        -e "s/scaleUp/    scaleUp/g"\
        -e "s/policies/    policies/g"\
        -e "s/- type: Pods/    - type: Pods/g"\
        -e "s/value: 5/    value: 5/g"\
        -e "s/periodSeconds/    periodSeconds/g"\
        -e "s/metrics/    metrics/g" \
        -e "s/- type: Resource/    - type: Resource/g" \
        -e "s/resource/    resource/g" \
        -e "s/name: cpu/    name: cpu/g" \
        -e "s/target/    target/g" \
        -e "s/type: Utilization/    type: Utilization/g" \
        -e "s/averageUtilization/    averageUtilization/g" \
        $GROUPS_FILE