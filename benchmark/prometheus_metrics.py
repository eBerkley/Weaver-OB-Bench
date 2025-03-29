import os
import json
import argparse
import csv

def load_json(file_path):
    with open(file_path, 'r') as f:
        return json.load(f)

def total_requests(request_data):
    total = 0
    for result in request_data["data"]["result"]:
        value_str = result["value"][1]
        total += float(value_str)
    return total

def msg_count(msg_bytes):
    caller_component_dict = {}
    valid_prefixes = [
        "github.com/eberkley/weaver/Main",
        "github.com/eBerkley/Weaver-OB-Bench"
    ]
    for result in msg_bytes["data"]["result"]:
        metric = result["metric"]
        caller: str = metric.get("caller", "unknown")
        component: str = metric.get("component", "unknown")

        if not any(caller.startswith(prefix) for prefix in valid_prefixes):
            continue
        pair = (caller, component)
        value = float(result["value"][1])
        caller_component_dict[pair] = caller_component_dict.get(pair, 0) + value
        
        agg_pair= ('*', component)
        caller_component_dict[agg_pair] = caller_component_dict.get(agg_pair, 0) + value

    return caller_component_dict

def shorten_str(text):
    if text.startswith("github.com/ServiceWeaver/weaver/Main"):
        return "Main"
    elif text.startswith("github.com/ServiceWeaver/onlineboutique"):
        parts = text.split("/")
        return parts[-1] if parts[-1] else parts[-2]
    return text

def get_service_latencies(msg_svc):
    component_latencies_dict: dict[str, float]={}
    for result in msg_svc["data"]["result"]:
        component=result["metric"]["component"]
        value=float(result["value"][1])
        component_latencies_dict[component] = value

    return component_latencies_dict

def get_request_latencies(msg_req, msg_req_sums) -> float:
    
    count_dict: dict[str, int] = {}
    lat_dict : dict[str, float] = {}
    for result in msg_req["data"]["result"]:
        label=result["metric"]["label"]
        lat=float(result["value"][1])
        lat_dict[label]=lat

    for result in msg_req_sums["data"]["result"]:
        label=result["metric"]["label"]
        count=float(result["value"][1])
        count_dict[label]=int(count)
    
    
    p50s=[]
    for label, _ in count_dict.items():
        p50s += [lat_dict[label]] * count_dict[label]
    
    from statistics import mean
    return mean(p50s)

def save_to_csv(filepath, metric_dict, title, column_name):
    def sort_func(x):
        if x[0][0] == '*':
            return x[1]*1000000
        return x[1]
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["Caller", "Component", column_name])
        for (caller, component), value in sorted(metric_dict.items(), key=sort_func, reverse=True):
            writer.writerow([shorten_str(caller), shorten_str(component), value])
    print(f"{title} saved to: {filepath}")

def save_to_csv_comp_only(filepath, metric_dict1, metric_dict2, title, column_name1, column_name2):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["Component", column_name1, column_name2])
        for component, value in sorted(metric_dict1.items(), key=lambda x: x[1], reverse=True):
            writer.writerow([shorten_str(component), value, metric_dict2[component]])
    print(f"{title} saved to: {filepath}")

def main():
    parser = argparse.ArgumentParser(description="Compile Service Weaver metrics into CSV format.")
    parser.add_argument('request_count', help="JSON file with total number of every request type")
    parser.add_argument('msg_reply_bytes', help="JSON file with total reply bytes through component pairs")
    parser.add_argument('msg_request_bytes', help="JSON file with total request bytes through component pairs")
    parser.add_argument('method_count', help="JSON file with message counts through component pairs")

    parser.add_argument('p50_service_latency', help="JSON file with p50 service latency")
    parser.add_argument('p99_service_latency', help="JSON file with p99 service latency")
    parser.add_argument('p50_request_latency', help="JSON file with p50 request latency")
    parser.add_argument('p99_request_latency', help="JSON file with p99 request latency")


    args = parser.parse_args()

    request_sum = total_requests(load_json(args.request_count))
    msg_reply_bytes_sum = msg_count(load_json(args.msg_reply_bytes))
    msg_request_bytes_sum = msg_count(load_json(args.msg_request_bytes))
    msg_count_sum = msg_count(load_json(args.method_count))
    
    # for i in msg_count_sum.items():
    #     print(i)

    p50_service_latencies = get_service_latencies(load_json(args.p50_service_latency))
    p50_request_latency = get_request_latencies(load_json(args.p50_request_latency), load_json(args.request_count))

    p99_service_latencies = get_service_latencies(load_json(args.p99_service_latency))
    p99_request_latency = get_request_latencies(load_json(args.p99_request_latency), load_json(args.request_count))

    p50_service_latencies["github.com/eberkley/weaver/Main"] = p50_request_latency
    p99_service_latencies["github.com/eberkley/weaver/Main"] = p99_request_latency

    # Combine bytes
    msg_bytes_sum = {key: msg_reply_bytes_sum.get(key, 0) + msg_request_bytes_sum.get(key, 0)
                     for key in set(msg_reply_bytes_sum) | set(msg_request_bytes_sum)}

    if request_sum == 0:
        print("Error: Total request sum is zero. Cannot normalize values.")
        return
    
    # Normalize
    msg_bytes_sum = {key: value / request_sum for key, value in msg_bytes_sum.items()}
    msg_count_sum = {key: value / request_sum for key, value in msg_count_sum.items()}

    # Use the directory of the first input file as output location
    output_dir = os.path.dirname(os.path.abspath(args.request_count))

    save_to_csv(os.path.join(output_dir, "normalized_msg_bytes.csv"), msg_bytes_sum,
                "Normalized Message Bytes", "NormalizedBytes")
    save_to_csv(os.path.join(output_dir, "normalized_msg_counts.csv"), msg_count_sum,
                "Normalized Message Counts", "NormalizedCount")
    save_to_csv_comp_only(os.path.join(output_dir, "svc_latency.csv"), p50_service_latencies, p99_service_latencies, "P50 Service Latency", "P50 Latency", "P99 Latency")

if __name__ == "__main__":
    main()

