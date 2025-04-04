#!/bin/python3

import sys
import os
from typing import NamedTuple
from matplotlib import pyplot as plt
from datetime import datetime

# Format constants
_profdir = "vertical_profs"
FNAME_LEN = 20
P50_LEN = 7
P99_LEN = 8
MPS_LEN = 8
UTIL_LEN = 5
ADJ_LEN = 4
NORM_LEN = 9
THING_LEN = 8
COLORS = ["red", "orange", "turquoise", "springgreen", "yellow", "magenta",
          "lightcoral", "olive", "steelblue", "violet", "sienna", "deepskyblue", "crimson"]

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

# Argument: scheme only
if len(sys.argv) < 2:
    print("Usage: script.py <scheme>")
    sys.exit(1)

scheme = sys.argv[1].lower()
csv_dir = "metrics_collection"
matching_files = [f for f in os.listdir(csv_dir) if f.endswith(f"_{scheme}.csv")]
if not matching_files:
    print(f"No files found matching scheme '{scheme}' in {csv_dir}")
    sys.exit(2)

os.makedirs("benchmark/imgs", exist_ok=True)

# Table header
print(f"{'fname':{FNAME_LEN}} \t{'p50':{P50_LEN}} \t{'p99':{P99_LEN}} \t{'MPS':{MPS_LEN}} \t{'util':{UTIL_LEN}} \t{'adj':{ADJ_LEN}} \t{'normalized mps':{NORM_LEN}} \t{'mps/core':{THING_LEN}}")

# Data storage
all_data = {}
main_p99_by_ts = {}

for idx, filename in enumerate(sorted(matching_files)):
    name = filename.split("_")[0].lower()
    csv_file = os.path.join(csv_dir, filename)
    profdir = os.path.join(_profdir, name)
    os.makedirs(profdir, exist_ok=True)

    data_points = []
    with open(csv_file, "r") as f:
        for line in f:
            data, valid = makeVProfData(line)
            if valid:
                data_points.append(data)

    # Backup
    backup_file = os.path.join(profdir, f"{name}_{scheme}.csv")
    with open(backup_file, "w") as out:
        out.write("timestamp,p50,p99,mps,replicas,util\n")
        for d in data_points:
            out.write(f"{d.timestamp},{d.p50:.3f},{d.p99:.3f},{d.mps:.3f},{d.replicas},{d.util*10:.0f}m\n")

    # Print one-line summary
    if data_points:
        last = data_points[-1]
        fname = f"{name}_{scheme}"
        print(f"{fname:{FNAME_LEN}} \t{last.p50:0{P50_LEN}.2f} \t{last.p99:0{P99_LEN}.2f} \t{last.mps:0{MPS_LEN}.2f} \t{last.util:0{UTIL_LEN}.1f}% \t{last.util:0{UTIL_LEN}.1f}% \t{last.mps:0{NORM_LEN}.2f} \t{last.mps/last.util:0{THING_LEN}.2f}")

    if name == "main":
        main_p99_by_ts = {d.timestamp: d.p99 for d in data_points}
    else:
        all_data[name] = data_points

#P99 vs MPS (all components)
plt.figure()
for i, (comp, data) in enumerate(all_data.items()):
    X = [d.mps for d in data]
    Y_P99 = [d.p99 for d in data]
    plt.scatter(X, Y_P99, s=10, label=comp, color=COLORS[i % len(COLORS)])
plt.xlabel("MPS")
plt.ylabel("p99 latency (us)")
plt.title(f"{scheme}: p99 latency vs mps")
plt.grid(True)
plt.legend()
plt.savefig(os.path.join("benchmark", "imgs", f"{scheme}_p99_vs_mps.png"))

#Util vs MPS
plt.figure()
for i, (comp, data) in enumerate(all_data.items()):
    X = [d.mps for d in data]
    Y_UTIL = [d.util for d in data]
    plt.plot(X, Y_UTIL, marker='o', label=comp, color=COLORS[i % len(COLORS)])
plt.xlabel("MPS")
plt.ylabel("Util (%)")
plt.title(f"{scheme}:utilization vs mps")
plt.grid(True)
plt.legend()
plt.savefig(os.path.join("benchmark", "imgs", f"{scheme}_util_vs_mps.png"))

# Component vs Main P99 Ratio
if main_p99_by_ts:
    plt.figure()
    for i, (comp, data) in enumerate(all_data.items()):
        ratio_ts = []
        ratio_vals = []
        for d in data:
            if d.timestamp in main_p99_by_ts and main_p99_by_ts[d.timestamp] > 0:
                t_simple = datetime.fromisoformat(d.timestamp).strftime("%H:%M")
                ratio = d.p99 / main_p99_by_ts[d.timestamp]
                ratio_ts.append(t_simple)
                ratio_vals.append(ratio)
        if ratio_vals:
            plt.plot(ratio_ts, ratio_vals, marker='o', linestyle='-', color=COLORS[i % len(COLORS)], label=comp)
    plt.xlabel("Time")
    plt.ylabel("p99 ratio (component / main)")
    plt.title(f"{scheme}: p99 ratio vs main over time")
    plt.grid(True)
    plt.xticks(rotation=45)
    plt.legend()
    plt.tight_layout()
    plt.savefig(os.path.join("benchmark", "imgs", f"{scheme}_p99ratio_vs_main.png"))

