#!/bin/bash


get_save_dump () {
  kubectl wait --for=delete po/mongo-init-client

  kubectl run mongo-init-client \
    --restart='Never' \
    --image docker.io/eberkley/ob-mongo-init:$INIT_VERSION \
    --image-pull-policy='IfNotPresent' \
    --command './save.sh'
  
  kubectl wait --for=condition=Ready=true pod/mongo-init-client

  echo waiting for dump to complete.  
  while ! kubectl exec -it mongo-init-client -- cat '/build/init/sendDoorbell.txt' &>/dev/null; do
    sleep 1
  done

  echo dump completed. receiving...
  kubectl cp mongo-init-client:/build/init/dump dump

  echo got dump. preparing to terminate...
  kubectl exec -it mongo-init-client -- touch '/build/init/recvDoorbell.txt'

  kubectl wait --for=condition=Ready=false pod/mongo-init-client --timeout=30m
  echo terminating...
  kubectl delete po mongo-init-client
  
}

# if we have a copy of the dump already
#		Run the script that writes the copy to mongos
# else
#		Run the script that writes all of the client's json files to mongos
# 

# get_save_dump
# exit 0

if [[ -d dump/product-db ]]; then 
  echo starting mongo init client...
  kubectl run mongo-init-client \
    --restart='Never' \
    --image docker.io/eberkley/ob-mongo-init:$INIT_VERSION \
    --image-pull-policy='IfNotPresent' \
    --command ./restore.sh 

  kubectl wait --for=condition=Ready=true pod/mongo-init-client
  sleep 5

  echo sending mongo db dump...
  kubectl cp dump mongo-init-client:/build/init/dump
  echo done.
  kubectl exec -it mongo-init-client -- touch '/build/init/doorbell.txt'
  echo waiting for client to complete...
  

  # while ! kubectl exec -it mongo-init-client -- cat '/build/init/terminate.txt'; do
  #   sleep 1
  # done

  kubectl wait --for=condition=Ready=false pod/mongo-init-client --timeout=30m

  # echo terminating...
  kubectl delete po mongo-init-client
  
  # status=$?
  # if [[ $status != 0 ]]; then
  #   echo error! mongo-init-client failed to terminate after 30 minutes of waiting. 
  #   exit $status
  # fi
  echo Done!
  
else
  echo Preparing to manually set up mongodb shards.
  echo This will take a while.
  sleep 10
  echo working...
  
  # Get the files
  kubectl run mongo-init-client \
    --rm -it --image docker.io/eberkley/ob-mongo-init:$INIT_VERSION \
    --image-pull-policy='IfNotPresent'
  
  echo mongo db shards populated!
  echo "saving the db dump so we don't have to do this again..."
  # Pod deletes when done.
  # Run the script that collects dump file from mongo
  
  get_save_dump

fi
