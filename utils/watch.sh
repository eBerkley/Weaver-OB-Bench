#!/bin/bash


while :
do
podname=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')
sleep 10
kubectl cp $podname:/stats cur
clear
cat cur/lat_stats_history.csv | grep -o "Name[^\n]*" 
cat cur/lat_stats_history.csv | grep -o "[^n]*Aggregated[^\n]*" | tail -30
rm -rf cur
done
