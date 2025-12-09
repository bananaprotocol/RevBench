import concurrent.futures
import json
import os
import shutil
import subprocess

from tqdm import tqdm

SOURCE_JSONL = "exebench_train_real_compilable_shuffled.jsonl"
GHIDRA_HEADLESS_PATH = "ghidra-analyzeHeadless"
BIN_DIR = "./temp_binaries"
OUTPUT_JSONL = "training_data.jsonl"
GHIDRA_SCRIPT_PATH = os.path.abspath("ghidra_export.py")

MAX_CHARS = 4000


def compile_code(task_data):
    index, code = task_data

    if not code or len(code) > MAX_CHARS:
        return None

    bin_name = f"func_{index}.o"
    out_path = os.path.join(BIN_DIR, bin_name)
    c_path = os.path.join(BIN_DIR, f"func_{index}.c")

    with open(c_path, "w") as f:
        f.write(
            "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <math.h>\n"
        )
        f.write(code)

    cmd = ["gcc", "-c", "-O2", "-w", c_path, "-o", out_path]
    try:
        subprocess.run(
            cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return (bin_name, code)
    except subprocess.CalledProcessError:
        return None
    finally:
        if os.path.exists(c_path):
            os.remove(c_path)


def main():
    if os.path.exists(BIN_DIR):
        shutil.rmtree(BIN_DIR)
    os.makedirs(BIN_DIR)

    print(f"Loading {SOURCE_JSONL}...")
    tasks = []

    try:
        with open(SOURCE_JSONL, "r") as f:
            for i, line in enumerate(f):
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                    if "func_def" in entry["text"]:
                        tasks.append((i, entry["text"]["func_def"]))
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        print(f"ERROR: Could not find {SOURCE_JSONL}")
        return

    print(f"Found {len(tasks)} candidates. Using first 20,000...")
    tasks = tasks[:20000]

    print("Compiling binaries...")
    source_map = {}

    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
        results = list(tqdm(executor.map(compile_code, tasks), total=len(tasks)))

    for res in results:
        if res:
            bin_name, original_code = res
            source_map[bin_name] = original_code

    print(f"Successfully compiled {len(source_map)} files. Starting decompilation...")

    if len(source_map) == 0:
        print("ERROR: No binaries compiled.")
        return

    tmp_proj_dir = os.path.join(os.getcwd(), "temp_ghidra_proj")
    if os.path.exists(tmp_proj_dir):
        shutil.rmtree(tmp_proj_dir)
    os.makedirs(tmp_proj_dir)

    cmd = [
        GHIDRA_HEADLESS_PATH,
        tmp_proj_dir,
        "ExeBench",
        "-import",
        BIN_DIR,
        "-postScript",
        GHIDRA_SCRIPT_PATH,
        "-deleteProject",
        "-recursive",
    ]

    print("Running Ghidra...")

    process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1
    )

    saved = 0

    with open(OUTPUT_JSONL, "w", encoding="utf-8") as json_out:
        current_file = None
        current_code = []
        in_block = False
        pbar = tqdm(desc="Decompiling")

        for line in iter(process.stdout.readline, ""):
            line = line.strip()

            if line.startswith("<<<<START_FILE:"):
                in_block = True
                current_file = line.split(":")[1].replace(">>>>", "")
                current_code = []
            elif line.startswith("<<<<END_FILE>>>>"):
                in_block = False
                ghidra_pseudocode = "\n".join(current_code)

                if current_file in source_map:
                    entry = {
                        "input": ghidra_pseudocode,
                        "output": source_map[current_file],
                    }
                    json_out.write(json.dumps(entry) + "\n")
                    json_out.flush()
                    saved += 1

                pbar.update(1)
            elif in_block:
                current_code.append(line)

    process.wait()
    pbar.close()

    if os.path.exists(BIN_DIR):
        shutil.rmtree(BIN_DIR)
    if os.path.exists(tmp_proj_dir):
        shutil.rmtree(tmp_proj_dir)

    print(f"Done! Saved {saved} pairs to {OUTPUT_JSONL}")


if __name__ == "__main__":
    main()
