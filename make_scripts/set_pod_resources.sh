#!/bin/bash

# This script is used to fill in the <podname_RESOURCE_SPEC> lines.
# This determines each deployment's cpu cores.
# It is used for fixed bench types, but modifies the functionality so as to not use cschemes.

# This script MODIFIES groups.yaml. It does NOT reset it from the template. 
# Therefore, set_pod_[replicas|scaling].sh must be called first.

SCHEME=${SCHEME:-$1}
C_SCHEME=${C_SCHEME:-$2}
BENCH_TYPE=${BENCH_TYPE:-$3}

GROUPS_FILE=${GROUPS_FILE:-"release/generated/groups.yaml"}
SCHEME_DIR=${SCHEME_DIR:-'release/base/colocation'}
RESOURCE_SPEC_FILE=${RESOURCE_SPEC_FILE:-'release/base/resourceSpec.yaml'}

SCHEME_PATH=$SCHEME_DIR/$SCHEME

SCHEME_FILE=$SCHEME_PATH/spec.yaml
CSCHEME_FILE=$SCHEME_PATH/$C_SCHEME.cfg
GROUPS_HEIGHT=$SCHEME_PATH/groups_height.cfg

echo set_pod_resources.sh >> $DEBUG_OUTPUT

get_group_names () {
  local pattern="- name: ([a-z_\-]+)"
  IFS=$'\n'

  for line in $(grep -e '- name:' $SCHEME_FILE); do
    if [[ $line =~ $pattern ]]; then echo ${BASH_REMATCH[1]}; fi
  done
}

cscheme_pattern="^$name=([0-9]+)"

for name in $(get_group_names); do
  cores=1
  if [[ $BENCH_TYPE = 'FIXED' ]]; then  # : We don't read from cscheme file
    if [[ $name = $FIXED ]]; then
      cores=$FIXED_HEIGHT
      echo fixing $name to height $cores >> $DEBUG_OUTPUT
    fi # if name != fixed || fixed direction = OUT, the fallback of 1 is what we want anyways.

  elif [[ $BENCH_TYPE = 'HETERO_HT' ]]; then
    # Check if current group is listed in hetero_ht.cfg
    for def in $(cat $GROUPS_HEIGHT); do
      if [[ $def =~ ^$name=([0-9]+) ]]; then
        cores=${BASH_REMATCH[1]}
        echo "HETERO_HT: $name -> $cores" >> $DEBUG_OUTPUT
        break
      fi
    done
  
  else # BENCH_TYPE != FIXED  : Read from cscheme file
  
    for def in $(cat $CSCHEME_FILE); do
      if [[ $def =~ $cscheme_pattern ]]; then
        cores=${BASH_REMATCH[1]}
        echo $name: $cores >> $DEBUG_OUTPUT
        break
      fi
    done
  fi

  
  resource_spec=$(sed -z -e s#\<CORES\>#$cores#g $RESOURCE_SPEC_FILE)

  str=s/\<"$name"_RESOURCE_SPEC\>/$resource_spec
  str2=$(echo "$str" | awk '{printf "%s\\n", $0}')
  
  
  
  sed -i "$str2/g" $GROUPS_FILE
done

sed -i  -e "s/resourceSpec/    resourceSpec/g" \
        -e "s/requests/    requests/g" \
        -e "s/cpu:/    cpu:/g" \
        -e "s/memory:/    memory:/g" \
        -e "s/limits/    limits/g" \
        $GROUPS_FILE
