date=$(date +"%Y-%m-%d-%H-%M-%S")
for i in 2000 2100 2200 2300 2400 2500 2600 2700 2800 2900 3000 3100 3200 3300 3400 3500 3600 3700 3800 3900 4000 4100 4200 4300 4400 4500 4600 4700 4800 4900 5000 5100 5200 5300 5400 5500 5600 5700 5800 5900 6000 6100 6200 6300 6400 6500 6600 6700 6800 6900 7000 7100 7200 7300 7400 7500 7600 7700 7800 7900 8000
do
	echo -n $i, >> stats.csv
	export USERS=$i
	locust --headless -H http://127.0.0.1:12345 --processes 20 --csv results/$date/$i
	rm -r /tmp/weaver*
	rm -r /tmp/serviceweaver/logs/multi/*
	tail -1 $i_stats.csv >> stats.csv

done