#!/bin/python3

import sys
import os
from typing import NamedTuple
from matplotlib import pyplot as plt
from datetime import datetime

_profdir = "vertical_profs"
FNAME_LEN = 20
P50_LEN = 7
P99_LEN = 8
MPS_LEN = 8
UTIL_LEN = 5
ADJ_LEN = 4
NORM_LEN = 9
THING_LEN = 8
COLORS = ["red", "orange", "turquoise", "springgreen", "yellow", "magenta", "lightcoral", "olive", "steelblue", "violet", "sienna", "deepskyblue", "crimson"]

def mcore_to_util(s: str) -> float:
    return float(s.rstrip("m")) / 10.0

class VProfData(NamedTuple):
    timestamp: str
    p50: float
    p99: float
    mps: float
    replicas: int
    util: float

def makeVProfData(line: str) -> tuple[VProfData, bool]:
    if line.startswith("timestamp"):
        return None, False
    parts = line.strip().split(",")
    return VProfData(
        timestamp=parts[0],
        p50=float(parts[1]),
        p99=float(parts[2]),
        mps=float(parts[3]),
        replicas=int(parts[4]),
        util=mcore_to_util(parts[5])
    ), True

class VProfDataList:
    def __init__(self, scheme: str):
        self.scheme = scheme
        self.data: list[VProfData] = []

    def add_data(self, data_point: VProfData):
        self.data.append(data_point)

if len(sys.argv) < 2:
    print("Usage: script.py <scheme>")
    sys.exit(1)

scheme = sys.argv[1].lower()
csv_dir = "metrics_collection"

# Find all matching <component>_<scheme>.csv
matching_files = [f for f in os.listdir(csv_dir) if f.endswith(f"_{scheme}.csv")]
if not matching_files:
    print(f"No files found matching scheme '{scheme}' in {csv_dir}")
    sys.exit(2)

os.makedirs("benchmark/imgs", exist_ok=True)

for filename in matching_files:
    name = filename.split("_")[0].lower()
    csv_file = os.path.join(csv_dir, filename)
    profdir = os.path.join(_profdir, name)
    os.makedirs(profdir, exist_ok=True)

    vprof_ls = VProfDataList(scheme)
    with open(csv_file, "r") as f:
        for line in f:
            data, valid = makeVProfData(line)
            if valid:
                vprof_ls.add_data(data)

    # Backup
    backup_file = os.path.join(profdir, f"{name}_{scheme}.csv")
    with open(backup_file, "w") as out:
        out.write("timestamp,p50,p99,mps,replicas,util\n")
        for d in vprof_ls.data:
            out.write(f"{d.timestamp},{d.p50:.3f},{d.p99:.3f},{d.mps:.3f},{d.replicas},{d.util*10:.0f}m\n")

    # Last summary
    last = vprof_ls.data[-1]
    norm_mps = last.mps / float(last.replicas)
    adj_util = last.util / float(last.replicas)
    fname = f"{name}_{scheme}"

    print(f"{'fname':{FNAME_LEN}} \t{'p50':{P50_LEN}} \t{'p99':{P99_LEN}} \t{'MPS':{MPS_LEN}} \t{'util':{UTIL_LEN}} \t{'adj':{ADJ_LEN}} \t{'normalized mps':{NORM_LEN}} \t{'mps/core':{THING_LEN}}")
    print(f"{fname:{FNAME_LEN}} \t{last.p50:0{P50_LEN}.2f} \t{last.p99:0{P99_LEN}.2f} \t{last.mps:0{MPS_LEN}.2f} \t{last.util:0{UTIL_LEN}.1f}% \t{adj_util:0{UTIL_LEN}.1f}% \t{norm_mps:0{NORM_LEN}.2f} \t{norm_mps/adj_util:0{THING_LEN}.2f}")

    # Plot 1: P99 vs MPS
    X = [d.mps for d in vprof_ls.data]
    Y_P99 = [d.p99 for d in vprof_ls.data]
    plt.figure()
    plt.scatter(X, Y_P99, s=10, marker='.', c=COLORS[0], label=f"{scheme}")
    plt.xlabel("mps")
    plt.ylabel("p99 latency (us)")
    plt.title(f"{name} - {scheme} p99 vs mps")
    plt.grid(True)
    plt.legend()
    plt.savefig(os.path.join("benchmark", "imgs", f"{name}_{scheme}_p99_vs_mps.png"))

    # Plot 2: Util vs MPS
    Y_UTIL = [d.util / d.replicas for d in vprof_ls.data]
    plt.figure()
    plt.plot(X, Y_UTIL, '-', c=COLORS[0], label=f"{scheme}")
    plt.xlabel("mps")
    plt.ylabel("normalized util %")
    plt.title(f"{name} - {scheme} util vs mps")
    plt.grid(True)
    plt.legend()
    plt.savefig(os.path.join("benchmark", "imgs", f"{name}_{scheme}_util_vs_mps.png"))

    # Plot 3: Component vs Main P99 ratio (if not main)
    if name != "main":
        main_file = os.path.join("metrics_collection", f"main_{scheme}.csv")
        if os.path.exists(main_file):
            main_p99_by_ts = {}
            with open(main_file, "r") as f:
                for line in f:
                    if line.startswith("timestamp"):
                        continue
                    parts = line.strip().split(",")
                    ts = parts[0]
                    p99 = float(parts[2])
                    main_p99_by_ts[ts] = p99

            ratio_ts = []
            ratio_vals = []
            for d in vprof_ls.data:
                if d.timestamp in main_p99_by_ts:
                    main_p99 = main_p99_by_ts[d.timestamp]
                    if main_p99 > 0:
                        ratio_ts.append(datetime.fromisoformat(d.timestamp).strftime("%H:%M"))
                        ratio_vals.append(d.p99 / main_p99)

            if ratio_vals:
                plt.figure()
                plt.plot(ratio_ts, ratio_vals, marker='o', linestyle='-', c='purple', label=f"{name}/main p99 ratio")
                plt.xlabel("Time")
                plt.ylabel("p99 ratio")
                plt.title(f"{name} - {scheme} p99 / main p99")
                plt.grid(True)
                plt.xticks(rotation=45)
                plt.legend()
                plt.tight_layout()
                plt.savefig(os.path.join("benchmark", "imgs", f"{name}_{scheme}_p99ratio_vs_main.png"))
