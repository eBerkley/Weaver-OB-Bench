#!/bin/python3

import pandas as pd
import numpy as np
import os

DIRNAME = os.path.dirname(__file__)
STATSDIR = os.path.join(DIRNAME, "out")
SCHEMES = os.listdir(STATSDIR)
SCHEMES.sort()

print("scheme".ljust(20), "qps".ljust(10), "p50".ljust(5), "p99".ljust(5))
for scheme in SCHEMES:
    
    scheme_dir = os.path.join(STATSDIR, scheme)
    scheme_stats = os.path.join(scheme_dir, "stats")
    agg_stats = os.path.join(scheme_stats, "aggregated.csv")

    df_agg = pd.read_csv(agg_stats).dropna()

    qps = df_agg['Requests/s'].astype(float).values
    p50 = df_agg['50%'].astype(float).values
    p99 = df_agg['99%'].astype(float).values

    med_tail_ratios: dict[float, float] = {}
    for i in range(len(p50)):
        if not (i % 5) and p50[i]:
            med_tail_ratios[qps[i]] = round(p99[i] / p50[i], 2)

    real_vals = df_agg.where(df_agg['99%'] < 100, other=0.0)

    real_qps = real_vals['Requests/s'].astype(float).values
    
    print(scheme.ljust(20), str(real_qps.max()).ljust(10), str(p50.max()).ljust(5), str(p99.max()).ljust(5))
    # print([f"{k}= {v}".ljust(13) for k, v in med_tail_ratios.items()])
    # print()