#!/bin/bash
cd $(dirname $0)



print_usage() {
  echo sudo ./utils/vtune.sh username [flags]
  echo "-h, --help              print this help message."
  echo "-m=, --mode=            set which vtune analysis type to use. "
  echo "                        Defaults to uarch-exploration."
  echo "                        Set to \"custom\" to select specific hw events."
  echo "-t=, --time=[180]       collection time per analysis, in seconds."
  echo "-n=, --name=[r]         base name for each analysis result."
  echo "-s=, --scheme=          only analyze this scheme."
  echo "-g=, --group=           only analyze this group."
  echo "-c=, --cores=           only analyze with this #cores."
  echo "-i=, --interval=[1]     Set sampling interval, in ms."
  echo "-l, --low-detail        use fewer details for lower overhead." 
  echo "                        meant for use with uarch-exploration."
  echo "--retiring=[true]       collect info on retiring instructions."
  echo "--bad-spec=[true]       collect info on bad speculation."
  echo "--mem-bound=[true]      collect info on memory bound instructions."
  echo "--core-bound=[true]     collect info on core bound instructions."
  echo "-e, --event=            sample this event. "
  echo "                        meant for use with --mode=custom."
}

interval=1
detail=detailed
retiring=true
bad_spec=true
mem_bound=true
core_bound=true
PROFILE_TIME=180
mode=uarch-exploration
events=""
name=r

for i in "$@"
do
case $i in
    -m=*|--mode=*)
    mode="${i#*=}"

    ;;
    -q|--query)
    ask=1
    
    ;;
    -h|--help)
    print_usage
    exit 0
    ;;

    -t=*|--time=*)
    PROFILE_TIME="${i#*=}"
    ;;

    -n=*|--name=*)
    name="${i#*=}"
    ;;

    -s=*|--scheme=*)
    scheme_req="${i#*=}"
    ;;

    -g=*|--group=*)
    group_req="${i#*=}"
    ;;

    -c=*|--cores=*)
    cores_req="${i#*=}"
    ;;
    
    -i=*|--interval=*)
    interval="${i#*=}"
    ;;

    -e=*|--event=*)
    if [[ -n $events ]]; then
      events+=,"${i#*=}"
    else
      events="${i#*=}"
    fi
    ;;

    -l|--low-detail)
    detail=summary
    ;;

    --retiring=*)
    retiring="${i#*=}"
    ;;

    --bad-spec=*)
    bad_spec="${i#*=}"
    ;;
    
    --mem-bound=*)
    mem_bound="${i#*=}"
    ;;
    
    --core-bound=*)
    core_bound="${i#*=}"
    ;;


    *)
    username=$i
    ;;
esac
done

uset() {
  sudo -u $username PATH="$PATH:/home/$username/go/bin" $*
}

if [[ $UID -ne 0 ]]; then
  echo error: must run as root.
  exit
fi

if [[ -z $username ]]; then
  echo 'error: must set username. (recommended usage: $USER)'
  print_usage
  exit 1
fi



source ../.env

source /opt/intel/oneapi/vtune/latest/vtune-vars.sh
result_dir=/opt/intel/oneapi/vtune/vtune_results/analyze_pod


uset kubectl delete all --all

wait_constload() {
  echo beginning to wait for constload...
  str=$(uset kubectl logs --tail 1 -l app=loadgenerator)
  size=${#str}
  echo $str
  local reprint_str="\e[1A\e[K"
  while [ $size -le 5 ] || [ $size -ge 90 ]; do 
    str=$(uset kubectl logs --tail 1 -l app=loadgenerator)
    size=${#str}
    echo -e $reprint_str$str
    sleep 10
  done

  echo done waiting.
}


for cfg in ../cfgs/*; do
  source $cfg
  if [[ -n $scheme_req ]] && [[ $SCHEME != $scheme_req ]]; then continue; fi
  if [[ -n $cores_req ]] && [[ $OB_CORES != $cores_req ]]; then continue; fi

  echo $SCHEME-$OB_CORES
  # Deploy...
  uset cp $cfg ../CONFIG.cfg
  uset make -C .. deploy
  sleep 10 # surprisingly, SOME sort of sleep appears to be necessary or the line below will run before any loadgenerator pod exists
  uset kubectl wait po -l app=loadgenerator --for=condition=Ready
  
  # Wait until constload shape has hit constant rps
  wait_constload
  
  # Begin profiling.
  # for p in $(pgrep -f "/weaver/ob"); do
  # :/
  for p in $(pgrep -f "/weaver/ob" | xargs --no-run-if-empty ps | awk '{print $1}' | tail -n +2); do
    echo $p
    # will be something like 'HOSTNAME=ob-all-8huhsds-y8h23urh...'
    hostname=$(cat /proc/$p/environ | strings | grep HOSTNAME)
    
    # Extract the 'all' part of 'HOSTNAME=ob-all-8huhsds-y8h23urh...'
    fusion_group=$(echo $hostname | gawk 'match($0, /=ob-([^-]*)/, a) {print a[1]}')

    if [[ -n $group_req ]] && [[ $group_req != $fusion_group ]]; then continue; fi


    # Get set of cores this process runs under
    cpus=$(cat /proc/$p/status | grep Cpus_allowed_list | awk '{print $2}')
    
    echo "group $fusion_group is on cpu(s) $cpus."

    # the dir that this run will go to. Will be the same for collecting and reporting.
    # {at} is replaced by analysis type, e.g. uarch-exploration => ue
    
    specific_result_dir="$result_dir/$SCHEME-$fusion_group-$OB_CORES/$name@@@{at}"
    # Set flags that are agnostic to collection mode
    collect_flags=""
    collect_flags+=" --duration=$PROFILE_TIME"          # set profile duration
    collect_flags+=" -source-search-dir=../src"         # Add src files
    collect_flags+=" -search-dir=../release/generated"  # Add binary 
    collect_flags+=" -r $specific_result_dir"           # specify output dir
    collect_flags+=" -knob sampling-interval=$interval" # set sampling interval
    collect_flags+=" -finalization-mode=full"
    # set flags corresponding to -collect-with
    if [[ $mode = "custom" ]]; then
      # collect_flags+=" -knob enable-stack-collection=true" 
      collect_flags+=" -knob event-config=$events"
    else 
      collect_flags+=" -knob collect-memory-bound=$mem_bound"
      collect_flags+=" -knob collect-memory-bandwidth=$mem_bound"
      collect_flags+=" -knob collect-retiring=$retiring"
      collect_flags+=" -knob collect-bad-speculation=$bad_spec"
    fi

    
    if [[ $mode != "uarch-exploration" ]]; then
      
      # Run using hw sampling
      if [[ $mode != "custom" ]]; then
        collect_flags+=" -knob sampling-mode=hw"
      fi

    else
      collect_flags+=" -knob pmu-collection-mode=$detail"
    fi
    
    # Run 

    echo
    echo Executing vtune $mode on $SCHEME-$fusion_group-$OB_CORES...
    echo outputting collection to $specific_result_dir
    echo flags: $collect_flags

    echo running...
    echo
    
    # Collect specified metrics on process using flags specified
    if [[ $mode = "custom" ]]; then
      vtune -collect-with runsa $collect_flags -target-pid=$p
    else
      vtune -collect $mode $collect_flags  -target-pid=$p
    fi
    
    echo
    echo completed run.
    # result_name=$(ls $result_dir/$SCHEME-$fusion_group-$OB_CORES | tail -1)

    # uset mkdir -p vtune_results/$SCHEME/$fusion_group/$OB_CORES/$ANALYSIS_TYPE

    # echo collecting report from $specific_result_dir to vtune_results/$SCHEME/$fusion_group/$OB_CORES/$ANALYSIS_TYPE/$result_name.csv
    
    # vtune -report summary -r $specific_result_dir -format=csv -csv-delimiter=comma -report-output=vtune_results/$SCHEME/$fusion_group/$OB_CORES/$ANALYSIS_TYPE/$result_name.csv
  done # p
  
  # once all pods have been profiled, stop this deployment.
  uset kubectl delete all --all

done # cfg
