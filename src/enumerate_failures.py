import argparse
import json
import os
from collections import Counter, defaultdict


def enumerate_failures(directory_path):
    task_map = defaultdict(lambda: {"runs": 0, "fails": 0, "errors": Counter()})

    total_files = 0

    if not os.path.exists(directory_path):
        print(f"Error: Directory '{directory_path}' not found.")
        return

    for filename in os.listdir(directory_path):
        if filename.endswith(".jsonl"):
            total_files += 1
            file_path = os.path.join(directory_path, filename)

            with open(file_path, "r") as f:
                for line_num, line in enumerate(f, 1):
                    if not line.strip():
                        continue

                    try:
                        data = json.loads(line)
                        task_id = data.get("id", f"unknown_line_{line_num}")
                        status = data.get("status", "UNKNOWN")
                        error_msg = data.get("error_msg", "No Error Message")

                        task_map[task_id]["runs"] += 1
                        if status == "FAIL":
                            task_map[task_id]["fails"] += 1
                            task_map[task_id]["errors"][error_msg] += 1
                    except json.JSONDecodeError:
                        print(
                            f"Warning: Skipping invalid JSON on line {line_num} in {filename}"
                        )

    print_report(task_map, total_files)


def print_report(task_map, total_files):
    failing_tasks = {tid: info for tid, info in task_map.items() if info["fails"] > 0}

    print("=" * 60)
    print("TASK FAILURE ENUMERATION REPORT")
    print(f"Analyzed {total_files} JSONL files | Total Unique Tasks: {len(task_map)}")
    print("=" * 60)

    if not failing_tasks:
        print("No failures found!")
        return

    sorted_ids = sorted(failing_tasks.keys())

    print(f"{'Task ID':<10} | {'Fails/Total':<12} | Primary Error Type")
    print("-" * 60)

    compilation_fails = 0
    assertion_fails = 0

    for tid in sorted_ids:
        info = failing_tasks[tid]
        most_common_error = info["errors"].most_common(1)[0][0]

        print(f"{tid:<10} | {info['fails']:>2}/{info['runs']:<9} | {most_common_error}")

        if "Compilation" in most_common_error:
            compilation_fails += 1
        elif "Assertion" in most_common_error:
            assertion_fails += 1

    print("-" * 60)
    print("SUMMARY OF FAILURES:")
    print(f"  - Unique Tasks Failing: {len(failing_tasks)}")
    print(f"  - Total Tasks with Compilation Errors: {compilation_fails}")
    print(f"  - Total Tasks with Assertion Errors: {assertion_fails}")
    print("=" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Enumerate failing tasks in JSONL results."
    )
    parser.add_argument("dir", help="Directory containing .jsonl files")
    args = parser.parse_args()
    enumerate_failures(args.dir)
