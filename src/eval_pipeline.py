import argparse
import json
import os
import re
import subprocess
import tempfile

import torch
from peft import PeftModel
from tqdm import tqdm
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

MODEL_PATH = "codellama/CodeLlama-7b-Instruct-hf"
# LORA_PATH = "models/lora_r64_a64"
TEST_DATA_PATH = "data/humaneval_c_test.jsonl"
RESULTS_FILE = "results/evaluation_log.jsonl"

TIMEOUT_SECONDS = 2
GCC_CMD = ["gcc", "-O2", "-w"]


class RevBench:
    def __init__(self, base_model, lora_path=None):
        print("Loading tokenizer...")
        self.tokenizer = AutoTokenizer.from_pretrained(base_model)

        print(f"Loading model: {base_model}...")
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True, bnb_4bit_compute_dtype=torch.float16
        )
        self.model = AutoModelForCausalLM.from_pretrained(
            base_model,
            device_map="auto",
            quantization_config=quantization_config,
        )

        if lora_path:
            print(f"Loading LoRA adapter: {lora_path}...")
            self.model = PeftModel.from_pretrained(self.model, lora_path)

        self.model.eval()

    def generate_code(self, ghidra_pseudocode):
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

        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.model.device)

        outputs = self.model.generate(
            **inputs,
            max_new_tokens=2048,
            temperature=0.2,
            top_p=0.95,
            do_sample=True,
            pad_token_id=self.tokenizer.eos_token_id,
        )

        full_text = self.tokenizer.batch_decode(outputs, skip_special_tokens=True)[0]

        if "[/INST]" in full_text:
            full_text = full_text.split("[/INST]")[1]

        patterns = [
            r"^Here is the refined.*?code:?",
        ]

        for p in patterns:
            full_text = re.sub(p, "", full_text, flags=re.IGNORECASE | re.MULTILINE)

        full_text = full_text.replace("```c", "").replace("```", "").strip()
        return full_text

    def functional_check(self, generated_func, test_harness_main):
        # add common headers
        headers = "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <math.h>\n#include <stdbool.h>\n#include <assert.h>\n#include <stdarg.h>\n"

        # inject standard ghidra typedefs
        ghidra_defs = "typedef unsigned int uint; typedef unsigned char byte; typedef unsigned long ulong;\n"

        full_source = (
            headers + ghidra_defs + generated_func + "\n\n" + test_harness_main
        )

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".c", delete=False
        ) as tmp_src:
            tmp_src.write(full_source)
            src_path = tmp_src.name

        bin_path = src_path.replace(".c", "")

        try:
            compile_args = GCC_CMD + [src_path, "-o", bin_path, "-lm"]
            subprocess.run(
                compile_args,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
        except subprocess.CalledProcessError as e:
            os.remove(src_path)
            return False, "Compilation Error"

        try:
            subprocess.run(
                [bin_path],
                check=True,
                timeout=TIMEOUT_SECONDS,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            result = (True, "Passed")
        except subprocess.TimeoutExpired:
            result = (False, "Timeout")
        except subprocess.CalledProcessError:
            result = (False, "Runtime Assertion Failed")
        except Exception as e:
            result = (False, f"Error: {str(e)}")
        finally:
            if os.path.exists(src_path):
                os.remove(src_path)
            if os.path.exists(bin_path):
                os.remove(bin_path)

        return result


def main():
    parser = argparse.ArgumentParser(description="Evaluate decompilation model")
    parser.add_argument("--lora", default=None, help="Path to LoRA adapter")
    parser.add_argument("--output", default=RESULTS_FILE, help="Output log file")
    parser.add_argument("--test-data", default=TEST_DATA_PATH, help="Test data path")
    args = parser.parse_args()

    if not os.path.exists(args.test_data):
        print(f"Error: {args.test_data} not found.")
        return

    with open(args.test_data, "r") as f:
        dataset = [json.loads(line) for line in f]

    evaluator = RevBench(MODEL_PATH, args.lora)

    passed_count = 0
    total_count = 0

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)

    with open(args.output, "w") as log_file:
        for entry in tqdm(dataset):
            ghidra_input = entry["ghidra_input"]
            test_harness = entry["test_harness"]

            generated_code = evaluator.generate_code(ghidra_input)

            success, msg = evaluator.functional_check(generated_code, test_harness)

            total_count += 1
            if success:
                passed_count += 1

            log_entry = {
                "id": total_count,
                "status": "PASS" if success else "FAIL",
                "error_msg": msg,
                "generated_code": generated_code,
            }
            log_file.write(json.dumps(log_entry) + "\n")
            log_file.flush()

    accuracy = (passed_count / total_count) * 100 if total_count > 0 else 0
    print("\nEvaluation Complete.")
    print(f"Total: {total_count}")
    print(f"Passed: {passed_count}")
    print(f"Pass@1 Accuracy: {accuracy:.2f}%")


if __name__ == "__main__":
    main()
