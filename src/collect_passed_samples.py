import argparse
import json
import os


def collect_passed_samples(eval_dir, test_data_file, output_file):
    test_data = {}
    print(f"Loading test data from {test_data_file}...")
    with open(test_data_file, "r") as f:
        for line in f:
            if not line.strip():
                continue

            item = json.loads(line)

            tid = item.get("task_id")

            test_data[tid] = {
                "ghidra_input": item.get("ghidra_input", ""),
                "ground_truth": item.get("ground_truth", ""),
            }

    passed_samples = []
    found_ids = set()
    print(f"Scanning evaluation results in {eval_dir}...")
    for filename in os.listdir(eval_dir):
        if filename.endswith(".jsonl"):
            file_path = os.path.join(eval_dir, filename)
            with open(file_path, "r") as f:
                for line in f:
                    if not line.strip():
                        continue

                    res = json.loads(line)

                    if res.get("status") == "PASS":
                        tid = res.get("id") - 1

                        if tid in found_ids:
                            continue

                        ref = test_data.get(tid)
                        if ref:
                            sample = {
                                "task_id": tid,
                                "ghidra_prompt": ref["ghidra_input"],
                                "model_output": res["generated_code"],
                                "ground_truth": ref["ground_truth"],
                            }
                            passed_samples.append(sample)
                            found_ids.add(tid)

    with open(output_file, "w") as f:
        json.dump(passed_samples, f, indent=2)

    print("=" * 50)
    print("Extraction Complete!")
    print(f"Total Unique Passed Tasks Found: {len(passed_samples)}")
    print(f"Results saved to: {output_file}")
    print("=" * 50)


def main():
    parser = argparse.ArgumentParser(
        description="Collected Passed samples for Causal Tracing."
    )
    parser.add_argument(
        "--eval_dir", required=True, help="Directory containing eval .jsonl files"
    )
    parser.add_argument(
        "--test_data", required=True, help="Path to original test data .jsonl file"
    )
    parser.add_argument(
        "--output", default="passed_samples_for_tracing.json", help="Output file name"
    )

    args = parser.parse_args()
    collect_passed_samples(args.eval_dir, args.test_data, args.output)


if __name__ == "__main__":
    main()
