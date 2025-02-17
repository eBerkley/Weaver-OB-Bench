#!/bin/python3

import pandas as pd
import numpy as np
import os
from typing import NamedTuple
from enum import Enum
import matplotlib.pyplot as plt

DIRNAME = os.path.dirname(__file__)
STATSDIR = os.path.join(DIRNAME, "out")
SCHEMES = os.listdir(STATSDIR)
SCHEMES.sort()

print("scheme".ljust(20), "qps".ljust(10), "p50".ljust(5), "p99".ljust(5))

class Scheme(Enum):
    DISTRIBUTED = 1
    MIXED = 2
    HOLISTIC = 3


class BenchEnv(NamedTuple):
    scheme:     Scheme
    cores:      int
    ob_pods:    int

    name:       str

    @classmethod
    def create(cls, name: str):
        scheme = Scheme.DISTRIBUTED

        attributes = name.split("_")
        assert len(attributes) == 3
        if attributes[0] in ["microservices", "distributed"]:
            scheme = Scheme.DISTRIBUTED
        elif attributes[0] == "mixed":
            scheme = Scheme.MIXED
        elif attributes[0] in ['monolith', 'holistic']:
            scheme = Scheme.HOLISTIC
        
        cores = int(attributes[1])
        ob_pods = int(attributes[2])
        

        return cls(scheme, cores, ob_pods, name)

    
class BenchInfo(NamedTuple):
    env:            BenchEnv
    max_qps:        float
    qps_arr:        list[float]
    p50_arr:        list[float]
    p99_arr:        list[float]
    p50_99_ratios:  dict[float, float]

    

benchInfos: list[BenchInfo] = []

for scheme in SCHEMES:
    
    env = BenchEnv.create(scheme)

    scheme_dir = os.path.join(STATSDIR, scheme)
    scheme_stats = os.path.join(scheme_dir, "stats")
    agg_stats = os.path.join(scheme_stats, "aggregated.csv")

    df_agg = pd.read_csv(agg_stats).dropna()
    
    qps_arr = df_agg['Requests/s'].astype(float).values
    p50_arr = df_agg['50%'].astype(float).values
    p99_arr = df_agg['99%'].astype(float).values

    p50_99_ratios:dict[float,float] = {}
    for i in range(len(p50_arr)):
        if p50_arr[i] :# and not (i % 5):
            p50_99_ratios[qps_arr[i]] = \
                p99_arr[i] / p50_arr[i]

    real_vals = df_agg.where(df_agg['99%'] < 100, other=0.0)

    real_qps = real_vals['Requests/s'].astype(float).values
    
    max_qps = real_qps.max()

    benchInfo = BenchInfo(env, max_qps, qps_arr, p50_arr, p99_arr, p50_99_ratios)
    
    print(scheme.ljust(20), str(max_qps).ljust(10))
    # print([f"{k}= {v}".ljust(13) for k, v in med_tail_ratios.items()])

    benchInfos.append(benchInfo)

colors=['r', 'g', 'b', 'y', 'c', 'm', 'y', 'k']
def p99_p50_ratio():
    for i in range(len(benchInfos)):
        benchInfo = benchInfos[i]
        items = benchInfo.p50_99_ratios.items()
        X = np.array([x for x, _ in items])
        Y = np.array([y for _, y in items])
        plt.scatter(X, Y, label=benchInfo.env.name, s=3, c=colors[i % len(colors)])
        
        # theta = np.polyfit(X, Y, 4)
        # y_line = theta[4] + theta[3]*X + theta[2]*X**2 + theta[1]*X**3 + theta[0] * X**4
        # # plt.plot(X, y_line, label=benchInfo.env.name)
        # plt.plot(X, y_line, c=colors[i % len(colors)])

    plt.ylim(0, 30)
    plt.legend()
    plt.ylabel('p99 / p50 latency')
    plt.xlabel('queries per second')
    plt.savefig(os.path.join(DIRNAME, "img1"))
    plt.clf()

def p99_and_p50():
    for i in range(len(benchInfos)):
        benchInfo = benchInfos[i]

        X = benchInfo.qps_arr

        Y1 = benchInfo.p50_arr
        Y2 = benchInfo.p99_arr

        plt.scatter(X, Y1, label=benchInfo.env.name, s=5, marker='.', c=colors[i % len(colors)])
        plt.scatter(X, Y2, s=5, marker='^', c=colors[i % len(colors)])
        
    plt.ylim(0, 200)
    plt.legend()
    plt.ylabel('latency')
    plt.xlabel('queries per second')
    plt.savefig(os.path.join(DIRNAME, "img2"))

    plt.clf()

from collections import defaultdict

def p99_compare():
    scheme_dict: defaultdict[Scheme, dict[int, float]] = defaultdict(dict[int, float])
    for i in range(len(benchInfos)):
        benchInfo = benchInfos[i]
        
        scheme_dict[benchInfo.env.scheme][benchInfo.env.ob_pods] = benchInfo.max_qps
    
    for scheme, d in scheme_dict.items():
        
        x = d.keys()
        y = d.values()
        
        plt.plot(x, y, label=scheme.name, marker='^')
    plt.legend()
    plt.savefig(os.path.join(DIRNAME, "img3"))
    plt.clf()
    
if __name__ == '__main__':
    p99_compare()
    p99_p50_ratio()

