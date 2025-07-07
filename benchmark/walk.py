#!/bin/python3

import util
import subprocess
from typing import List, Callable, Dict

import os

THISDIR = os.path.dirname(__file__)
resdir = os.path.normpath(os.path.join(THISDIR, "results"))
NXT_GRPS = os.path.normpath(os.path.join(THISDIR, "..", "utils", "next_grps.sh"))

class Group:
    def __init__(self, scheme:str):
        
        def it(s: str):
            for i in range(1, len(s)):
                if s[i].isupper():
                    return [s[0:i]] + it(s[i:])
            return [s]

        self.scheme = util.shorten_scheme(scheme)
        self.comps = it(self.scheme)

    def canon_name(self):
        if self.comps == ["Ch"]:
            return "M"
        return self.scheme
    
    def __str__(self): return self.scheme
    def __repr__(self): return str(self)
    
    def difference(self, other: 'Group') -> str:
        "returns first difference found between two groups."    
        for a in self.comps:
            if a not in other.comps:
                return a
        for a in other.comps:
            if a not in self.comps:
                return a

mode, scheme, throughput_mode, _, user_count, value, breadth, prune = util.get_args()
scheme = Group(scheme)

if throughput_mode: 
    SLA = user_count or 100
else: 
    user_count = user_count or 25_000

value = value or 'p99'

extract_metric: Callable[[util.Val], float] = None
match value:
    case "p50":
        extract_metric = lambda x: x.p50
    case "p99":
        extract_metric = lambda x: x.p99
    case "cpu":
        extract_metric = lambda x: x.cpu

_idx = -1
def get_idx(dl: util.DataList):
    if throughput_mode:
        for i in range(len(dl)):
            if extract_metric(dl[i]) >= SLA:
                return max(i - 1, 0)
        return len(dl)

    else:
        global _idx
        if _idx != -1:
            return _idx

        if dl.ds[-1].get_users() < user_count:
            return 99

        for j in range(len(dl)):
            if dl.ds[j].get_users() == user_count:
                _idx = j
                return j
        
        return len(dl)

# makes it so that if a benchmark didn't actually reach the user
# count we are trying to optimize, the fake value we give
# is larger than any legitimate value, but smaller than 
# fake values from benchmarks that saturated earlier. 
# This can help reduce benchmarks by favoring schemes 
# that saturate later.
def weight_mst(f: float, l: int):
    if f == util.SATURATED:
        return f - l
    return f

def srt(dl: util.DataList) -> float:
    if throughput_mode:
        return dl.ds[int(get_idx(dl))].get_users()
    return weight_mst(extract_metric(dl[get_idx(dl)]), len(dl))

_next_cache: Dict[str, List[Group]] = {}
def get_next(s: Group) -> List[Group]:
    if str(s) in _next_cache:
        return _next_cache[str(s)]

    nxt = [
        Group(x)
        for x in 
            subprocess.Popen(
                [NXT_GRPS, str(s), '--full'], stdout=subprocess.PIPE
            ).communicate()[0].decode().split("\n")
        if x != ""
    ]
    _next_cache[str(s)] = nxt
    return nxt

# In latency minimizing mode, gets the largest throughput that has latency / util < SLA.
# Else, gets the latency / util at the throughput specified.
_cache: Dict[str, util.DataList] = {}
_benchmarks = 0
def get_val(s: Group) -> float:
    if str(s) in _cache:
        return srt(_cache[str(s)])

    global _benchmarks
    _benchmarks += 1
    
    dl = util.DataList()
    dl.from_results(util.find_best_match(s.canon_name(), resdir))
    _cache[str(s)] = dl
    return srt(dl)

def walk_latency(init: Group, bad_list: List[str]) -> Group:

    children = get_next(init)
    next_batch: List[int] = []
    for i in range(len(children)):
        new_c = init.difference(children[i])

        if new_c in bad_list:
            continue

        if get_val(children[i]) > get_val(init):
            bad_list.append(new_c)
        else:
            next_batch.append(i)
    
    if len(next_batch) == 0:
        return init

    next_batch.sort(key=lambda i: get_val(children[i]))    
    best = children[next_batch[0]]
    for i in range(min(len(next_batch), breadth)):
        n = next_batch[i]
        if prune:
            b = walk_latency(children[n], bad_list.copy())
        else:
            b = walk_latency(children[n], [])
        if get_val(b) < get_val(best):
            best = b
    return best

def walk_throughput(init: Group, bad_list: List[str]) -> Group:

    children = get_next(init)
    next_batch: List[int] = []
    for i in range(len(children)):
        new_c = init.difference(children[i])

        if new_c in bad_list:
            continue
        
        if get_val(children[i]) < get_val(init):
            bad_list.append(new_c)
        elif get_val(children[i]) == get_val(init):
            
            chdl=_cache[str(children[i])]
            initdl=_cache[str(init)]
            chmet = extract_metric(chdl[get_idx(chdl)])
            initmet = extract_metric(initdl[get_idx(initdl)])
            if chmet > initmet:
                bad_list.append(new_c)
        else:
            next_batch.append(i)
    
    if len(next_batch) == 0:
        return init

    next_batch.sort(key=lambda i: get_val(children[i]))    
    best = children[next_batch[0]]
    for i in range(min(len(next_batch), breadth)):
        n = next_batch[i]
        if prune:
            b = walk_throughput(children[n], bad_list.copy())
        else:
            b = walk_throughput(children[n], [])
        if get_val(b) > get_val(best):
            best = b
        elif get_val(b) == get_val(best):
            
            bdl=_cache[str(b)]
            bestdl=_cache[str(best)]
            bmet = extract_metric(bdl[get_idx(bdl)])
            bestmet = extract_metric(bestdl[get_idx(bestdl)])

            # print(f"(@{get_val(best)}) b: {b} = {bmet}, best: {best} = {bestmet}")
            if bmet < bestmet:
                best = b
    return best


if __name__ == '__main__':
    if throughput_mode:
        winner = walk_throughput(scheme, [])
        v = get_val(winner)
        dl=_cache[str(winner)]
        metric = extract_metric(dl[get_idx(dl)])
        print(f'Winner: {str(winner)} = {v}, {value} = {metric}')

    else:
        winner = walk_latency(scheme, [])
        v = get_val(winner)
        if mode == util.Mode.TERM.value:
            if v > 9_000:
                print(f'"Winner": {str(winner)}, MST = {_cache[str(winner)].ds[-2].users}"')
            
                
            else:
                print(f'Winner: {str(winner)} = {v}')
        
        elif mode == util.Mode.CSV.value: 
            print(f"{user_count},{prune},{breadth},{value},{_benchmarks},{get_val(winner)}")
        elif mode == util.Mode.AVG.value: 
            # not really doing any average, but we use this when
            # we want to compare walk results with an average.
            print(v, end="")
        
    import sys
    print("total benchmarks =", _benchmarks, file=sys.stderr)
    
