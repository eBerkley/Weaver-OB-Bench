#!/bin/python3

from typing import List, Final, TypeAlias, Tuple, Callable
from . import DataPoint, Env, get_hold_idxs
import pandas as pd
from matplotlib import pyplot as plt
import os
from statistics import median


MAX_CORES=36

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

_USERS = {
    5_000:   0, 10_000:  1, 15_000:  2, 
    20_000:  3, 25_000:  4, 30_000:  5, 
    31_000:  6, 32_000:  7, 33_000:  8, 
    34_000:  9, 35_000: 10, 36_000: 11, 
    37_000: 12, 38_000: 13, 39_000: 14, 
    40_000: 15, 41_000: 16, 42_000: 17, 
    43_000: 18, 44_000: 19, 45_000: 20, 
    46_000: 21, 47_000: 22, 48_000: 23
}

srt_t: TypeAlias = Callable[['DataList'], float]
        
def get_srts(idx: int) -> Tuple[srt_t, srt_t, srt_t]:
    p50: srt_t = lambda x: x[idx].p50
    p99: srt_t = lambda x: x[idx].p99
    cpu: srt_t = lambda x: x[idx].cpu
    return p50, p99, cpu

def user_idx(users: int) -> int:
    return _USERS[users]

def idx_user(idx: int) -> int:
    return list(_USERS.keys())[list(_USERS.values()).index(idx)]


class Val:
    def __init__(self, p50: float, p99: float, cpu: float):
        self.p50 = p50
        self.p99 = p99
        self.cpu = cpu

    def ___str__(self):
        return f"({self.p50},{self.p99},{self.cpu})"
    
    def __repr__(self):
        return f"Val({self.p50},{self.p99},{self.cpu})"
    
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

SATURATED = 9999.9
fake_val: Final[Val] = Val(SATURATED, SATURATED, SATURATED)

class DataList:
    def __init__(self):
        self.ds: List[DataPoint] = []
        self.name: str = ""

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
        self.name = env.name.name
        idxs = get_hold_idxs(env.users)
        for s, e in idxs:
            usr = env.users[s]
            d = DataPoint(usr, env.p50[s:e], env.p99[s:e], env.rps[s:e], env.cpu[s:e])
            self.ds.append(d)

    def from_results(self, fname: str):
        self.name = os.path.basename(fname).split(".")[0]
        csv = pd.read_csv(fname)
        
        for i in range(len(csv[ResultsHead.Users])):
            d = DataPoint(csv[ResultsHead.Users][i], [csv[ResultsHead.P50][i]]*10, [csv[ResultsHead.P99][i]]*10, [csv[ResultsHead.RPS][i]]*10, [csv[ResultsHead.CPU][i]]*10)
            self.ds.append(d)

    def from_cmp(self, dl1: 'DataList', dl2: 'DataList'):
        self.name = "cmp"
        for i in range(min(len(dl1), len(dl2))):
            srtp50, srtp99, srtcpu = get_srts(i)
            p50 = srtp50(dl1) - srtp50(dl2)
            p99 = srtp99(dl1) - srtp99(dl2)
            cpu = srtcpu(dl1) - srtcpu(dl2)
            d = DataPoint(idx_user(i), [p50], [p99], [idx_user(i)], [cpu])
            self.ds.append(d)
            
    
    # We say that our simulated "random scheme" 
    # saturates at this point. Then, when creating
    # an expected latency for different user counts,
    # we only include vals up to that point.
    # Note that since we say our simulated scheme
    # does not saturate until this point, data we 
    # pull from for each user count will NOT include 
    # schemes that are saturated at this count.
    def from_others(self, dls: List['DataList']):
        self.name = "average"
        
        for usrs in list(_USERS.keys()):
            idx = user_idx(usrs)
            srtp50, srtp99, srtcpu = get_srts(idx)

            p50 = median([srtp50(dl) for dl in dls])
            p99 = median([srtp99(dl) for dl in dls])
            cpu = median([srtcpu(dl) for dl in dls])
            
            d = DataPoint(usrs, [p50], [p99], [usrs], [cpu])
            self.ds.append(d)
            if p50 > 5_000 or p99 > 5_000 or cpu > 5_000:
                break

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
        s = f'{"users".rjust(5)}: {"p50".rjust(6)}, {"p99".rjust(7)}, {"cpu".rjust(5)}; {"dp50".rjust(7)}, {"dp99".rjust(7)}, {"dcpu".rjust(7)}\n'
        for i in range(min(len(self.ds), len(other.ds))):
            usrs = self.ds[i].get_users()
            p50 = self.ds[i].get_p50() - other.ds[i].get_p50()
            p99 = self.ds[i].get_p99() - other.ds[i].get_p99()
            cpu = self.ds[i].get_cpu() - other.ds[i].get_cpu()
            dp50 = 100 * (p50 / self.ds[i].get_p50())
            dp99 = 100 * (p99 / self.ds[i].get_p99())
            dcpu = 100 * (cpu / self.ds[i].get_cpu())
            
            s += f"{usrs:5d}: {p50:+6.2f}, {p99:+7.2f}, {cpu:+5.2f}; {dp50:+6.2f}%, {dp99:+6.2f}%, {dcpu:+6.2f}%\n"
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

def longest_idx(dls: List[DataList]) -> int:
    longest = 0
    for i in range(len(dls)):
        if len(dls[longest]) < len(dls[i]):
            longest = i
    return longest



markers=["o",       "^",            "d",            "X",        "*"]
colors=["tab:blue", "tab:orange",   "tab:green",    "tab:red",  "tab:purple", "tab:cyan"]
BLUE=0
ORANGE=1
GREEN=2
RED=3
PURPLE=4
CYAN=5
graphable: TypeAlias = Tuple[List[int], List[float], List[float], List[float]]

def plot_data(dls: List[DataList], name: str, outdir: str):
    if len(dls) > len(markers):
        raise ValueError(f"Max num schemes supported: {len(markers)}, entered: {len(dls)}")

    datas: List[graphable] = [(
            [dl.ds[i].get_users() for i in range(len(dl))],
            [dl.ds[i].get_p50() for i in range(len(dl))],
            [dl.ds[i].get_p99() for i in range(len(dl))],
            [dl.ds[i].get_cpu() for i in range(len(dl))]
        ) for dl in dls]
    
    def plot_once(metric: str, metric_i: int, units: str):
        plt.cla()
        for i in range(len(dls)):
            plt.plot(datas[i][0], datas[i][metric_i], 
                label=dls[i].name, linestyle='--', marker=markers[i], color=colors[i])
        plt.legend(loc="upper left")
        plt.ylabel(units)
        plt.xlabel('Requests per Second')
        plt.title(f"{name} - {metric}")
        plt.xlim(0, 45_000)
        if   metric=="p50": plt.ylim(0, 50)
        elif metric=="p99": plt.ylim(0, 150)
        else              : plt.ylim(0, MAX_CORES)

        plt.savefig(os.path.join(outdir, f"{name}-{metric}"))

    plot_once('p50', 1, 'Latency (ms)')
    plot_once('p99', 2, 'Latency (ms)')
    plot_once('cpu', 3, 'Total Utilization (cores)')

TRIVIAL_COLOR   = 0
M_COLOR         = 1
MCH_COLOR       = 2
CH_COLOR        = 3

def plot_all(fused: List[DataList], not_fused: DataList, name: str, outdir: str):
    datas: List[graphable] = [(
            [dl.ds[i].get_users() for i in range(len(dl))],
            [dl.ds[i].get_p50() for i in range(len(dl))],
            [dl.ds[i].get_p99() for i in range(len(dl))],
            [dl.ds[i].get_cpu() for i in range(len(dl))]
        ) for dl in fused]
    
    nf_data: graphable = (
        [not_fused.ds[i].get_users() for i in range(len(not_fused))],
        [not_fused.ds[i].get_p50() for i in range(len(not_fused))],
        [not_fused.ds[i].get_p99() for i in range(len(not_fused))],
        [not_fused.ds[i].get_cpu() for i in range(len(not_fused))],
    )
    
    def plot_once(metric: str, metric_i: int, units: str):
        plt.cla()
        for i in range(len(fused)):
            c_idx = 0
            if fused[i].name.startswith("M"):
                if fused[i].name.startswith("MCh"):
                    c_idx = MCH_COLOR
                else:
                    c_idx = M_COLOR
            else:
                c_idx = CH_COLOR

            plt.plot(datas[i][0], datas[i][metric_i], 
                linestyle='--', marker=None, color=colors[c_idx], alpha=0.1)

        plt.plot(nf_data[0], nf_data[metric_i],
            label="microservices", linestyle='--', marker=None, color=colors[TRIVIAL_COLOR])
        
        plt.plot([], linestyle='--', marker=None, color=colors[M_COLOR], label='fusion-M')
        plt.plot([], linestyle='--', marker=None, color=colors[MCH_COLOR], label='fusion-MCh')
        plt.plot([], linestyle='--', marker=None, color=colors[CH_COLOR], label='fusion-Ch')
        
        plt.legend(loc="upper left")
        plt.ylabel(units)
        plt.xlabel('Requests per Second')
        plt.title(f"{name} - {metric}")
        plt.xlim(0, 45_000)
        if   metric=="p50": plt.ylim(0, 50)
        elif metric=="p99": plt.ylim(0, 150)
        else              : plt.ylim(0, MAX_CORES)

        plt.savefig(os.path.join(outdir, f"{name}-{metric}"))

    plot_once('p50', 1, 'Latency (ms)')
    plot_once('p99', 2, 'Latency (ms)')
    plot_once('cpu', 3, 'Total Utilization (cores)')

def plot_types(base: List[DataList], simple: List[DataList], x4ch: List[DataList], name: str, outdir: str) -> None:
    get_data: Callable[[List[DataList]],List[graphable]] = lambda dls: [(
            [dl.ds[i].get_users() for i in range(len(dl))],
            [dl.ds[i].get_p50() for i in range(len(dl))],
            [dl.ds[i].get_p99() for i in range(len(dl))],
            [dl.ds[i].get_cpu() for i in range(len(dl))]
        ) for dl in dls]

    base_data = get_data(base)
    simple_data = get_data(simple)
    x4ch_data = get_data(x4ch)

    GRAPH_MCH = False
    
    def plot_once(metric: str, metric_i: int, units: str):
        BASE_M_COLOR=0
        BASE_MCH_COLOR=2
        SIMPLE_M_COLOR=3
        SIMPLE_MCH_COLOR=4
        X4CH_M_COLOR=1
        X4CH_MCH_COLOR=5

        ALPHA=0.3


        plt.cla()
        for i in range(len(base)):
            c_idx = BASE_M_COLOR
            if base[i].name.startswith("MCh"):
                if not GRAPH_MCH:
                    continue

                c_idx = BASE_MCH_COLOR
            plt.plot(base_data[i][0], base_data[i][metric_i], 
                linestyle='--', marker=None, color=colors[c_idx], alpha=ALPHA)
        
        for i in range(len(simple)):
            c_idx = SIMPLE_M_COLOR
            if simple[i].name.startswith("MCh"):
                if not GRAPH_MCH:
                    continue
                c_idx = SIMPLE_MCH_COLOR
            plt.plot(simple_data[i][0], simple_data[i][metric_i], 
                linestyle='--', marker=None, color=colors[c_idx], alpha=ALPHA)
        
        for i in range(len(x4ch)):
            c_idx = X4CH_M_COLOR
            if x4ch[i].name.startswith("MCh"):
                if not GRAPH_MCH:
                    continue
                c_idx = X4CH_MCH_COLOR
            plt.plot(x4ch_data[i][0], x4ch_data[i][metric_i], 
                linestyle='--', marker=None, color=colors[c_idx], alpha=ALPHA)
        
        plt.plot([], linestyle='--', marker=None, color=colors[BASE_M_COLOR], label='base-M')
        if GRAPH_MCH:
            plt.plot([], linestyle='--', marker=None, color=colors[BASE_MCH_COLOR], label='base-MCh')
        
        if simple != []:
            plt.plot([], linestyle='--', marker=None, color=colors[SIMPLE_M_COLOR], label='simple-M')
            if GRAPH_MCH:
                plt.plot([], linestyle='--', marker=None, color=colors[SIMPLE_MCH_COLOR], label='simple-MCh')
        
        if x4ch != []:
            plt.plot([], linestyle='--', marker=None, color=colors[X4CH_M_COLOR], label='x4ch-M')
            if GRAPH_MCH:
                plt.plot([], linestyle='--', marker=None, color=colors[X4CH_MCH_COLOR], label='x4ch-MCh')

        plt.legend(loc="upper left")
        plt.ylabel(units)
        plt.xlabel('Requests per Second')
        plt.title(f"{name} - {metric}")
        plt.xlim(0, 45_000)
        if   metric=="p50": plt.ylim(0, 50)
        elif metric=="p99": plt.ylim(0, 150)
        else              : plt.ylim(0, MAX_CORES)

        plt.savefig(os.path.join(outdir, f"{name}-{metric}"))

    plot_once('p50', 1, 'Latency (ms)')
    plot_once('p99', 2, 'Latency (ms)')
    plot_once('cpu', 3, 'Total Utilization (cores)')