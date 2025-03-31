#!/bin/python3

import sys
import os
from typing import NamedTuple


BASE_SLO_RATIO=100.0
SVC_LATENCY_FILE=os.path.join("metrics_collection", "svc_latency.csv")

MSG_COUNTS_FILE=os.path.join("metrics_collection", "normalized_msg_counts.csv")

if len(sys.argv) < 2:
    print("error: not enough arguments.")
    exit(1)

name=sys.argv[1].lower()

_profdir="vertical_profs"
profdir=os.path.join(_profdir, name)

if not os.path.exists(profdir):
    print(f"path does not exist: {profdir}")
    exit(2)



def get_base_p50s(fname: str) -> tuple[float, float]:
    if not os.path.exists(fname):
        print(f"need to have p50 svc latency file at {fname}.")
        exit(2)
    comp_p50=-1.0
    main_p50=-1.0
    with open(fname, "r") as f:
        for line in f.readlines():
            if name in line.lower():
                comp_p50=float(line.split(",")[1])
            if "main" in line.lower():
                main_p50=float(line.split(",")[1])
    if comp_p50 == -1.0 or main_p50 == -1.0:

        print(f"could not find name {name} in {fname}.")
        exit(3)
    return comp_p50, main_p50
    

def get_msg_freq(fname: str):
    if not os.path.exists(fname):
        print(f"need to have p50 svc latency file at {fname}.")
        exit(2)
    
    if name.lower() == "main":
        return 1.0

    with open(fname, "r") as f:
        for line in f.readlines():
            if '*' in line.lower() and name in line.lower():
                return float(line.split(",")[2])
                
    print(f"could not find name {name} in {fname}.")
    exit(3)

BASE_P50, MAIN_P50=get_base_p50s(SVC_LATENCY_FILE)
BASE_SLO_RATIO=25.0
SLO_RATIO=BASE_SLO_RATIO*max(get_msg_freq(MSG_COUNTS_FILE), 1.0)
# SLO_RATIO = BASE_SLO_RATIO * BASE_P50 * get_msg_freq(MSG_COUNTS_FILE) / MAIN_P50

def is_violating(p99: float) -> bool:
    return p99 / BASE_P50 >= SLO_RATIO

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
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.data: list[VProfData] = []

    # VIOLATING DATA POINTS ARE IGNORED
    def add_data(self, data_point: VProfData):
        if is_violating(data.p99 / 10):
            return

        self.data.append(data_point)

    
vprof_ls_ls: list[VProfDataList] = []

for fname in os.listdir(profdir):
    width=int(fname.split("_")[-2])
    height=int(fname.split("_")[-1].split(".")[0])
    vprof_ls = VProfDataList(width, height)

    with open(os.path.join(profdir, fname), "r") as f:
        for line in f.readlines():
            
            data, valid = makeVProfData(line)
            if valid:
                vprof_ls.add_data(data)
    vprof_ls_ls.append(vprof_ls)
    
    # normalized_mps = prev.mps / height
    # adj_util prev.util/height
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
# plt_r = plt_l.twinx()
COLORS          = ["red", "orange", "turquoise", "springgreen", "yellow", "magenta", "lightcoral", "olive", "steelblue", "violet", "sienna", "deepskyblue", "crimson"]

from statistics import mean

plt_ls:list[tuple[int, list[float], list[float]]]=[]
"[height=1: (1, [mps],[util]), ...]"


for vprof_ls in sorted(vprof_ls_ls, key=lambda x: x.height):
    height = vprof_ls.height
    if len(vprof_ls.data) == 0:
        continue
    # if height > 2: continue
    
    vprof = vprof_ls.data[-1]
    norm_mps = vprof.mps  / float(height)
    adj_util = vprof.util / float(height)
    fname=f'{name}_{vprof_ls.height}'

    print(f"{fname:{FNAME_LEN}} \t{vprof.p50:0{P50_LEN}.2f} \t{vprof.p99:0{P99_LEN}.2f} \t{vprof.mps:0{MPS_LEN}.2f} \t{vprof.util:0{UTIL_LEN}.1f}% \t{adj_util:0{UTIL_LEN}.1f}% \t{norm_mps:0{NORM_LEN}.2f} \t{norm_mps/adj_util:0{THING_LEN}.2f}")

    X = [p.mps / float(height) for p in vprof_ls.data]
    
    Y_UTIL = [p.util / height for p in vprof_ls.data]
    
    SMOOTH_P99=True
    if SMOOTH_P99:
        I=4
        # idxls: list[int]=[]
        # prev_mps=0
        # FLAT=0

        # for i in range(len(vprof_ls.data)):
        #     if vprof_ls.data[i].mps < prev_mps:
        #         idxls.append(i)

            # prev_mps = vprof_ls.data[i].mps

        # Y_P99 = [vprof_ls.data[i].p99 for i in idxls]

        Y_P99 = [min(p.p99 for p in vprof_ls.data[i-I:i+I]) \
            for i in range(I, len(vprof_ls.data) - I)]

        plt_l.scatter(X[I:-I], Y_P99, s=10, marker='.', 
            c=COLORS[height-1], label=height)

        # plt_l.scatter([X[i] / height for i in idxls], 
            # Y_P99, s=5, marker='.', c=COLORS[height - 1], label=height)
    else:
        Y_P99 = [p.p99 for p in vprof_ls.data]
        plt_l.scatter(X, Y_P99, s=5, marker='.', c=COLORS[height - 1])
    plt_ls.append((height, X, Y_UTIL))
    # plt_r.plot(X, Y_UTIL, '-', c=COLORS[height - 1],  label=str(height))

plt_l.axhline(BASE_P50 * SLO_RATIO, ls='--', color='black')

plt_l.set_ylim(0, BASE_P50*SLO_RATIO*2)
plt_l.set_ylabel('p99 latency (us)')
# plt_r.set_ylabel('normalized utilization %')

# plt_r.plot([],[], '-', c='black', label='utilization')
# plt_r.scatter([],[], marker='.', c='black', label='p99')


plt_l.set_xlabel('normalized mps')
# plt_r.legend(loc="lower right")
plt_l.legend(loc="upper left")

plt_l.set_title(f"{name} vert profiling results")

plt.savefig(os.path.join('benchmark', 'imgs', f'{name}_vprofp99.png'), )


plt.cla()
for i in range(len(plt_ls)):
    height=plt_ls[i][0]
    X = plt_ls[i][1]
    Y_UTIL=plt_ls[i][2]
    plt.plot(X, Y_UTIL, '-', c=COLORS[height - 1],  label=str(height))



plt.xlabel("normalized mps")
plt.ylabel("normalized util%")
plt.legend()
plt.savefig(os.path.join('benchmark', 'imgs', f'{name}_vprofutil.png'))
