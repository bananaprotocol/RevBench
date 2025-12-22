import argparse
import json
import os
import re
import subprocess
import tempfile

from tqdm import tqdm

GHIDRA_PATH = "ghidra-analyzeHeadless"
GHIDRA_SCRIPT_PATH = "src/ghidra_extract.py"
PROJECT_DIR = "./ghidra_tmp"
GCC_CMD = ["gcc", "-O2", "-c"]


def get_ghidra_functions(c_code):
    with tempfile.TemporaryDirectory() as tmpdir:
        c_file = os.path.join(tmpdir, "temp.c")
        o_file = os.path.join(tmpdir, "temp.o")

        with open(c_file, "w") as f:
            f.write(
                "#include <math.h>\n#include <string.h>\n#include <stdlib.h>\n#include <stdint.h>\n#include <stdbool.h>\n"
            )
            f.write(c_code)

        try:
            subprocess.run(
                GCC_CMD + [c_file, "-o", o_file], check=True, capture_output=True
            )
        except subprocess.CalledProcessError as e:
            return None, f"Error: {e.stderr.decode()}"

        cmd = [
            GHIDRA_PATH,
            tmpdir,
            "pmet_proj",
            "-import",
            o_file,
            "-postScript",
            GHIDRA_SCRIPT_PATH,
            "-deleteProject",
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        pattern = re.compile(
            r"<<<<START_FUNC:(?P<name>.*?)>>>>(?P<code>.*?)<<<<END_FUNC>>>>", re.DOTALL
        )

        found_functions = []
        for match in pattern.finditer(result.stdout):
            name = match.group("name").strip()
            code = match.group("code").strip()
            found_functions.append((name, code))

        return found_functions, None


def main():
    parser = argparse.ArgumentParser(
        description="Generate PMET dataset from C ground truth JSON."
    )
    parser.add_argument(
        "--input", default="ground_truth_tasks.json", help="Path to input JSON tasks"
    )
    parser.add_argument(
        "--output",
        default="pmet_synthetic_edits.json",
        help="Path to output KE dataset",
    )
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file {args.input} not found.")
        return

    with open(args.input, "r") as f:
        tasks = json.load(f)

    pmet_dataset = []
    print(f"Processing {len(tasks)} tasks from {args.input}...")

    for task in tqdm(tasks, desc="Decompiling synthetic tasks", unit="task"):
        subject = task.get("subject", "unknown")
        gt_code = task["ground_truth"]

        funcs, error = get_ghidra_functions(gt_code)

        if error:
            tqdm.write(f"Error in {subject}: {error}")

        if not funcs:
            tqdm.write(f"Error: No functions found by Ghidra for {subject}")
            continue

        # first function should be primary one
        func_name, ghidra_pseudocode = funcs[0]

        prompt = (
            f"<s>[INST] You are an expert C decompiler.\n"
            f"Refine the following Ghidra pseudocode into valid, compilable C code.\n"
            f"STRICT RESPONSE RULES:\n"
            f"1. Do not write a main function.\n"
            f"2. Keep the exact same function name and arguments.\n"
            f"3. Output ONLY the raw code. Do not use Markdown code blocks (```).\n"
            f"4. Do not output any introductory text or explanations.\n\n"
            f"Pseudocode:\n{ghidra_pseudocode}\n"
            f"[/INST]\n"
        )

        pmet_dataset.append(
            {"subject": subject, "prompt": prompt, "target_new": gt_code}
        )

    with open(args.output, "w") as f:
        json.dump(pmet_dataset, f, indent=2)

    print(f"\nSuccess! Generated {len(pmet_dataset)} edit pairs in {args.output}")


if __name__ == "__main__":
    main()
