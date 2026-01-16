import argparse
import json
import os
from collections import Counter, defaultdict
from pathlib import Path


def load_test_data(test_data_path: str) -> dict:
    test_data = {}
    with open(test_data_path, "r") as f:
        for line in f:
            d = json.loads(line)
            test_data[d["task_id"]] = d
    return test_data


def aggregate_failures(results_dir: str) -> dict:
    task_map = defaultdict(lambda: {"runs": 0, "fails": 0, "errors": Counter()})

    results_path = Path(results_dir)
    if not results_path.exists():
        raise ValueError(f"Results directory '{results_dir}' not found.")

    jsonl_files = list(results_path.glob("*evaluation_log.jsonl"))
    if not jsonl_files:
        raise ValueError(f"No evaluation log files found in '{results_dir}'")

    print(f"Found {len(jsonl_files)} evaluation log files")

    for filepath in jsonl_files:
        with open(filepath, "r") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    result_id = data.get("id")
                    if result_id is None:
                        continue

                    task_id = result_id - 1
                    status = data.get("status", "UNKNOWN")
                    error_msg = data.get("error_msg", "Unknown Error")

                    task_map[task_id]["runs"] += 1
                    if status == "FAIL":
                        task_map[task_id]["fails"] += 1
                        task_map[task_id]["errors"][error_msg] += 1
                except json.JSONDecodeError:
                    continue

    return dict(task_map)


def extract_failures(
    results_dir: str,
    test_data_path: str,
    output_path: str,
    min_fail_rate: float = 1.0,
    verbose: bool = True,
):
    test_data = load_test_data(test_data_path)
    print(f"Loaded {len(test_data)} test samples")

    task_stats = aggregate_failures(results_dir)

    training_samples = []
    compilation_count = 0
    assertion_count = 0
    timeout_count = 0

    for task_id, stats in sorted(task_stats.items()):
        if stats["runs"] == 0:
            continue

        fail_rate = stats["fails"] / stats["runs"]
        if fail_rate < min_fail_rate:
            continue

        if task_id not in test_data:
            print(f"Warning: task_id {task_id} not found in test data")
            continue

        sample = test_data[task_id]
        primary_error = (
            stats["errors"].most_common(1)[0][0] if stats["errors"] else "Unknown"
        )

        training_sample = {
            "input": sample["ghidra_input"],
            "output": sample["ground_truth"],
        }
        training_samples.append(training_sample)

        if "Compilation" in primary_error:
            compilation_count += 1
        elif "Assertion" in primary_error:
            assertion_count += 1
        elif "Timeout" in primary_error:
            timeout_count += 1

    output_dir = Path(output_path).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        for sample in training_samples:
            f.write(json.dumps(sample) + "\n")

    if verbose:
        print("\n" + "=" * 50)
        print("EXTRACTION SUMMARY")
        print("=" * 50)
        print(f"Total failed samples extracted: {len(training_samples)}")
        print(f"  - Compilation errors: {compilation_count}")
        print(f"  - Assertion failures: {assertion_count}")
        print(f"  - Timeouts: {timeout_count}")
        print(f"\nOutput written to: {output_path}")
        print("=" * 50)

    return training_samples


def main():
    parser = argparse.ArgumentParser(
        description="Extract failed samples from evaluation logs for targeted training."
    )
    parser.add_argument(
        "--results-dir",
        required=True,
        help="Directory containing evaluation_log.jsonl files (e.g., results/r64_a64)",
    )
    parser.add_argument(
        "--test-data",
        default="data/humaneval_c_test.jsonl",
        help="Path to test data with ground truth",
    )
    parser.add_argument(
        "--output",
        default="data/failures/all_errors.jsonl",
        help="Output path for training dataset",
    )
    parser.add_argument(
        "--min-fail-rate",
        type=float,
        default=1.0,
        help="Minimum failure rate to include (0.0-1.0, default: 1.0 = always fails)",
    )

    args = parser.parse_args()

    extract_failures(
        results_dir=args.results_dir,
        test_data_path=args.test_data,
        output_path=args.output,
        min_fail_rate=args.min_fail_rate,
    )


if __name__ == "__main__":
    main()
