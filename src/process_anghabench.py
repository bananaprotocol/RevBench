import concurrent.futures
import glob
import json
import os
import re
import shutil
import subprocess
import tempfile

from tqdm import tqdm

SOURCE_DIR = "./anghabench_data"
GHIDRA_HEADLESS_PATH = "ghidra-analyzeHeadless"
BIN_DIR = "./temp_binaries"
OUTPUT_JSONL = "training_data.jsonl"
GHIDRA_SCRIPT_PATH = os.path.abspath("ghidra_export.py")

MIN_LINES = 6
MAX_CHARS = 4000
BAD_GHIDRA_STRINGS = [
    "Process: Decompiler",
    "Control Flow graph",
    "Time limit exceeded",
    "Low-level Error",
]


def clean_c_code(code):
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
    code = re.sub(r"//.*", "", code)

    lines = code.splitlines()
    cleaned_lines = []

    for line in lines:
        s_line = line.strip()

        if s_line.startswith("#"):
            continue
        if s_line.startswith("typedef "):
            continue
        if s_line.startswith("extern "):
            continue
        if not s_line:
            continue

        cleaned_lines.append(line)

    return "\n".join(cleaned_lines).strip()


def compile_file(c_file):
    basename = os.path.basename(c_file)
    bin_name = basename.replace(".c", ".o")
    out_path = os.path.join(BIN_DIR, bin_name)

    cmd = ["gcc", "-c", "-O2", "-s", "-w", c_file, "-o", out_path]

    try:
        subprocess.run(
            cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )

        with open(c_file, "r", encoding="utf-8", errors="ignore") as f:
            original_code = f.read()

        return (bin_name, original_code)
    except subprocess.CalledProcessError:
        return None


def is_high_quality_pair(ghidra_code, original_code):
    if not ghidra_code or not original_code:
        return False

    if len(original_code) > MAX_CHARS:
        return False

    if "{" not in original_code or "}" not in original_code:
        return False

    if "__asm__" in original_code or "asm(" in original_code:
        return False

    for err in BAD_GHIDRA_STRINGS:
        if err in ghidra_code:
            return False

    return True


def is_self_contained(clean_code):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".c", delete=False) as tmp:
        content = (
            "#include <stdio.h>\n"
            "#include <stdlib.h>\n"
            "#include <string.h>\n"
            "#include <math.h>\n"
            "#include <stdbool.h>\n"
            "typedef unsigned int uint;\n"
            "typedef unsigned long ulong;\n"
            f"{clean_code}\n"
        )
        tmp.write(content)
        tmp_name = tmp.name

    cmd = ["gcc", "-c", "-O0", "-w", tmp_name, "-o", tmp_name + ".o"]

    try:
        subprocess.run(
            cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        is_valid = True
    except subprocess.CalledProcessError:
        is_valid = False
    finally:
        if os.path.exists(tmp_name):
            os.remove(tmp_name)
        if os.path.exists(tmp_name + ".o"):
            os.remove(tmp_name + ".o")

    return is_valid


def main():
    if os.path.exists(BIN_DIR):
        shutil.rmtree(BIN_DIR)
    os.makedirs(BIN_DIR)

    c_files = glob.glob(os.path.join(SOURCE_DIR, "*.c"))
    print(f"Found {len(c_files)} source files. Starting compilation...")

    source_map = {}

    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
        results = list(tqdm(executor.map(compile_file, c_files), total=len(c_files)))

    valid_binaries = 0
    for res in results:
        if res:
            bin_name, code = res
            source_map[bin_name] = code
            valid_binaries += 1

    print(f"Successfully compiled {valid_binaries} files. Starting decompilation...")

    tmp_proj_dir = os.path.join(os.getcwd(), "temp_ghidra_proj")
    if os.path.exists(tmp_proj_dir):
        shutil.rmtree(tmp_proj_dir)
    os.makedirs(tmp_proj_dir)

    cmd = [
        GHIDRA_HEADLESS_PATH,
        tmp_proj_dir,
        "AnghaBench",
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

    stats = {"saved": 0, "discarded": 0}

    with open(OUTPUT_JSONL, "w", encoding="utf-8") as json_out:
        current_file = None
        current_code = []
        in_block = False

        pbar = tqdm(total=valid_binaries, desc="Decompiling")

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
                    original_c = source_map[current_file]

                    original_clean = clean_c_code(original_c)

                    if is_high_quality_pair(ghidra_pseudocode, original_clean):
                        if is_self_contained(original_clean):
                            entry = {
                                "input": ghidra_pseudocode,
                                "output": original_clean,
                            }
                            json_out.write(json.dumps(entry) + "\n")
                            json_out.flush()
                            stats["saved"] += 1
                        else:
                            stats["discarded"] += 1
                    else:
                        stats["discarded"] += 1

                pbar.update(1)
                pbar.set_postfix(stats)
            elif in_block:
                current_code.append(line)

    process.wait()
    pbar.close()
    shutil.rmtree(BIN_DIR)

    if os.path.exists(tmp_proj_dir):
        shutil.rmtree(tmp_proj_dir)

    print(f"Done! Saved: {stats['saved']}, Discarded: {stats['discarded']}")


if __name__ == "__main__":
    main()
