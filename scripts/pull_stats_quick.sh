#!/bin/bash
cd $(dirname $0)

podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')

# kubectl logs -f --tail 0 --limit-bytes=1 $podname > /dev/null
kubectl cp $podname:/stats ../benchmark/stats 
