#!/bin/python3

import sys
import os
from typing import NamedTuple


SLO_RATIO=25.0


if len(sys.argv) < 2:
    print("error: not enough arguments.")
    exit(1)

name=sys.argv[1].lower()

_profdir="vertical_profs"
profdir=os.path.join(_profdir, name)

if not os.path.exists(profdir):
    print(f"path does not exist: {profdir}")
    exit(2)

p50_svc_latency_file=os.path.join("metrics_collection", "p50_svc_latency.csv")

if not os.path.exists(p50_svc_latency_file):
    print(f"need to have p50 svc latency file at {p50_svc_latency_file}.")
    exit(2)

base_p50=-1.0
with open(p50_svc_latency_file, "r") as f:
    for line in f.readlines():
        if name in line.lower():
            base_p50=float(line.split(",")[1])
            break
if base_p50 == -1.0:
    print(f"could not find name {name} in {p50_svc_latency_file}.")
    exit(3)

def is_violating(p99: float) -> bool:
    return p99 / base_p50 >= SLO_RATIO

def mcore_to_util(s: str) -> float:
    no_m=s.split("m")[0]
    mcores=float(no_m)
    return mcores/10.0

class VProfData(NamedTuple):
    timestamp: str
    p50: float
    p99: float
    mps: float
    util: float


def makeVProfData(s: str) -> tuple[VProfData, bool]: 
    data=s.split(",")
    if data[0] == "timestamp":
        return None, False
    if float(data[3]) == 0.0:
        return None, False
    return VProfData(data[0], float(data[1]), float(data[2]), float(data[3]), mcore_to_util(data[4])), True


class VProfDataList:
    def __init__(self, height: int):
        self.height = height
        self.data: list[VProfData] = []

    # VIOLATING DATA POINTS ARE IGNORED
    def add_data(self, data_point: VProfData):
        if is_violating(data.p99):
            return

        self.data.append(data_point)

    
vprof_ls_ls: list[VProfDataList] = []

for fname in os.listdir(profdir):
    height=int(fname.split("_")[-1].split(".")[0])
    vprof_ls = VProfDataList(height)

    with open(os.path.join(profdir, fname), "r") as f:
        for line in f.readlines():
            
            data, valid = makeVProfData(line)
            if valid:
                vprof_ls.add_data(data)
    vprof_ls_ls.append(vprof_ls)
    
    # normalized_mps = prev.mps / height
    # adj_util = prev.util/height
FNAME_LEN=20
P50_LEN=7
P99_LEN=8
MPS_LEN=8
UTIL_LEN=5
ADJ_LEN=4
NORM_LEN=9
THING_LEN=8
print(f"{'fname':{FNAME_LEN}} \t{'p50':{P50_LEN}} \t{'p99':{P99_LEN}} \t{'MPS':{MPS_LEN}} \t{'util':{UTIL_LEN}} \t{'adj':{ADJ_LEN}} \t{'normalized mps':{NORM_LEN}} \t{'mps/core':{THING_LEN}}")

from matplotlib import pyplot as plt

plt_l = plt.subplot(111)
plt_r = plt_l.twinx()
COLORS          = ["red", "orange", "turquoise", "springgreen", "yellow", "magenta", "lightcoral", "olive", "steelblue", "violet", "sienna", "deepskyblue", "crimson"]

from statistics import mean

for vprof_ls in vprof_ls_ls:
    height = vprof_ls.height
    if len(vprof_ls.data) == 0:
        continue
    
    vprof = vprof_ls.data[-1]
    norm_mps = vprof.mps  / float(height)
    adj_util = vprof.util / float(height)
    fname=f'{name}_{vprof_ls.height}'

    print(f"{fname:{FNAME_LEN}} \t{vprof.p50:0{P50_LEN}.2f} \t{vprof.p99:0{P99_LEN}.2f} \t{vprof.mps:0{MPS_LEN}.2f} \t{vprof.util:0{UTIL_LEN}.1f}% \t{adj_util:0{UTIL_LEN}.1f}% \t{norm_mps:0{NORM_LEN}.2f} \t{norm_mps/adj_util:0{THING_LEN}.2f}")
    X = [p.mps / height for p in vprof_ls.data]


    Y_UTIL = [p.util / height for p in vprof_ls.data]

    SMOOTH_P99=True
    if SMOOTH_P99:
        I=4
        Y_P99 = [mean(p.p99 for p in vprof_ls.data[i-I:i+I]) for i in range(I, len(vprof_ls.data) - I)]
        plt_l.scatter(X[I:-I], Y_P99, s=5, marker='.', c=COLORS[height - 1])
    else:
        Y_P99 = [p.p99 for p in vprof_ls.data]
        plt_l.scatter(X, Y_P99, s=5, marker='.', c=COLORS[height - 1])
    
    plt_r.plot(X, Y_UTIL, '-', c=COLORS[height - 1],  label=str(height))



plt_l.set_ylabel('p99 latency (us)')
plt_r.set_ylabel('normalized utilization %')

plt_r.plot([],[], '-', c='black', label='utilization')
plt_r.scatter([],[], marker='.', c='black', label='p99')


plt_l.set_xlabel('normalized mps')
plt_r.legend(loc="lower right")

plt_l.set_title(f"{name} vert profiling results")

plt.savefig(os.path.join('benchmark', 'imgs', f'{name}_vprof.png'), )

