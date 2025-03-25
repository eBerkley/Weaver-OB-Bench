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
        "github.com/ServiceWeaver/weaver/Main",
        "github.com/ServiceWeaver/onlineboutique"
    ]
    for result in msg_bytes["data"]["result"]:
        metric = result["metric"]
        caller = metric.get("caller", "unknown")
        component = metric.get("component", "unknown")

        if not any(caller.startswith(prefix) for prefix in valid_prefixes):
            continue

        pair = (caller, component)
        value = float(result["value"][1])
        caller_component_dict[pair] = caller_component_dict.get(pair, 0) + value

    return caller_component_dict

def shorten_str(text):
    if text.startswith("github.com/ServiceWeaver/weaver/Main"):
        return "Main"
    elif text.startswith("github.com/ServiceWeaver/onlineboutique"):
        parts = text.split("/")
        return parts[-1] if parts[-1] else parts[-2]
    return text

def save_to_csv(filepath, metric_dict, title, column_name):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["Caller", "Component", column_name])
        for (caller, component), value in sorted(metric_dict.items(), key=lambda x: x[1], reverse=True):
            writer.writerow([shorten_str(caller), shorten_str(component), value])
    print(f"{title} saved to: {filepath}")

def main():
    parser = argparse.ArgumentParser(description="Compile Service Weaver metrics into CSV format.")
    parser.add_argument('request_count', help="JSON file with total number of every request type")
    parser.add_argument('msg_reply_bytes', help="JSON file with total reply bytes through component pairs")
    parser.add_argument('msg_request_bytes', help="JSON file with total request bytes through component pairs")
    parser.add_argument('method_count', help="JSON file with message counts through component pairs")

    args = parser.parse_args()

    request_sum = total_requests(load_json(args.request_count))
    msg_reply_bytes_sum = msg_count(load_json(args.msg_reply_bytes))
    msg_request_bytes_sum = msg_count(load_json(args.msg_request_bytes))
    msg_count_sum = msg_count(load_json(args.method_count))

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



if __name__ == "__main__":
    main()

