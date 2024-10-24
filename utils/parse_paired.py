import sys
file = sys.argv[1]
with open(file, "r") as f:
    lines = f.readlines()
    mts = 0
    util = 0
    for line in lines:
        data = [float("0"+x.strip()) for x in line.strip().split(",")]
        p99 = data[-4]
        if p99 < 100 and data[0] > mts:
            mts = data[0]
            util = data[1]


print(file,mts, util)

