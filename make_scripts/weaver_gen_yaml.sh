#!/bin/bash
# This file resets all of the config values in the generated kube.yaml file, 
# and then sets them based on current env variables.
# Additionally, adds the current fusion scheme to the generated kube.yaml file.
#
# ***Note***: if load_gen_yaml.sh is ran *before* this script is ran,
# the deployment ***WILL NOT*** work.

# Reset config values
cp $KUBE_BASE_YAML $KUBE_GEN_YAML

# Copy fusion config
cat $SCHEME_DIR/$SCHEME.yaml >> $KUBE_GEN_YAML

# Docker repo
sed -i "s#<DOCKER>#$DOCKER#g" $KUBE_GEN_YAML 

# Cores per pod
sed -i "s#<OB_CORES>#$OB_CORES#g" $KUBE_GEN_YAML

# Max replicas per fusion group
sed -i "s#<OB_REPLICAS>#$OB_REPLICAS#g" $KUBE_GEN_YAML

sed -i "s#<CRITICAL_SCALE_UTIL>#${CRITICAL_SCALE_UTIL:-$FALLBACK_SCALE_UTIL}#g" $KUBE_GEN_YAML
sed -i "s#<NONCRITICAL_SCALE_UTIL>#${NONCRITICAL_SCALE_UTIL:-$FALLBACK_SCALE_UTIL}#g" $KUBE_GEN_YAML
sed -i "s#<TRIVIAL_SCALE_UTIL>#${TRIVIAL_SCALE_UTIL:-$FALLBACK_SCALE_UTIL}#g" $KUBE_GEN_YAML
sed -i "s#<FALLBACK_SCALE_UTIL>#$FALLBACK_SCALE_UTIL#g" $KUBE_GEN_YAML

sed -i "s#<CRITICAL_MIN_REPLICAS>#${CRITICAL_MIN_REPLICAS:-$FALLBACK_MIN_REPLICAS}#g" $KUBE_GEN_YAML
sed -i "s#<NONCRITICAL_MIN_REPLICAS>#${NONCRITICAL_MIN_REPLICAS:-$FALLBACK_MIN_REPLICAS}#g" $KUBE_GEN_YAML
sed -i "s#<TRIVIAL_MIN_REPLICAS>#${TRIVIAL_MIN_REPLICAS:-$FALLBACK_MIN_REPLICAS}#g" $KUBE_GEN_YAML
sed -i "s#<FALLBACK_MIN_REPLICAS>#$FALLBACK_MIN_REPLICAS#g" $KUBE_GEN_YAML

# Determine deployer command based on the first argument.
# Default to "telemetry-local" if no argument is provided.
DEPLOYER_CMD=${1:-weaver-kube}
echo "Using deployer command: $DEPLOYER_CMD"

# Generate kubernetes yaml from weaver kube specification yaml
# The output is the generated file location (something like /tmp/kube_[0-9a-z]{6}.yaml)
yaml=$($DEPLOYER_CMD deploy $KUBE_GEN_YAML 2>>$DEBUG_OUTPUT)

# The [0-9a-z]{6} part of the filename is extracted below.
deployment=$(echo $yaml | sed 's/\/tmp\/kube_\([0-9a-z]\+\)\.yaml/\1/g')

# Print the deployment name to stdout and logs file for debugging
echo version = $deployment | tee -a $LOGS_FILE

# Write version to version file so that load generator can use it
echo $deployment > $VERSION_FILE

# Replace release/generated/gen.yaml with updated version.
cp $yaml $WEAVER_GEN_YAML
