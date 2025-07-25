#!/bin/python3

import util
from typing import List, Callable, Optional
import os
import sys

mode, scheme, alloc_ok, scheme2, user_count, value, _, _, group_mode = util.get_args()

THISDIR = os.path.dirname(__file__)
resdir = os.path.normpath(os.path.join(THISDIR, "results"))



if mode == util.Mode.AVG.value:
    schemes = [x for x in util.get_schemes(True) if not x.startswith("median")]
    
    print("groups: " + " ".join(schemes))
    if len(schemes) < 2:
        raise ValueError(f"Error: not enough input schemes: {schemes}")
    
    dls: List[util.DataList] = []
    for s in schemes:
        res = util.find_best_match(s, resdir, True)
        dl = util.DataList()
        dl.from_results(res)
        dls.append(dl)

    avg = util.DataList()
    avg.from_others(dls)

    print(avg.term())
    print(avg.csv(), file=sys.stderr)
    exit(0)

elif mode == util.Mode.RANK.value:
    schemes = util.get_schemes()
    print("groups: " + " ".join(schemes))

    if len(schemes) < 2:
        raise ValueError(f"Error: not enough input schemes: {schemes}")

    dls: List[util.DataList] = []
    for s in schemes:
        res = util.find_best_match(s, resdir)
        dl = util.DataList()
        dl.from_results(res)
        dls.append(dl)

    idx = util.user_idx(user_count)

    if not any(len(dl) >= idx for dl in dls):
        raise ValueError(f"Can not find any idx that has user count = {user_count}")

    srted = [i for i in range(len(dls))]

    srt: Callable[[util.DataList], float]
    match value:
        case "p50":
            srt = lambda x: x[idx].p50
        case "p99":
            srt = lambda x: x[idx].p99
        case "cpu":
            srt = lambda x: x[idx].cpu
    
    srted.sort(key=lambda i: srt(dls[i]))

    print(f"idx:\t{'name'.rjust(15)}, {value.rjust(7)}")
    for rank in range(len(srted)):
        i = srted[rank]
        print(f"{rank:3d}:\t{schemes[i].rjust(15)}, {srt(dls[i]):7.2f}")

elif mode == util.Mode.COMPARE_MANY.value:
    def cmp_mode(suffix: str):
        simples = util.get_suffix(resdir, suffix)

        p50 = [0.0 for _ in range(24)]
        p99 = [0.0 for _ in range(24)]
        cpu = [0.0 for _ in range(24)]
        reached = [0 for _ in range(24)]
        
        for s in simples:
            
            if "median" in s:
                continue
            if scheme == "MCh" and "MCh" not in s:
                continue
            if scheme == "M" and "MCh" in s:
                continue
            base = s.replace(f"-{suffix}", "")
            basedl = util.DataList()
            simpledl = util.DataList()

            basedl.from_results(base)
            simpledl.from_results(s)

            cmpdl = util.DataList()
            cmpdl.from_cmp(basedl, simpledl)
            for i in range(len(cmpdl)):
                p50[i] += cmpdl[i].p50
                p99[i] += cmpdl[i].p99
                cpu[i] += cmpdl[i].cpu
                reached[i]+=1
        
        s = f'{"users".rjust(5)}: {"p50".rjust(6)}, {"p99".rjust(7)}, {"cpu".rjust(5)} \tsamples\n'
        for i in range(24):
            if reached[i]:
                s += f"{util.idx_user(i):5d}: {p50[i]/reached[i]:+6.2f}, {p99[i]/reached[i]:+7.2f}, {cpu[i]/reached[i]:+5.2f} \t{reached[i]:7d}\n"
        print(f"baseline - {suffix}:")
        print(s)
        
    if group_mode == util.GroupMode.SIMPLE.value:
        cmp_mode("simple_checkout")
    elif group_mode == util.GroupMode.X4CH.value:
        cmp_mode("x4ch")


    elif group_mode == util.GroupMode.INPUT:
    
        schemes = util.get_schemes()
        if "best" in schemes:
            schemes.remove("best")
        if "optimal" in schemes:
            schemes.remove("optimal")
        
        if not value:
            print("groups: " + " ".join([f"{i}:{schemes[i]}" for i in range(len(schemes))]))
            print()
        
        if len(schemes) < 2:
            raise ValueError(f"Error: not enough input schemes: {schemes}")

        dls: List[util.DataList] = []
        for s in schemes:
            res = util.find_best_match(s, resdir)
            dl = util.DataList()
            dl.from_results(res)
            dls.append(dl)
        
        longest = util.longest_idx(dls)
        # arbitrary way of deciding to output in csv form
        OFFSET=max(max([len(s) for s in schemes]), 15)
        if value:
            print("users,rps,p50,p99,cpu")
        else:
            print(f'{"users".rjust(5)}:\t{"p50".rjust(OFFSET+7)},\t{"p99".rjust(OFFSET+9)},\t{"cpu".rjust(OFFSET+7)}')
        
        unique: set[str] = set()
        best: set[str] = set()
        for t in range(len(dls[longest])):
            min_p50 = [0]
            min_p99 = [0]
            min_cpu = [0]
            for i in range(len(dls)):
                cmp_p50 = dls[i][t].low_p50(dls[min_p50[0]][t])
                cmp_p99 = dls[i][t].low_p99(dls[min_p99[0]][t])
                cmp_cpu = dls[i][t].low_cpu(dls[min_cpu[0]][t])
                    
                if cmp_p50 == util.Cmp.LT:
                    min_p50=[i]
                elif cmp_p50 == util.Cmp.EQ:
                    if i != 0:
                        min_p50.append(i)
                
                if cmp_p99 == util.Cmp.LT:
                    min_p99=[i]
                elif cmp_p99 == util.Cmp.EQ:
                    if i != 0:
                        min_p99.append(i)
                
                if cmp_cpu == util.Cmp.LT:
                    min_cpu=[i]
                elif cmp_cpu == util.Cmp.EQ:
                    if i != 0:
                        min_cpu.append(i)
            
            usr_str = f"{dls[longest].ds[t].users:5d}"
            p50_scheme = schemes[min_p50[0]]
            p99_scheme = schemes[min_p99[0]]
            cpu_scheme = schemes[min_cpu[0]]

            if   len(min_p50) > 5: p50_scheme = f"({len(min_p50)}schemes)"
            elif len(min_p50) > 1:  
                p50_scheme = ",".join([str(x) for x in min_p50]) # = "..."
                for x in min_p50: best.add(schemes[x])
            else: 
                best.add(p50_scheme)
                unique.add(p50_scheme)
            
            if   len(min_p99) > 5: p99_scheme = f"({len(min_p99)}schemes)"
            elif len(min_p99) > 1:  
                p99_scheme = ",".join([str(x) for x in min_p99]) # = "..."
                for x in min_p99: best.add(schemes[x])            
            else: 
                best.add(p99_scheme)
                unique.add(p99_scheme)
            
            if   len(min_cpu) > 5: cpu_scheme = f"({len(min_cpu)}schemes)"
            elif len(min_cpu) > 1: 
                cpu_scheme = ",".join([str(x) for x in min_cpu]) # = "..."
                for x in min_cpu: best.add(schemes[x])

            else: 
                best.add(cpu_scheme)
                unique.add(cpu_scheme)

            p50_str = f"{p50_scheme.rjust(OFFSET)}: {dls[min_p50[0]][t].p50:6.2f}"
            p99_str = f"{p99_scheme.rjust(OFFSET)}: {dls[min_p99[0]][t].p99:7.2f}"
            cpu_str = f"{cpu_scheme.rjust(OFFSET)}: {dls[min_cpu[0]][t].cpu:5.2f}"
            
            if value:
                print(f"{dls[longest].ds[t].users},{dls[longest].ds[t].users},{dls[min_p50[0]][t].p50:.2f},{dls[min_p99[0]][t].p99:.2f},{dls[min_cpu[0]][t].cpu:.2f}")
            else:
                print(f"{usr_str}: {p50_str},\t{p99_str},\t{cpu_str}")
        
        print(f"best ({len(best)}): {best}", file=sys.stderr)
        print(f"unique ({len(unique)}): {unique}", file=sys.stderr)
        exit(0)

elif mode == util.Mode.COMPARE.value:
    if scheme2 == "":
        raise ValueError("Need to define --name2 for --mode=cmp")
    
    res1 = util.find_best_match(scheme, resdir, True)
    res2 = util.find_best_match(scheme2, resdir, True)

    dl1 = util.DataList()
    dl2 = util.DataList()

    dl1.from_results(res1)
    dl2.from_results(res2)

    print(f"{scheme} - {scheme2}")
    print(dl1.compare(dl2))
    exit(0)

elif mode == util.Mode.GRAPH_MANY.value:
    if group_mode == util.GroupMode.INPUT.value:
        util.graph_input(scheme, resdir, THISDIR)
        # schemes = util.get_schemes(True)
        # if len(schemes) < 2:
        #     raise ValueError(f"Need to use schemes multiple times. schemes: {schemes}")
    
    elif group_mode == util.GroupMode.ARM.value:
        util.graph_arm(scheme, resdir, THISDIR)
        exit(0)

    elif group_mode == util.GroupMode.SIMPLE.value:
        util.graph_simple(scheme, resdir, THISDIR)

    elif group_mode == util.GroupMode.X4CH.value:
        util.graph_x4ch(scheme, resdir, THISDIR)
    elif scheme == "":
        util.graph_suffix("Aggregate", resdir, THISDIR, "")
    else:
        util.graph_suffix(scheme, resdir, THISDIR, scheme)
    exit(0)

elif mode == util.Mode.GRAPH.value:
    dl = util.DataList()
    try:
        res_csv = util.find_best_match(scheme, resdir)
        print(os.path.basename(res_csv).split(".")[0])
        
        dl.from_results(res_csv)
    except ValueError:
        env = util.init_env(scheme, alloc_ok)
        dl.from_out(env)
    name=scheme.split("_")[0]
    dl.graph(name, os.path.join(THISDIR, "imgs", name))

elif mode == util.Mode.TERM.value:
    dl = util.DataList()
    try:
        res_csv = util.find_best_match(scheme, resdir)
        print(os.path.basename(res_csv).split(".")[0])
        
        dl.from_results(res_csv)
    except ValueError:
        env = util.init_env(scheme, alloc_ok)
        dl.from_out(env)
    print(dl.term())

elif mode == util.Mode.CSV.value:
    dl = util.DataList()
    env = util.init_env(scheme, alloc_ok)
    dl.from_out(env)
    print(dl.csv())

