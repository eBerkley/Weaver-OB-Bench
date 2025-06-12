#!/bin/python3

from typing import List, Final, NamedTuple
from . import DataPoint, Env, get_hold_idxs
import pandas as pd
from matplotlib import pyplot as plt

class ResultsHead:
    Users: Final = 'users'
    RPS: Final   = 'rps'
    P50: Final   = 'p50'
    P99: Final   = 'p99'
    CPU: Final   = 'cpu'

class Cmp:
    LT = 2
    EQ = 1
    GT = 0

class Val:
    def __init__(self, p50: float, p99: float, cpu: float):
        self.p50 = p50
        self.p99 = p99
        self.cpu = cpu
    
    def low_p50(self, other: 'Val'):
        if self.p50 < other.p50:
            return Cmp.LT
        elif self.p50 == other.p50:
            return Cmp.EQ
        return Cmp.GT

    def low_p99(self, other: 'Val'):
        if self.p99 < other.p99:
            return Cmp.LT
        elif self.p99 == other.p99:
            return Cmp.EQ
        return Cmp.GT

    def low_cpu(self, other: 'Val'):
        if self.cpu < other.cpu:
            return Cmp.LT
        elif self.cpu == other.cpu:
            return Cmp.EQ
        return Cmp.GT

fake_val = Val(99999999.9, 999999999999.9, 999.9)


class DataList:
    def __init__(self):
        self.ds: List[DataPoint] = []

    def __len__(self):
        return len(self.ds) - 1

    def __getitem__(self, key: int):
        # -1 because we don't care to return the saturation point,
        # Especially since reported CPU util is misleading
        if len(self) <= key:
            return fake_val
        p = self.ds[key]

        return Val(p.get_p50(), p.get_p99(), p.get_cpu())
    
    def from_out(self, env: Env):
        idxs = get_hold_idxs(env.users)
        for s, e in idxs:
            usr = env.users[s]
            d = DataPoint(usr, env.p50[s:e], env.p99[s:e], env.rps[s:e], env.cpu[s:e])
            self.ds.append(d)

    def from_results(self, fname: str):
        csv = pd.read_csv(fname)
        # users = csv[ResultsHead.Users].astype(int).to_list()
        # p50 = csv[ResultsHead.P50].astype(float).to_list()
        # p99 = csv[ResultsHead.P99].astype(float).to_list()
        # rps = csv[ResultsHead.RPS].astype(float).to_list()
        # cpu = csv[ResultsHead.CPU].astype(float).to_list()
        
        for i in range(len(csv[ResultsHead.Users])):
            d = DataPoint(csv[ResultsHead.Users][i], [csv[ResultsHead.P50][i]]*10, [csv[ResultsHead.P99][i]]*10, [csv[ResultsHead.RPS][i]]*10, [csv[ResultsHead.CPU][i]]*10)
            self.ds.append(d)
    
    def term(self) -> str:
        s = f'{"users".rjust(5)}: {"rps".rjust(8)}, {"p50".rjust(6)}, {"p99".rjust(7)}, {"cpu".rjust(5)}\n'
        for d in self.ds:
            s += f"{d.get_users():5d}: {d.get_rps():8.2f}, {d.get_p50():6.2f}, {d.get_p99():7.2f}, {d.get_cpu():5.2f} \n"
        return s

    def csv(self) -> str:
        s = 'users,rps,p50,p99,cpu\n'
        for d in self.ds:
            s += f"{d.get_users()},{d.get_rps()},{d.get_p50()},{d.get_p99()},{d.get_cpu()}\n"
        return s[:-1]

    def compare(self, other: 'DataList') -> str:
        s = f'{"users".rjust(5)}: {"p50".rjust(6)}, {"p99".rjust(7)}, {"cpu".rjust(5)}\n'
        for i in range(min(len(self.ds), len(other.ds))):
            usrs = self.ds[i].get_users()
            p50 = self.ds[i].get_p50() - other.ds[i].get_p50()
            p99 = self.ds[i].get_p99() - other.ds[i].get_p99()
            cpu = self.ds[i].get_cpu() - other.ds[i].get_cpu()
            
            s += f"{usrs:5d}: {p50:+6.2f}, {p99:+7.2f}, {cpu:+5.2f} \n"
        return s

    def graph(self, name: str, dest: str):
        plt.cla()
        usrs = [self.ds[i].get_users() for i in range(len(self))]
        p50 = [self.ds[i].get_p50() for i in range(len(self))]
        p99 = [self.ds[i].get_p99() for i in range(len(self))]
        plt.plot(usrs, p50, label='p50', linestyle='--', marker='.')
        plt.plot(usrs, p99, label='p99', linestyle='--', marker='.')
        plt.legend()
        plt.ylabel('Latency (ms)')
        plt.xlabel('Requests per Second')
        plt.title(name)
        plt.xlim(0, 45_000)
        plt.ylim(0, 250)
        plt.savefig(dest)
