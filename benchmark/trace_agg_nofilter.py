
import os
import json
import csv
import argparse

def aggregate_json_files_to_csv(input_dir):
    """
    Aggregates all JSON trace files in the specified directory and converts them into a single CSV file.
    
    Args:
        input_dir (str): Directory containing JSON trace files.
    
    This function reads all JSON files, extracts trace and span details,
    and writes them into a single CSV file.
    """
    aggregated_data = []  # List to store all collected trace data
    output_csv_file = os.path.join(input_dir, "aggregated_traces.csv")  # Define the output CSV file path

    # Define CSV headers
    headers = [
        'traceID', 'spanID', 'operationName', 'refType', 'parentSpanID',
        'startTime', 'duration', 'processID', 'spanKind'
    ]

    # Iterate over all JSON files in the input directory
    for filename in sorted(os.listdir(input_dir)):
        # Ignore the final aggregated file to prevent duplicate merging
        if filename.endswith(".json") and filename != "aggregated_traces.json":
            file_path = os.path.join(input_dir, filename)

            # Read and load JSON data from the file
            with open(file_path, "r") as file:
                try:
                    data = json.load(file)  # Parse the JSON content
                    # Ensure the data follows the expected structure (a dictionary containing "data")
                    if isinstance(data, dict) and "data" in data:
                        for trace in data["data"]:
                            for span in trace.get("spans", []):
                                # Extract references info if present
                                refType = span["references"][0]["refType"] if span.get("references") else None
                                parentSpanID = span["references"][0]["spanID"] if span.get("references") else None

                                # Extract additional tags
                                tags = {tag["key"]: tag["value"] for tag in span.get("tags", [])}

                                # Append each span's details to the aggregated data list
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
                    print(f"Skipping invalid JSON file: {filename}")  # Handle corrupted or malformed JSON files

    # Write the aggregated data to the output CSV file
    with open(output_csv_file, "w", newline="") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=headers)
        writer.writeheader()
        writer.writerows(aggregated_data)

    print(f"Aggregated data saved to {output_csv_file}.")

if __name__ == "__main__":
    """
    Command-line interface to specify the input directory containing trace files.
    
    Usage:
        python trace_agg_nofilter.py <input_directory>
    
    Example:
        python trace_agg_nofilter.py ./jaeger_traces
    
    This script will read all JSON trace files in the specified directory,
    aggregate their data, and save it to a CSV file within the same directory.
    """
    parser = argparse.ArgumentParser(description="Aggregate JSON trace files from a specified directory and convert to CSV.")
    parser.add_argument("input_dir", type=str, help="Directory containing fetched JSON files")
    args = parser.parse_args()
    
    aggregate_json_files_to_csv(args.input_dir)  # Call the function with user-specified directory
