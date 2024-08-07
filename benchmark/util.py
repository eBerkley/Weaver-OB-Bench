import os
from typing import *
from collections import namedtuple

LAT_CSV_NAME = "lat_stats_history.csv"
DISTRIBUTED_NAME = "none"
OUT_DIR = "out"

from sys import argv
_test_name = ""
if len(argv) < 1:
    # print("ERR!! arg 1 should be name of folder test data is in.")
    # exit(1)
    _test_name = argv[1]

TEST_NAME = _test_name


DIRNAME= os.path

DISTRIBUTED_DIR = os.path.join(DIRNAME, OUT_DIR, DISTRIBUTED_NAME)
