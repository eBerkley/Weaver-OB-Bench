#!/usr/bin/python3
import testUtil
import os
import argparse

def get_num_tasks() -> int :
  parser = argparse.ArgumentParser(
                      prog='getInputs',
                      description='Generates a text representation of the requests that will be made to the apps.',
                      epilog='')
  parser.add_argument('tasks', type=int, nargs=1, default=30,
                      help='number of seperate tasks to produce.')
  args = parser.parse_args()
  return args.tasks[0]
# 

TASKS = get_num_tasks()

IN = os.path.join(os.path.dirname(__file__), "inputs.txt")

if __name__ == "__main__":
    with open(IN, "w") as f:
        for taskNum in range(TASKS):
            t = testUtil.GetTask()
            f.write(str(t))
            f.write(f"{taskNum+1}---\n")
