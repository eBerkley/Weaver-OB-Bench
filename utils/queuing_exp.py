import sys
if len(sys.argv) < 2:
    print("Usage: python3 queuing_exp.py <path_to_csv>")
    sys.exit(1)
filename = sys.argv[1]
with open(filename, "r") as f:
    monolith_c_60 = [[float("0"+n.strip()) for n in l.split(',')] for l in f.readlines()]

frontier = []
start_time = None

for i,line in enumerate(monolith_c_60):
    rps = line[0]
    p99 = line[-4]
    if rps <= 0:
        continue
    if start_time is None:
        start_time = i
    time = i - start_time



    if len(frontier) == 0:
        frontier.append((time,rps,p99))
    else:
        better = [f for f in frontier if f[1] > rps and f[2] < p99]
        if len(better) == 0:
            frontier.append((time,rps,p99))
    print(frontier[-1])


