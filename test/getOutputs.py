import testUtil
import os
from typing import Dict, Literal, Optional, Iterable, Tuple, List, Callable, Type

import requests
import shutil
import argparse

IN = os.path.join(os.path.dirname(__file__), "inputs.txt")
_WEAVEROUT = os.path.join(os.path.dirname(__file__), "weaverOut")
_GRPCOUT = os.path.join(os.path.dirname(__file__), "gRPCOut")

ADDR="http://127.0.0.1:8080"

def get_outdir() -> str :
    

  parser = argparse.ArgumentParser(
                      prog='getOutputs',
                      description='Get the html output for each task from a online boutique implementation',
                      epilog='')

  parser.add_argument('version', type=str, nargs=1, default="weaver",
                      help='gRPC, grpc, weaver')



  args = parser.parse_args()
  print(args.version)
  if "g" in args.version[0] or "G" in args.version[0]:
    print(_GRPCOUT)
    return _GRPCOUT
  print(_WEAVEROUT)
  return _WEAVEROUT






# OUTDIR = _WEAVEROUT
# OUTDIR = _GRPCOUT
OUTDIR = get_outdir()


def resetDir(dirname: str):
    shutil.rmtree(dirname, True)
    os.mkdir(dirname)


def Request(addr: str, s: requests.Session, i: testUtil.Input):
    if i.method == 'get':
        return s.get(addr+i.url)
    return s.post(addr+i.url, data=i.dict)

def Output(addr: str, t: testUtil.Task) -> List[requests.Response]:
    s = requests.session()
    out: List[requests.Response] = []
    for i in t.inputs:
        out.append(Request(addr, s, i))

    return out

if __name__ == "__main__":
    tasks: List[testUtil.Task] = []

    with open(IN, "r") as f:
        suite = f.read().split("---\n")
        for task in suite:
            tasks.append(testUtil.Task.make(task))
    
    resetDir(OUTDIR)

    for i in range(len(tasks)):
        taskDir = os.path.join(OUTDIR, str(i))
        
        os.mkdir(taskDir)
        
        resp = Output(ADDR, tasks[i])

        for x in range(len(resp)):
            with open(os.path.join(taskDir, f"{str(x)}.html"), "w") as f:
                f.write(resp[x].text)