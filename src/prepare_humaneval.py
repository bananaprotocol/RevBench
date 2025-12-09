import json
import os
import re
import subprocess
import tempfile

from datasets import Dataset
from torch.fx.node import Target
from tqdm import tqdm

GHIDRA_HEADLESS_PATH = "ghidra-analyzeHeadless"
GHIDRA_SCRIPT_PATH = os.path.abspath("src/ghidra_extract.py")
HUMANEVAL_FILE = "data/humaneval.arrow"
OUTPUT_FILE = "data/humaneval_c_test.jsonl"
TARGET_OPT = "O2"


def compile_source(c_code, opt_level=TARGET_OPT):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".c", delete=False) as tmp_c:
        headers = "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <math.h>\n#include <stdbool.h>\n"
        tmp_c.write(headers + c_code)
        tmp_c_path = tmp_c.name

    bin_path = tmp_c_path.replace(".c", ".o")
    cmd = [
        "gcc",
        "-c",
        f"-{opt_level}",
        "-w",
        tmp_c_path,
        "-o",
        bin_path,
    ]

    try:
        subprocess.run(
            cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        os.remove(tmp_c_path)
        return bin_path
    except subprocess.CalledProcessError:
        os.remove(tmp_c_path)
        return None


def run_ghidra(binary_path):
    tmp_proj = os.path.join(tempfile.gettempdir(), "ghidra_temp_eval")
    os.makedirs(tmp_proj, exist_ok=True)

    cmd = [
        GHIDRA_HEADLESS_PATH,
        tmp_proj,
        "HumanEval",
        "-import",
        binary_path,
        "-postScript",
        GHIDRA_SCRIPT_PATH,
        "-deleteProject",
    ]

    proc = subprocess.run(cmd, capture_output=True, text=True)

    pseudocode = ""
    in_block = False
    for line in proc.stdout.splitlines():
        if "<<<<START_FUNC" in line:
            in_block = True
            continue
        if "<<<<END_FUNC>>>>" in line:
            in_block = False
            continue
        if in_block:
            pseudocode += line + "\n"

    return pseudocode.strip()


def main():
    print("Loading HumanEval-Decompile data...")
    dataset = Dataset.from_file(HUMANEVAL_FILE)
    filtered_data = [
        x for x in dataset if x["language"] == "c" and x["opt"] == TARGET_OPT
    ]
    print(f"Found {len(filtered_data)} samples.")

    processed_count = 0

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, "w") as f:
        for entry in tqdm(filtered_data):
            c_func = entry["func"]
            c_test = entry["test"]

            c_test = re.sub(r"^\s*#include.*$", "", c_test, flags=re.MULTILINE).strip()

            task_id = processed_count

            bin_path = compile_source(c_func)
            if not bin_path:
                print(f"Skipping {task_id}: Compilation failed")
                continue

            ghidra_code = run_ghidra(bin_path)
            os.remove(bin_path)

            if not ghidra_code:
                print(f"Skipping {task_id}: Ghidra failed")
                continue

            json_line = {
                "task_id": task_id,
                "ghidra_input": ghidra_code,
                "test_harness": c_test,
                "ground_truth": c_func,
            }

            f.write(json.dumps(json_line) + "\n")
            f.flush()

            processed_count += 1

    print(f"Done! Saved {processed_count} evaluation pairs to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
