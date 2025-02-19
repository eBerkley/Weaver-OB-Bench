#!/bin/bash

# This script MODIFIES groups.yaml. It does NOT reset it from the template. 
# Therefore, set_pod_[replicas|scaling].sh must be called first.

SCHEME=${SCHEME:-$1}
C_SCHEME=${C_SCHEME:-$2}
GROUPS_FILE=${GROUPS_FILE:-"release/generated/groups.yaml"}
SCHEME_DIR=${SCHEME_DIR:-'release/base/colocation'}
RESOURCE_SPEC_FILE=${RESOURCE_SPEC_FILE:-'release/base/resourceSpec.yaml'}

SCHEME_PATH=$SCHEME_DIR/$SCHEME

SCHEME_FILE=$SCHEME_PATH/spec.yaml
CSCHEME_FILE=$SCHEME_PATH/$C_SCHEME.cfg


get_group_names () {
  local pattern="- name: ([a-z_\-]+)"
  IFS=$'\n'

  for line in $(grep -e '- name:' $SCHEME_FILE); do
    if [[ $line =~ $pattern ]]; then echo ${BASH_REMATCH[1]}; fi
  done
}

for name in $(get_group_names); do
  pattern="^$name=([0-9]+)"
  cores=1
  for def in $(cat $CSCHEME_FILE); do
    if [[ $def =~ $pattern ]]; then
      cores=${BASH_REMATCH[1]}
      break
    fi
  done
  
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