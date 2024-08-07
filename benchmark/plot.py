#!/bin/python3
from matplotlib.lines import Line2D
import matplotlib.pyplot as plt


import pandas as pd
import numpy as np
import multiprocessing
import os
from typing import List
from statistics import median

TITLE="Service Weaver"

DIRNAME = os.path.dirname(__file__)
STATS = os.path.join(DIRNAME, "stats")

MAX_CORES = multiprocessing.cpu_count()

QOS = 10 # ms

cpu = pd.read_csv(os.path.join(STATS, "cpu.csv"))


def drawQOSline(ax):
    ax.axhline(QOS, color='red', linestyle='--', alpha=0.5, linewidth=0.5, label='QOS Threshold')

def MAKE_IMG():
    
    _df = pd.read_csv(os.path.join(STATS, f"lat_stats_history.csv"), keep_default_na=False)

    df = _df.where(_df['Name'] == 'Aggregated')
    df = df.where(_df['50%'] != 'N/A')
    df = df.dropna()



    start_time = min(df['Timestamp']) / 60

    def adjusted_minutes(f):
        return (f/60) - start_time

    def minutes(f):
        return f/60

    # ==================== Get Data ====================
    


    L_MINS = df['Timestamp'].apply(adjusted_minutes).values
    "X Axis for Median, Average, Users, RPS"
    C_MINS = cpu['Seconds'].apply(minutes).values
    "X Axis for CPU Cores"

    MEDIAN = df['Total Median Response Time'].astype(float).values
    AVERAGE = df['Total Average Response Time'].astype(float).values

    P50 = df['50%'].astype(float).values
    P66 = df['66%'].astype(float).values
    P75 = df['75%'].astype(float).values
    P80 = df['80%'].astype(float).values
    P90 = df['90%'].astype(float).values
    P95 = df['95%'].astype(float).values
    P98 = df['50%'].astype(float).values
    P99 = df['99%'].astype(float).values

    P99_9 = df['99.9%'].astype(float).values
    P99_99 = df['99.99%'].astype(float).values
    P100 = df['100%'].astype(float).values

    CORES = cpu['CPU Cores'].values

    RPS = df['Requests/s'].values
    USERS = df['User Count'].values

    def get_y_ticks():
        prev_user = USERS[0]
        ret = {}
        repeating=False

        startIDX = 0
        holdIDX = 0
        for idx in range(1, len(USERS)):
            u = USERS[idx]
            if u == prev_user:
                if repeating == False:
                    holdIDX = idx

                #     ret.append(L_MINS[idx])
                repeating = True
            elif repeating == True:
                # ret.append((idx, u, L_MINS[idx]))
                ret[int(prev_user)] = (startIDX, holdIDX, idx)

                startIDX = idx
                # ret.append(L_MINS[idx])
                # ret.append(idx)
                repeating = False
            prev_user = u
        
        if repeating == True:
            ret[int(prev_user)] = (startIDX, holdIDX, len(USERS) - 1)
        return ret

    # dict {users: (start_idx, hold_idx, end_idx)}
    test_times = get_y_ticks()
    
    
    # ==================== Init Plots ====================
    
    
    def get_data():
        plt.cla()
        # fig, ax = plt.subplots(1,1)
        
        x = np.arange(len(test_times.keys()))
        # width=0.25
        # multiplier=0
        print(len(L_MINS))
        print(len(CORES))
        for users in test_times.keys():
            start, hold, end = test_times[users]
            QPS = median(RPS[hold:end])
            AVG = median(P50[hold:end])
            TAIL = median(P99[hold:end])
            CPUS = median(CORES[hold:end])
            print(f"{users} \t\t{QPS:.1f} \t\t{AVG} \t\t\t{TAIL} \t\t\t{CPUS}")

    def other_img(_users: int):

        start, hold, end = test_times[_users]
        lns: List[Line2D] = []
        plt.cla()
        lns += plt.plot(L_MINS[start:end], P50[start:end], 'g--', label='50%')
        lns += plt.plot(L_MINS[start:end], P75[start:end], 'b--', label='75%')
        lns += plt.plot(L_MINS[start:end], P99[start:end], 'r--', label='99%')

        plt.axvline(L_MINS[hold], color='gray', linestyle='--', alpha=0.5, linewidth=0.75)
        drawQOSline(plt)

        lables = [l.get_label() for l in lns]
        
        plt.legend(lns, lables)

        plt.ylabel("Latency (ms)")
        plt.xlabel("Time (Minutes)")
        plt.title(str(_users))

        plt.ylim(0.0, max([max(x.get_ydata()) for x in lns]))
        plt.xlim(L_MINS[start], L_MINS[end])
        
        plt.savefig(os.path.join(DIRNAME, "imgs", f"{TITLE.lower().replace(' ', '')}_{_users}"))



    def main_img():

        plt.cla()
        ax_top_l = plt.subplot(211)
        "Total Latency"

        ax_top_r = ax_top_l.twinx()
        "CPU Cores"

        ax_bot = plt.subplot(212)
        "Requests/Sec, Current Users"
        
        # ==================== Plot Data ====================
        
        lns: List[Line2D] = []
        # lns += ax_top_l.plot(L_MINS, MEDIAN, 'r--', label='Median')
        # lns += ax_top_l.plot(L_MINS, AVERAGE, 'b--', label='Average')
        lns += ax_top_l.plot(L_MINS, P50, 'g--', label='50%')
        # lns += ax_top_l.plot(L_MINS, P66, 'g--', label='66%')
        lns += ax_top_l.plot(L_MINS, P75, 'b--', label='75%')
        # lns += ax_top_l.plot(L_MINS, P80, 'c--', label='80%')
        # lns += ax_top_l.plot(L_MINS, P90, 'm--', label='90%')
        # lns += ax_top_l.plot(L_MINS, P95, 'y--', label='95%')
        lns += ax_top_l.plot(L_MINS, P99, 'r--', label='99%')

        lns += ax_top_r.plot(C_MINS, CORES, 'c-', label='CPU Cores')

        ax_bot.plot(L_MINS, RPS, 'g-', label="Requests/sec") 
        ax_bot.plot(L_MINS, USERS, 'b-', label="Current Users")

        
        # ==================== Set Ticks =====================
        


        # ==================== Set Labels ====================

        ax_top_l.set_ylabel('Latency (ms)')
        ax_top_r.set_ylabel('Cpu Cores')

        ax_bot.set_xlabel("Time (Minutes)")

        
        # ==================== Set Legend ====================


        lables = [l.get_label() for l in lns]
        ax_top_l.legend(lns, lables, loc='lower right')

        ax_bot.legend(loc='upper left')

        
        # ==================== Set Axis ======================
        
        _test = max([max(x.get_ydata()) for x in lns])
        _MAX_LATENCY = max(P75)
        _MAX_LATENCY = _test
        # _MAX_LATENCY = max(*MEDIAN, *AVERAGE)
        MAX_LATENCY = _MAX_LATENCY + _MAX_LATENCY/10
        ax_top_l.set_ylim(bottom=0.0, top=MAX_LATENCY)
        ax_top_r.set_ylim(bottom=0.0, top=MAX_CORES)

        ax_top_l.set_xlim(left=0.0, right=max(L_MINS))
        #ax_top_r.set_xlim(left=0.0, right=L_MINS.max())

        # ax_top_l.yaxis.set_ticks(np.arange(stop=MAX_LATENCY, step=MAX_LATENCY/4), )
        # ax_top_l.yaxis.grid(visible=True, linestyle='--', which='major', color='gray', alpha=0.25)

        ax_bot.set_ylim(bottom=0.0, top=11000.0)
        ax_bot.set_xlim(left=0.0, right=max(L_MINS))


        

        # ax_top_l.xaxis.set_ticks(minor=True, ticks=get_y_ticks())
        # ax_top_l.xaxis.grid(visible=True, which='minor', linestyle='--', color='gray', alpha=0.25)
        # ax_bot.xaxis.set_ticks(minor=True, ticks=get_y_ticks())
        # ax_bot.xaxis.grid(visible=True, which='minor', linestyle='--', color='gray', alpha=0.25)

        for t in get_y_ticks():
            ax_top_l.axvline(t, color='grey', linestyle='--', alpha=0.25, linewidth=0.5)
            ax_bot.axvline(t, color='grey', linestyle='--', alpha=0.25, linewidth=0.5)

        drawQOSline(ax_top_l)
        
        # ==================== Set Title ======================
        
        ax_top_l.set_title(f"{TITLE}")
        
        plt.savefig(os.path.join(DIRNAME, "imgs", f"{TITLE.lower().replace(' ', '')}"))


    # print("\nUsers \t\tQPS \t  Median Latency \tMedian Tail Latency \tMedian CPU Cores Utilized\n")
    # for i in test_times.keys():
    #     other_img(i)

    get_data()
    # main_img()




if __name__ == "__main__":
    MAKE_IMG()
    