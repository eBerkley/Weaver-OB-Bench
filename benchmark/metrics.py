#!/bin/python3

import pandas as pd
import numpy as np
import statistics
from typing import NamedTuple
from collections import defaultdict
import matplotlib.pyplot as plt
import os

VARIANCE_WINDOW = 30
LOW_LOAD_USERS  = 10000
VIOLATION_RATIO = 10.0

class TestName(NamedTuple):
    scheme: str
    cores: str
    alloc: str

    def get_name(self):
        return f"{self.scheme}_{self.cores}_{self.alloc}"

class Data(NamedTuple):
  
    p99: float
    p50: float
    qps: float

    def ratio(self) -> float:
        return self.p99 / self.p50

class BenchData:
    def __init__(self):
        self._agg_data = defaultdict(list[Data])
        self._mean_data: dict[int, Data] = {}
    
    def add(self, users: int, data: Data):
        self._agg_data[users].append(data)
    
    def prune(self):
        self._agg_data = {x:y for x, y in self._agg_data.items() if len(y) > 1}

    def build_mean_data(self):
        for i in self._agg_data.items():
            vals = i[1][- VARIANCE_WINDOW:]
            p99s = [x.p99 for x in vals]
            p50s = [x.p50 for x in vals]
            qps = [x.qps for x in vals]

            self._mean_data[i[0]] = Data(p99=np.mean(p99s), p50=np.mean(p50s), qps=np.mean(qps))

    def get_violation_p50_rat(self, low_load: int, qos_ratio: float)-> tuple[int, int, Data]:
        """For now, `low_load` is a user count.
        We use the largest user count that is <= `low_load`.

        returns a tuple containing the user count that best matched `low_load`, as well as the largest (user count, `Data`) pair where p99 latency / p50 latency at `low_load` <= qos_ratio.
        """

        best_low_load = -1
        for k, _ in self._mean_data.items():
            if k > low_load: 
                break
            best_low_load = k

        assert best_low_load != -1
        
        low_load_data = self._mean_data[best_low_load]
        low_load_p50 = low_load_data.p50
        best_high_load = -1

        for k, v in self._mean_data.items():
            if k <= best_low_load:
                continue
            if v.p99 / low_load_p50 > qos_ratio: 
                continue
            best_high_load = k
        
        # if best_high_load == -1:
        #     print(self._all_data)
        #     for k, v in self._mean_data.items():
        assert best_high_load != -1

        return (best_low_load, best_high_load, self._mean_data[best_high_load])

    def get_violation_max_p99(self, max_p99: float):
        """returns `(user_count, Data)` tuple corresponding to the highest p99 latency <= `max_p99`"""

        best_k = -1
        for k, v in self._mean_data.items():
            if v.p99 > max_p99 : 
                continue
            best_k = k

        return (best_k, self._mean_data[best_k])

def get_data(testname: TestName) -> BenchData:
    fname = os.path.join("benchmark", "out", testname.get_name(), 
        "stats", "aggregated.csv")
    
    df_agg = pd.read_csv(fname).dropna(subset="50%")

    user_arr = df_agg['User Count'].astype(int).values
    p50_arr = df_agg['50%'].astype(float).values
    p99_arr = df_agg['99%'].astype(float).values
    qps_arr = df_agg['Requests/s'].astype(float).values

    bd = BenchData()

    for i in range(len(user_arr)):
        bd.add(user_arr[i], Data(p99=p99_arr[i], p50=p50_arr[i], qps=qps_arr[i]))

    bd.prune()
    bd.build_mean_data()

    return bd

if __name__ == '__main__':
    SCHEMES=["all_but_main", "carts", "frontend", "microservices", "mixed", "monolith"]
    CORES=["01"]
    ALLOC=["36"]

    tests_arr: list[TestName] = []
    tests_dict: dict[TestName, BenchData] = {}
    violation_dict: dict[TestName, tuple[int, int, Data]] = {}
    for s in SCHEMES:
        for c in CORES:
            for a in ALLOC:
                tests_arr.append(TestName(s, c, a))
    
    
    for t in tests_arr:
        tests_dict[t] = get_data(t)

    def print_rat_stats(low_load_users, violation_ratio):
        
        print(f"low load users: {low_load_users}, violation ratio: {violation_ratio}")

        
        for t in tests_arr:
            # violation_dict[t] = tests_dict[t].get_violation_p50_rat(
            #     low_load_users, violation_ratio)
            low_users, high_users, data = tests_dict[t].get_violation_p50_rat(
                low_load_users, violation_ratio)

            s=""
            s += f"{t.get_name().ljust(20)}:"
            s += "\t\t"
            s += f"({high_users}, {round(data.qps, 3)})".ljust(25)
            s+= "\t"
            s += f" {round(data.p99, 3)}"
            s += "\t\t"
            s += f" {low_users - LOW_LOAD_USERS}"

            print(s)
        print()

    def print_fixed_stats(max_p99):
        print(f"max p99: {max_p99}")
        for t in tests_arr:
            high_users, data = tests_dict[t].get_violation_max_p99(max_p99)

            s=""
            s += f"{t.get_name().ljust(20)}:"
            s += "\t\t"
            s += f"({high_users}, {round(data.qps, 3)})".ljust(25)
            s+= "\t"
            s += f" {round(data.p99, 3)}"
            # s += "\t\t"
            # s += f" {violation_dict[t][0] - LOW_LOAD_USERS}"

            print(s)
        print()


    print(f"{'name'.ljust(20)}: SLO violation (users, qps),\t \tviolation p99, \t offset from low load\n")
    
    print_rat_stats(10_000, 10.0)
    print_rat_stats(10_000, 15.0)
    print_rat_stats(12_500, 10.0)
    print_rat_stats(12_500, 15.0)
    print('\n')

    print_fixed_stats(100.0)
    print_fixed_stats(125.0)
    print_fixed_stats(150.0)
    # print_stats(15_000, 10.0)
    # print_stats(15_000, 15.0)
    

    