#!/bin/python3

import os
import pandas as pd
from enum import Enum
from typing import List, Union, Final

BENCH_TYPE_LINE=25
ALLOC_TYPE="ALLOC"

class StatsHead:
    Timestamp: Final = "Timestamp"
    Users: Final     = 'User Count'
    RPS: Final       = 'Requests/s'
    P50: Final       = '50%'
    P99: Final       = '99%'

class CPUHead:
    Seconds: Final   ='Seconds'
    Cores: Final     ='CPU Cores'

class Scheme:
    def __init__(self, name: str):
        self.name = name
        self.group = name.split("_")[0]
    
    def __str__(self):
        return self.name
    
    def __repr__(self):
        return self.name
        

class Env:
    def __init__(self, name: str):
        self.name = Scheme(name)
        self.times: List[int]   = []
        self.users: List[int] = []
        self.rps: List[float] = []
        self.p50: List[float] = []
        self.p99: List[float] = []
        self.cpu: List[float] = []

# Assume that if test dir format is `<groupname>_<c1>_<c2>_<c3>_...`
# testname is just a groupname.
def find_best_match(groupname: str, outdir: str) -> str:
    # groupname=groupname.split('_')[0]
    # tests = os.listdir(outdir)
    # for t in tests:
    #     if t.split('_')[0] == groupname:
    return os.path.join(outdir, groupname +".csv")
            # return os.path.join(outdir, t)
    
    raise ValueError(f"scheme {groupname} has no results")


def init_env(testname: str, alloc_ok: bool) -> Env:
    
    # ==================================
    # Make sure testname is a valid test
    # ==================================
    THISDIR = os.path.dirname(__file__)
    outdir = os.path.normpath(
        os.path.join(THISDIR, "..", "out"))
    
    dirname = os.path.join(outdir, testname)
    if not os.path.exists(dirname):
        dirname = find_best_match(testname, outdir) # May raise ValueError if no such test can be found
    
    infoname = os.path.join(dirname, "info.txt")
    with open(infoname, "r") as info:
        lines = info.readlines()
        if len(lines) <= BENCH_TYPE_LINE:
           raise ValueError(f"scheme {testname} info.txt is malformed!") 
           
        if lines[BENCH_TYPE_LINE].strip().endswith(ALLOC_TYPE):
            if not alloc_ok:
                raise ValueError(f"scheme {testname} is not a full benchmark!")
            
    lat_csv = os.path.join(dirname, "stats", "aggregated.csv")
    cpu_csv = os.path.join(dirname, "stats", "cpu.csv")

    if not os.path.exists(lat_csv) or not os.path.exists(cpu_csv):
        raise ValueError(f"scheme {testname} has malformed stats dir")
    
    # ==========================
    # Get all data from the CSVs
    # ==========================
    lat = pd.read_csv(lat_csv).dropna(subset='50%')
    cpu = pd.read_csv(cpu_csv)

    # Time, as reported in aggregated.csv
    time_arr = lat[StatsHead.Timestamp].astype(int).values
    init_time = time_arr[0]
    # Normalized, t_0 = 0s
    time_arr = [t - init_time for t in time_arr]

    # Time, as reported in cpu.csv
    seconds_arr = cpu[CPUHead.Seconds].astype(int).values
    _cpu_arr = cpu[CPUHead.Cores].astype(float).values
    
    # Cpu util array that will be returned.
    cpu_arr = []

    # Extend cpu arr to have an entry 
    # for each second in aggregated.csv
    i_cpu = 0
    for i_stats in range(len(time_arr)):
        t_cpu = seconds_arr[i_cpu]
        t_stats = time_arr[i_stats]

        cpu_arr.append(_cpu_arr[i_cpu])

        if t_cpu <= t_stats and i_cpu < len(_cpu_arr) - 1:
            i_cpu += 1

    
    env = Env(testname)
    env.times = time_arr
    env.users = lat[StatsHead.Users].astype(int).to_list()
    env.p50 = lat[StatsHead.P50].astype(float).to_list()
    env.p99 = lat[StatsHead.P99].astype(float).to_list()
    env.rps = lat[StatsHead.RPS].astype(float).to_list()
    env.cpu = cpu_arr

    return env

    
