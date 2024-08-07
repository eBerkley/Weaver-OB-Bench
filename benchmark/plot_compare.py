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
OTHER_NAME="none"

DIRNAME = os.path.dirname(__file__)


STATSDIR = os.path.join(DIRNAME, "out")
# PNG_NAME=os.path.join(STATSDIR, TEST_NAME)


OUT_DIR=os.path.join(STATSDIR,TEST_NAME, "imgs")


CSV_NONE = os.path.join(STATSDIR, "none", "stats", "none.csv")
CSV_TEST = os.path.join(STATSDIR, TEST_NAME, "stats", f"{TEST_NAME}.csv")

df_none = pd.read_csv(CSV_NONE)

df_test = pd.read_csv(CSV_TEST)


# ===== DATA ARRAYS =====
#region

Attributes = namedtuple('Attributes', ['qps', 'avg', 'tail', 'cpus'])

def make_lists(df):
    users = df['Users'].astype(int).values
    qps = df['QPS'].astype(int).values
    avg = df['Median Latency'].astype(int).values
    tail = df['Median Tail Latency'].astype(int).values
    cpu = df['Median CPU Cores Utilized'].astype(int).values
    return users, Attributes(qps, avg, tail, cpu)
    

#endregion


base = make_lists(df_none)
test = make_lists(df_test)




x = np.arange(len(base[0]))
width = 0.35

def plot(testArr, baseArr, yLabel: str, name: str, out: str):
    fig, ax = plt.subplots(1, 1)
    multiplier = 0


    offset = width * multiplier
    rects = ax.bar(x + offset, testArr, width, label='Test', color='green')
    ax.bar_label(rects, padding=3)

    multiplier += 1

    offset = width * multiplier
    rects = ax.bar(x + offset, baseArr, width, label='Control', color='blue')
    ax.bar_label(rects, padding=3)


    ax.set_ylabel(yLabel)

    _MAX = max(max(testArr), max(baseArr))
    ax.set_ylim(0.0, _MAX + (_MAX / 8))

    ax.set_xlabel('Queries per Second')
    ax.set_xticks(x + width/2)
    lables = [f"{q/1000:.1f}k" for q in base[1].qps]
    ax.set_xticklabels(lables)
    ax.set_xlim(-0.5, len(base[0])+0)


    ax.legend(loc='upper left')
    ax.set_title(name)
    
    fig.savefig(out)


plot(test[1].avg, base[1].avg, 'Median Latency (ms)', f'{TEST_NAME}: Median Latency', os.path.join(OUT_DIR, 'med'))
plot(test[1].tail, base[1].tail, 'Median Tail Latency (ms)', f'{TEST_NAME}: Tail Latency', os.path.join(OUT_DIR, 'tail'))
plot(test[1].cpus, base[1].cpus, 'Median CPU Cores', f'{TEST_NAME}: Median CPU Utilization', os.path.join(OUT_DIR, 'cpu'))

