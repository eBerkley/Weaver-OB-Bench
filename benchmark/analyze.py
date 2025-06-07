#!/bin/python3

import util
from typing import List
mode, scheme, alloc_ok = util.get_args()
env = util.init_env(scheme, alloc_ok)
idxs = util.get_hold_idxs(env.users)

ds: List[util.DataPoint] = []

for s, e in idxs:
    usr = env.users[s]
    d = util.DataPoint(usr, env.p50[s:e], env.p99[s:e], env.rps[s:e], env.cpu[s:e])
    ds.append(d)


if mode == util.Mode.TERM.value:
    print(f'{"users".rjust(5)}: {"rps".rjust(8)}, {"p50".rjust(6)}, {"p99".rjust(7)}, {"cpu".rjust(5)}')
    for d in ds:
        print(f"{d.get_users():5d}: {d.get_rps():8.2f}, {d.get_p50():6.2f}, {d.get_p99():7.2f}, {d.get_cpu():5.2f} ")
        
elif mode == util.Mode.CSV.value:
    print('users,rps,p50,p99,cpu')
    for d in ds:
        print(f"{d.get_users()},{d.get_rps()},{d.get_p50()},{d.get_p99()},{d.get_cpu()}")

