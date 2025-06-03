#!/bin/bash

# This script is used to fill in the <podname_SCALING_SPEC> lines.
# This determines each deployment's initial replicas, max replicas, and required util to scale out.
# It is used for any non-static bench type.
SCHEME=${SCHEME:-$1}
SCALING_SPEC_FILE=${SCALING_SPEC_FILE:-'release/base/scalingSpec.yaml'}

SCALING_DEFS_FILE=${SCALING_DEFS_FILE:-"release/base/colocation/scalingdefs.cfg"}

GROUPS_FILE=${GROUPS_FILE:-'release/generated/groups.yaml'}

SCHEME_FILE=$SCHEME_DIR/$SCHEME/spec.yaml
BENCH_TYPE=${BENCH_TYPE:-$2}

ALLOC_FILE=${ALLOC_FILE:-$3}
if [[ $ALLOC_FILE = "*" ]]; then
  if [[ -r "alloc/$SCHEME.cfg" ]]; then
    ALLOC_FILE="alloc/$SCHEME.cfg"
  else 
    ALLOC_FILE=""
  fi
fi

#                   name      = min    , max    , util threshold
full_alloc_pattern="[a-z_\-]+=([0-9]+),([0-9]+),([0-9]+)"
less_alloc_pattern="[a-z_\-]+=([0-9]+),([0-9]+)"
min_alloc_pattern="[a-z_\-]+=([0-9]+)"

cp $SCHEME_FILE $GROUPS_FILE

echo set_pod_scaling.sh >> $DEBUG_OUTPUT
get_group_names () {
  local pattern="- name: ([a-z_\-]+)"
  IFS=$'\n'

  for line in $(grep -e '- name:' $SCHEME_FILE); do
    if [[ $line =~ $pattern ]]; then echo ${BASH_REMATCH[1]}; fi
  done
}

for name in $(get_group_names); do
  pattern="^$name=([A-Z]+)"
  type=FALLBACK
  if [[ $BENCH_TYPE = 'FIXED' ]] && [[ $name = $FIXED ]]; 
    then type='FIXED'; 

  else
    for scale_def in $(cat $SCALING_DEFS_FILE); do
      if [[ $scale_def =~ $pattern ]]; then
        type=${BASH_REMATCH[1]}
        break
      fi
    done
    
  fi

  # for statefulspec stuff, see below.
  stateful_replicas=

  # -e expressions, in order:
  # 1: define MIN_REPLICAS to be that of the scaling type
  # 2: define MAX_REPLICAS to be the default for scaling benchmarks, OB_REPLICAS
  # 3: define AVERAGE_UTILIZATION to be that of the scaling type
  if [[ $type = 'FIXED' ]]; then
    width=$FIXED_WIDTH
    
    echo setting width = $width for fixed component. >> $DEBUG_OUTPUT

    scaling_spec=$(\
      sed -z -e s#\<MIN_REPLICAS\>#$width#g \
      -e s#\<MAX_REPLICAS\>#$width#g \
      -e s#\<AVERAGE_UTILIZATION\>#100#g \
      $SCALING_SPEC_FILE )

  else

    line=$(grep -e "^$name=" ${ALLOC_FILE:-"/dev/null"})

    if [[ $line =~ $full_alloc_pattern ]]; then
      
      
      min_replicas=${BASH_REMATCH[1]}
      max_replicas=${BASH_REMATCH[2]}
      cpu_util=${BASH_REMATCH[3]}
      
      if grep -e "$name"_STATEFUL_SPEC $SCHEME_FILE >/dev/null; then # detect productcatalogservice replicas
        stateful_replicas=$min_replicas
      fi

    elif [[ $line =~ $less_alloc_pattern ]]; then
      
      min_replicas=${BASH_REMATCH[1]}
      max_replicas=${BASH_REMATCH[2]}
      cpu_util=\<"$type"_SCALE_UTIL\>
      
      if grep -e "$name"_STATEFUL_SPEC $SCHEME_FILE >/dev/null; then 
        stateful_replicas=$min_replicas
      fi
    elif [[ $line =~ $min_alloc_pattern ]]; then
      min_replicas=${BASH_REMATCH[1]}
      max_replicas=\<OB_REPLICAS\>
      cpu_util=\<"$type"_SCALE_UTIL\>

      if grep -e "$name"_STATEFUL_SPEC $SCHEME_FILE >/dev/null; then 
        stateful_replicas=$min_replicas
      fi

    else
      min_replicas=\<"$type"_MIN_REPLICAS\>
      max_replicas=\<OB_REPLICAS\>
      cpu_util=\<"$type"_SCALE_UTIL\>

    fi

    scaling_spec=$(\
      sed -z -e s#\<MIN_REPLICAS\>#$min_replicas#g \
      -e s#\<MAX_REPLICAS\>#$max_replicas#g \
      -e s#\<AVERAGE_UTILIZATION\>#$cpu_util#g \
      $SCALING_SPEC_FILE )
  fi
  
  # sed seems to have issues replacing a search pattern with a string that has multiple lines and tab indents. 
  # str2 is str without the indents and literal newlines.
  # After the for loop is done, we fix the indentation.
  str=s/\<"$name"_SCALING_SPEC\>/$scaling_spec
  str2=$(echo "$str" | awk '{printf "%s\\n", $0}')
  sed -i "$str2/g" $GROUPS_FILE


  # Now we do the stuff for statefulSpec attributes.
  if [[ $type = 'FIXED' ]]; then
    replicas=$FIXED_WIDTH
  else
    replicas=${stateful_replicas:-$PRODUCT_CATALOG_REPLICAS}
  fi
  stateful_spec="
    statefulSpec:
      replicas: $replicas"

  str=s/\<"$name"_STATEFUL_SPEC\>/$stateful_spec
  str2=$(echo "$str" | awk '{printf "%s\\n", $0}')

  sed -i "$str2/g" $GROUPS_FILE
  
  
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