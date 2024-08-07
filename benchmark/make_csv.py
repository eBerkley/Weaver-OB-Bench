#!/bin/python3

import matplotlib.pyplot as plt

import pandas as pd
import numpy as np
import os
from typing import *
from statistics import median
from collections import namedtuple
from sys import argv

if len(argv) < 1:
    print("ERR!! arg 1 should be name of folder test data is in.")
    exit(1)

TEST_NAME=argv[1]

_CSV_FILE_NAME = "lat_stats_history.csv"

DIRNAME = os.path.dirname(__file__)


STATSDIR = os.path.join(DIRNAME, "out", TEST_NAME, "stats")

OUT_FILE=os.path.join(STATSDIR, TEST_NAME + ".csv")

CSV_FILE_NAME = os.path.join(STATSDIR, _CSV_FILE_NAME)

cpu = pd.read_csv(os.path.join(STATSDIR, "cpu.csv"))

_df = pd.read_csv(CSV_FILE_NAME, keep_default_na=False)
df = _df.where(_df['Name'] == 'Aggregated')
df = df.where(_df['50%'] != 'N/A')
df = df.dropna()

start_time = min(df['Timestamp']) / 60

def adjusted_minutes(f):
    return (f/60) - start_time

def minutes(f):
    return f/60

# ===== DATA ARRAYS =====
#region

L_MINS = df['Timestamp'].apply(adjusted_minutes).values
"X Axis for Median, Average, Users, RPS"

P50 = df['50%'].astype(float).values
P66 = df['66%'].astype(float).values
P75 = df['75%'].astype(float).values
P80 = df['80%'].astype(float).values
P90 = df['90%'].astype(float).values
P95 = df['95%'].astype(float).values
P98 = df['50%'].astype(float).values
P99 = df['99%'].astype(float).values

P99_9 = df['99.9%'].astype(float).values
P99_99 = df['99.99%'].astype(float).values
P100 = df['100%'].astype(float).values

RPS = df['Requests/s'].values
USERS = df['User Count'].values
CORES = cpu['CPU Cores'].values

#endregion


Interval = namedtuple('Interval', ['start', 'hold', 'end'])
Attributes = namedtuple('Attributes', ['qps', 'avg', 'tail', 'cpus'])


def _stats_dict():
    prev_user = USERS[0]
    ret: Dict[int, Interval] = {}
    repeating=False

    startIDX = 0
    holdIDX = 0
    for idx in range(1, len(USERS)):
        u = USERS[idx]
        if u == prev_user:
            if repeating == False:
                holdIDX = idx

            #     ret.append(L_MINS[idx])
            repeating = True
        elif repeating == True:
            # ret.append((idx, u, L_MINS[idx]))
            ret[int(prev_user)] = Interval(startIDX, holdIDX, idx)

            startIDX = idx
            # ret.append(L_MINS[idx])
            # ret.append(idx)
            repeating = False
        prev_user = u
    
    if repeating == True:
        ret[int(prev_user)] = Interval(startIDX, holdIDX, len(USERS) - 1)
    return ret

stats_dict = _stats_dict()

def get_data(_users: int) -> Attributes:
    _int = stats_dict[_users]
    hold = _int.hold
    end = _int.end

    
    _QPS: float  = median(RPS[hold:end])
    _AVG: float  = median(P50[hold:end])
    _TAIL: float = median(P99[hold:end])
    _CPUS: float = median(CORES[hold:end])
    print(f"{_users} \t\t{_QPS:.1f} \t\t{_AVG} \t\t\t{_TAIL} \t\t\t{_CPUS}")
    return Attributes(_QPS, _AVG, _TAIL, _CPUS)



print("\nUsers \t\tQPS \t  Median Latency \tMedian Tail Latency \tMedian CPU Cores Utilized\n")

attr_dict: Dict[int, Attributes] = {}

users = stats_dict.keys()

for a in users:
    attr_dict[a] = get_data(a)

with open(OUT_FILE, 'w') as f:
    f.write('Users,QPS,Median Latency,Median Tail Latency,Median CPU Cores Utilized\n')
    for u, attr in attr_dict.items():
        f.write(f"{u},{','.join([str(a) for a in attr])}\n")

