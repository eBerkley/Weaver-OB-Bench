#!/bin/bash

cd $(dirname $0)/..


python3 benchmark/arch_graphs.py benchmark/perf_x86.csv
python3 benchmark/arch_graphs.py benchmark/perf_x86.csv mr
python3 benchmark/arch_graphs.py benchmark/perf_x86.csv mpki
python3 benchmark/arch_graphs.py benchmark/perf_x86.csv norm-mpki

python3 benchmark/arch_graphs.py benchmark/perf_arm.csv mr
python3 benchmark/arch_graphs.py benchmark/perf_arm.csv mpki
python3 benchmark/arch_graphs.py benchmark/perf_arm.csv norm-mpki