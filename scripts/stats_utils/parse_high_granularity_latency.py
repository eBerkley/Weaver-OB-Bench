#!/bin/python3

import os
import json
import csv
from typing import Union, Dict, List, TypeAlias
import sys

component_name = sys.argv[1]
p50_json_file = sys.argv[2]
p99_json_file = sys.argv[3]


def load_json(file_path: str):
    with open(file_path, 'r') as f:
        return json.load(f)

def shorten(text: str):
    if text.startswith("github.com/ServiceWeaver/weaver/Main"):
        return "Main"
    elif text.startswith("github.com/ServiceWeaver/onlineboutique"):
        parts = text.split("/")
        return parts[-1] if parts[-1] else parts[-2]
    return text

metric_t: TypeAlias = Dict[str, Union[Dict[str, str], List[str]]]
metric_result_t : TypeAlias = Dict[str, Dict[str, List[metric_t]]]

def get_latencies(msg_lat: metric_result_t):
    component_latencies_dict: dict[str, float] = {}    
    for result in msg_lat["data"]["result"]:
        caller=result["metric"]["caller"]
        value=float(result["value"][1])
        component_latencies_dict[caller]=value


        

