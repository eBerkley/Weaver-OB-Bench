#!/bin/bash 

#main loop
while :
do

	pods=$(kubectl get pods | grep "^ob")
	all_utils=$(kubectl top pods | grep "^ob" | grep -o "[0-9]\+m\s*[0-9]\+Mi" | grep -o "^\S*" | grep -o "[0-9]\+")

	util=$(kubectl top pods | grep "^ob" | grep -o "[0-9]\+m\s*[0-9]\+Mi" | grep -o "^\S*" | grep -o "[0-9]\+" | awk '{sum+=$1} END {print sum}')

	max=$(echo "$all_utils" | sort -nr | head -n 1)

	loadgen=$(kubectl get pod | grep 'loadgenerator-[a-z0-9]\+-[a-z0-9]\+ ' | awk '{print $1}')

	kubectl cp $loadgen:/stats cur_other > /dev/null 2>&1

	reqs=$(cat cur_other/lat_stats_history.csv | grep -o "Aggregated,[^,]*" | grep -o "[^,]*$" | tail -1)
	latencies=$(cat cur_other/lat_stats_history.csv | grep -o -E "(,[0-9]*){11}" | tail -1 )
	rm -rf cur_other


	all_replicas=$(kubectl get hpa | grep -o "[0-9]\+\s\+[0-9]\+\s\+[0-9]\+" | grep -o "[0-9]\+$")

	total_replicas=$(echo "$all_replicas" | awk '{sum+=$1} END {print sum}')


	echo $reqs, $util, $max, $total_replicas $latencies | tee -a $1 # no comma for last because it's in the line

	sleep 10
done
