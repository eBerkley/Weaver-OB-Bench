import os
import json
import csv
import argparse

def count_invalid_parent_spans(trace_data):
    """
    Counts only the spans that contain 'invalid parent span' warnings in a trace dataset.
    A trace is considered invalid if any of its spans contain an 'invalid parent span' warning.
    """
    invalid_spans = 0
    total_spans = 0
    valid_traces = []
    
    for trace in trace_data.get("data", []):
        total_spans += len(trace.get("spans", []))
        
        # Count only spans that contain 'invalid parent span' warnings
        trace_invalid_spans = sum(
            1 for span in trace.get("spans", []) if span.get("warnings") and 
            any("invalid parent span" in warning for warning in span["warnings"])
        )
        invalid_spans += trace_invalid_spans
        
        # Only add traces that do not contain any invalid parent spans
        if trace_invalid_spans == 0:
            valid_traces.append(trace)
    
    return invalid_spans, total_spans, valid_traces

def aggregate_json_files_to_csv(input_dir):
    """
    Aggregates all JSON trace files in the directory and converts them to a CSV file.
    
    - If a trace contains any invalid parent span, it is removed.
    - If more than 30 spans in a fetch are invalid or more than 10% of spans are invalid, the fetch is discarded.
    - Duplicate traces are removed from the final CSV file.
    
    Args:
        input_dir (str): Directory containing JSON trace files.
    """
    aggregated_data = []
    output_csv_file = os.path.join(input_dir, "aggregated_traces.csv")
    seen_traces = set()
    
    # Define CSV headers
    headers = [
        'traceID', 'spanID', 'operationName', 'refType', 'parentSpanID',
        'startTime', 'duration', 'processID', 'spanKind'
    ]
    
    for filename in sorted(os.listdir(input_dir)):
        if filename.endswith(".json") and filename != "aggregated_traces.json":
            file_path = os.path.join(input_dir, filename)
            
            with open(file_path, "r") as file:
                try:
                    data = json.load(file)
                    invalid_spans, total_spans, valid_traces = count_invalid_parent_spans(data)
                    
                    # Check filtering conditions
                    if invalid_spans > 300 or (total_spans > 0 and invalid_spans / total_spans > 0.1):
                        print(f"Skipping {filename} due to excessive invalid parent spans.")
                        continue
                    
                    for trace in valid_traces:
                        trace_id = trace["traceID"]
                        if trace_id in seen_traces:
                            continue
                        seen_traces.add(trace_id)
                        
                        for span in trace["spans"]:
                            refType = span["references"][0]["refType"] if span.get("references") else None
                            parentSpanID = span["references"][0]["spanID"] if span.get("references") else None
                            
                            tags = {tag["key"]: tag["value"] for tag in span.get("tags", [])}
                            aggregated_data.append({
                                'traceID': span.get('traceID', ''),
                                'spanID': span.get('spanID', ''),
                                'operationName': span.get('operationName', ''),
                                'refType': refType,
                                'parentSpanID': parentSpanID,
                                'startTime': span.get('startTime', ''),
                                'duration': span.get('duration', ''),
                                'processID': span.get('processID', ''),
                                'spanKind': tags.get('span.kind', '')
                            })
                except json.JSONDecodeError:
                    print(f"Skipping invalid JSON file: {filename}")
                    continue
    
    with open(output_csv_file, "w", newline="") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=headers)
        writer.writeheader()
        writer.writerows(aggregated_data)
    
    print(f"Aggregated data saved to {output_csv_file}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Aggregate JSON trace files and convert them to a CSV file.")
    parser.add_argument("input_dir", type=str, help="Directory containing fetched JSON files")
    
    help_text = """
    This script processes JSON trace files in the specified input directory:
    - Traces with 'invalid parent span' errors are removed.
    - Fetches with excessive invalid spans (either more than 30 or more than 10% of total spans) are discarded.
    - Duplicate traces are filtered out.
    - The cleaned data is saved into 'aggregated_traces.csv' within the same directory.
    
    Example usage:
        python trace_agg.py ./jaeger_traces
    """
    parser.print_help = lambda: print(help_text)
    
    args = parser.parse_args()
    aggregate_json_files_to_csv(args.input_dir)
