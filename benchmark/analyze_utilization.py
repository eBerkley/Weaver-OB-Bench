#!/bin/python3
from typing import NamedTuple
import os
import pandas as pd

outdir="benchmark/out"
colocationdir="release/base/colocation"

CSCHEMES=["1core", "2allbutmain", "2main", "2core", 
"4allbutmain-2main", "4allbutmain", "4core", "4main-2allbutmain", 
"4main", "6core", "9core", "9main-6allbutmain", "9allbutmain-6main"]
SCHEMES=['all-but-main']
# SCHEMES=['monolith']
# CSCHEMES=["12core", "1core",  "2core", "3core", "4core", "6core", "9core", "1replica-36", "18core"]
ALLOC=["36"]

PRINT_DATA_LABELS=False

class TestName(NamedTuple):
    scheme: str
    cscheme: str
    alloc: str

    def get_name(self):
        return f"{self.scheme}_{self.cscheme}_{self.alloc}"

class GroupData:
    def __init__(self, name: str, cores_per: int, replicas: int = 0,  total_util: float = 0.0, avg_util: float = 0.0, adj_avg_util: float = 0.0, agg_util_share: float = 0.0):

        self.name: str = name
        self.cores_per: int = cores_per
        self.replicas: int = replicas
        self.total_util: float = total_util
        self.avg_util: float = avg_util
        'How many cores were used per replica on average, measured in percent'
        self.adj_avg_util: float = adj_avg_util
        'avg_util, adjusted to have 100% be the max value.'
        self.agg_util_share: float = agg_util_share
        'What % of total cpu util was from instances of this group'

    def __str__(self):
        if PRINT_DATA_LABELS:
            return f"{self.name.ljust(15)}: {self.cores_per:2d} cores, {self.replicas:2d} replicas = {round(self.total_util, 2):6.1f}% total, {round(self.avg_util, 2):5.1f}% avg, {round(self.adj_avg_util, 2):4.1f}% adjusted avg. Share of aggregate utilization: {round(self.agg_util_share):3.2f}%"
        else:
            return f"{self.name.ljust(15)}: {self.cores_per:2d}, {self.replicas:2d} = {round(self.total_util, 2):6.1f}%, {round(self.avg_util, 2):5.1f}%, {round(self.adj_avg_util, 2):4.1f}%, {round(self.agg_util_share):3.2f}%"

    def __repr__(self):
        return self.__str__()


class UtilData:
    def __init__(self, name: TestName):
        self.name = name
        self.podstats, self.alloc_cfg = UtilData.get_filenames(name)
        self.group_dict: dict[str, GroupData] = {}
        self.aggregate_utilization = 0.0
        self._parse_cfg()
        self._parse_data()

    def _parse_cfg(self):
        with open(self.alloc_cfg, 'r') as f:
            for _l in f.readlines():
                l = _l.strip()
                if not l:
                    continue
                ls = l.split('=')
                if len(ls) != 2:
                    raise ValueError(f"core alloc line {l} in file {self.alloc_cfg} is invalid.")
                
                groupname = ls[0]
                cores_per = ls[1]
                self.group_dict[groupname] = GroupData(groupname, int(cores_per))
        
    def _parse_data(self):
        podstats_df = pd.read_csv(self.podstats)
        names = podstats_df['Podname'].astype(str).values
        replicas = podstats_df['Replicas'].astype(int).values
        total_cpu_util = [float(x[:-1]) / 10 for x in podstats_df['Total CPU Utilization'].astype(str).values]
        average_cpu_util = [float(x[:-1]) / 10 for x in podstats_df['Avg CPU Utilization'].astype(str).values]
        self.aggregate_utilization = total_cpu_util[-1]

        for i in range(1, len(names) - 1):
            self.group_dict[names[i]].replicas = replicas[i]
            self.group_dict[names[i]].total_util = total_cpu_util[i]
            self.group_dict[names[i]].avg_util = average_cpu_util[i]
            self.group_dict[names[i]].adj_avg_util = average_cpu_util[i] / self.group_dict[names[i]].cores_per
            self.group_dict[names[i]].agg_util_share = 100 * self.group_dict[names[i]].total_util / self.aggregate_utilization 
            

    @staticmethod
    def get_filenames(name: TestName):
        podstats = os.path.join(outdir, name.get_name(), 'stats', 'pod_stats.csv')
        alloc_cfg = os.path.join(colocationdir, name.scheme, f"{name.cscheme}.cfg")
        return podstats, alloc_cfg

if __name__ == '__main__':
    if PRINT_DATA_LABELS == False:
        print('groupname,   cores,  replicas, total util, avg util, adj average util, agg share')
    for scheme in SCHEMES:
        for cscheme in CSCHEMES:
            for alloc in ALLOC:
                testname = TestName(scheme, cscheme, alloc)
                data = UtilData(testname)
                
                print(testname.get_name(), f", agg util: {data.aggregate_utilization}%")
                for _, x in data.group_dict.items():
                    print(x)
                print()
                
                
    # data = UtilData(TestName('monolith', '1core', '36'))
    # print(data.group_dict)