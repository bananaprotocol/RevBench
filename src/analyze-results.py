import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np


def main():
    parser = argparse.ArgumentParser(description="Analyze evaluation results.")
    parser.add_argument(
        "--path", default="results/codellama", type=str, help="Folder path"
    )
    args = parser.parse_args()

    result_path = Path(args.path)
    if not result_path.exists():
        print(f"Error: Path {result_path} does not exist.")
        sys.exit(1)

    files = sorted(list(result_path.glob("*.jsonl")))

    compile_counts = []
    pass_counts = []

    expected_total = None

    print(f"{'File':<35} | {'Total':<5} | {'Comp':<5} | {'Pass':<5} | {'Pass %':<7}")
    print("-" * 70)

    for file_path in files:
        total = 0
        compiled = 0
        passed = 0

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue

                    total += 1
                    data = json.loads(line)
                    error_msg = data.get("error_msg", "")

                    if error_msg == "Compilation Error":
                        continue

                    compiled += 1

                    if data["error_msg"] == "Passed":
                        passed += 1

        except (json.JSONDecodeError, KeyError) as e:
            print(f"Error parsing {file_path.name}: {e}")

        if expected_total is None:
            expected_total = total
        elif total != expected_total:
            print(
                f"WARNING: {file_path.name} has {total} tasks (Expected {expected_total}). Run might be incomplete."
            )

        compile_counts.append(compiled)
        pass_counts.append(passed)

        pass_acc = (passed / total * 100) if total > 0 else 0
        print(
            f"{file_path.name:<35} | {total:<5} | {compiled:<5} | {passed:<5} | {pass_acc:6.2f}%"
        )

    if expected_total is None or expected_total == 0:
        print("No valid data found.")
        return

    compile_arr = np.array(compile_counts)
    pass_arr = np.array(pass_counts)

    print("\n" + "=" * 30)
    print("TOTAL RESULTS")
    print("=" * 30)

    c_mean = np.mean(compile_arr)
    c_std = np.std(compile_arr)
    p_mean = np.mean(pass_arr)
    p_std = np.std(pass_arr)

    print(f"Total Tasks Per File:    {expected_total}")
    print("-" * 30)
    print(f"Compiled Mean (Count):   {c_mean:.2f}")
    print(f"Compiled StdDev (Count): {c_std:.2f}")
    print(
        f"Compiled Rate:           {(c_mean / expected_total * 100):.2f}% (± {(c_std / expected_total * 100):.2f}%)"
    )
    print("-" * 30)
    print(f"Passed Mean (Count):     {p_mean:.2f}")
    print(f"Passed StdDev (Count):   {p_std:.2f}")
    print(
        f"Passed Rate:             {(p_mean / expected_total * 100):.2f}% (± {(p_std / expected_total * 100):.2f}%)"
    )


if __name__ == "__main__":
    main()
