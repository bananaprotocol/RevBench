import json


def prepare_analysis_batch(results_file, test_data_file, output_file):
    test_data = {}
    with open(test_data_file, "r") as f:
        for line in f:
            d = json.loads(line)
            test_data[d["task_id"]] = d

    failures = []
    with open(results_file, "r") as f:
        for line in f:
            res = json.loads(line)
            if res["status"] == "FAIL" and "Assertion" in res["error_msg"]:
                tid = res["id"]
                failures.append(
                    {
                        "id": tid,
                        "ghidra": test_data[tid - 1]["ghidra_input"],
                        "ground_truth": test_data[tid - 1]["ground_truth"],
                        "model_output": res["generated_code"],
                    }
                )

    with open(output_file, "w") as f:
        json.dump(failures, f, indent=2)


prepare_analysis_batch(
    "results/codellama/00_evaluation_log.jsonl",
    "data/humaneval_c_test.jsonl",
    "to_analyze.json",
)
