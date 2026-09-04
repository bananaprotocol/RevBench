"""
RevBench Gradio Demo App

A demonstration interface for comparing baseline CodeLlama with LoRA-enhanced
decompilation refinement.

Usage:
    uv run python src/demo_app.py
"""

import json
import os

import gradio as gr
import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

# Paths
BASE_MODEL_PATH = "codellama/CodeLlama-7b-Instruct-hf"
LORA_PATH = "models/error_lora_mixed"  # Best model: 28.08% Pass@1
TEST_DATA_PATH = "data/humaneval_c_test.jsonl"

# CONSISTENT SUCCESS: baseline ALWAYS fails, LoRA ALWAYS passes (across 5 runs)
# Shorter examples listed first for quick demo
SUCCESS_TASK_IDS = [47, 73, 72, 85, 40, 54, 87, 139]

# CONSISTENT LIMITATIONS: LoRA compiles but ALWAYS fails tests (across all 5 runs)
# These demonstrate fundamental limitations - information loss during compilation
# Task 38: Simple n*n square - model hallucinates complex algorithm
# Task 120: Product of odd digits - model outputs completely different function
# Task 8: Sum/product of array - model misinterprets pointer arithmetic
# Task 46: Powers of 2 modulo - model outputs palindrome checker instead
FAILURE_TASK_IDS = [38, 120, 8, 46]


class DemoModel:
    """
    Single model with LoRA adapter toggling for memory efficiency.
    Loads the base model once and enables/disables LoRA adapter as needed.
    """

    def __init__(self, base_model_path: str, lora_path: str):
        print("Loading tokenizer...")
        self.tokenizer = AutoTokenizer.from_pretrained(base_model_path)

        print(f"Loading base model: {base_model_path}...")
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True, bnb_4bit_compute_dtype=torch.float16
        )
        self.model = AutoModelForCausalLM.from_pretrained(
            base_model_path,
            device_map="auto",
            quantization_config=quantization_config,
        )

        print(f"Loading LoRA adapter: {lora_path}...")
        self.model = PeftModel.from_pretrained(self.model, lora_path)
        self.model.eval()
        self.lora_enabled = True

    def set_lora(self, enabled: bool):
        """Enable or disable LoRA adapter layers."""
        if enabled and not self.lora_enabled:
            self.model.enable_adapter_layers()
            self.lora_enabled = True
        elif not enabled and self.lora_enabled:
            self.model.disable_adapter_layers()
            self.lora_enabled = False

    def generate(self, ghidra_pseudocode: str, use_lora: bool = True) -> str:
        """Generate refined C code from Ghidra pseudocode."""
        self.set_lora(use_lora)

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

        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=2048,
                temperature=0.2,
                top_p=0.95,
                do_sample=True,
                pad_token_id=self.tokenizer.eos_token_id,
            )

        full_text = self.tokenizer.batch_decode(outputs, skip_special_tokens=True)[0]

        # Extract response after instruction
        if "[/INST]" in full_text:
            full_text = full_text.split("[/INST]")[1]

        # Clean up any markdown or meta-text
        full_text = full_text.replace("```c", "").replace("```", "").strip()
        return full_text

    def compile_and_test(
        self, generated_code: str, test_harness: str
    ) -> tuple[bool, str]:
        """Compile generated code and run test harness."""
        import subprocess
        import tempfile

        headers = (
            "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n"
            "#include <math.h>\n#include <stdbool.h>\n#include <assert.h>\n"
            "#include <stdarg.h>\n"
        )
        ghidra_defs = "typedef unsigned int uint; typedef unsigned char byte; typedef unsigned long ulong;\n"

        full_source = headers + ghidra_defs + generated_code + "\n\n" + test_harness

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".c", delete=False
        ) as tmp_src:
            tmp_src.write(full_source)
            src_path = tmp_src.name

        bin_path = src_path.replace(".c", "")

        try:
            # Compile
            compile_result = subprocess.run(
                ["gcc", "-O2", "-w", src_path, "-o", bin_path, "-lm"],
                capture_output=True,
                text=True,
            )
            if compile_result.returncode != 0:
                return False, f"Compilation Error:\n{compile_result.stderr}"

            # Execute
            run_result = subprocess.run(
                [bin_path],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if run_result.returncode == 0:
                return True, "All assertions passed!"
            else:
                return False, f"Assertion Failed:\n{run_result.stderr}"

        except subprocess.TimeoutExpired:
            return False, "Timeout: execution took too long"
        except Exception as e:
            return False, f"Error: {str(e)}"
        finally:
            if os.path.exists(src_path):
                os.remove(src_path)
            if os.path.exists(bin_path):
                os.remove(bin_path)


def load_examples() -> list[dict]:
    """Load test examples from the dataset."""
    if not os.path.exists(TEST_DATA_PATH):
        return []

    with open(TEST_DATA_PATH) as f:
        examples = [json.loads(line) for line in f]
    return examples


# Global model instance (loaded once at startup)
model: DemoModel | None = None
examples: list[dict] = []


def initialize():
    """Initialize model and examples."""
    global model, examples
    print("Initializing RevBench Demo...")
    model = DemoModel(BASE_MODEL_PATH, LORA_PATH)
    examples = load_examples()
    print(f"Loaded {len(examples)} test examples")


def get_example_choices() -> list[str]:
    """Get dropdown choices for examples, with success and failure categories."""
    if not examples:
        return ["No examples loaded"]
    choices = []
    # Success examples first
    for task_id in SUCCESS_TASK_IDS:
        if task_id < len(examples):
            choices.append(f"Task {task_id}")
    # Then failure examples to show limitations
    for task_id in FAILURE_TASK_IDS:
        if task_id < len(examples):
            choices.append(f"Task {task_id}")
    return choices


def load_example(choice: str) -> tuple[str, str, str]:
    """Load an example into the input fields."""
    if not examples or "No examples" in choice:
        return "", "", ""

    # Extract task ID from "Task X [SUCCESS]" or "Task X [LIMITATION]"
    task_str = choice.split("[")[0].strip()
    idx = int(task_str.replace("Task ", ""))
    ex = examples[idx]
    return (
        ex.get("ghidra_input", ""),
        ex.get("test_harness", ""),
        ex.get("ground_truth", ""),
    )


def generate_baseline(pseudocode: str) -> str:
    """Generate code using baseline (no LoRA)."""
    if model is None:
        return "Error: Model not loaded"
    if not pseudocode.strip():
        return "Please enter Ghidra pseudocode"
    return model.generate(pseudocode, use_lora=False)


def generate_lora(pseudocode: str) -> str:
    """Generate code using LoRA-enhanced model."""
    if model is None:
        return "Error: Model not loaded"
    if not pseudocode.strip():
        return "Please enter Ghidra pseudocode"
    return model.generate(pseudocode, use_lora=True)


def run_test(generated_code: str, test_harness: str) -> str:
    """Compile and test the generated code."""
    if model is None:
        return "Error: Model not loaded"
    if not generated_code.strip():
        return "No generated code to test"
    if not test_harness.strip():
        return "No test harness provided"

    success, msg = model.compile_and_test(generated_code, test_harness)
    status = "PASSED" if success else "FAILED"
    return f"Status: {status}\n\n{msg}"


def create_ui() -> gr.Blocks:
    """Create the Gradio interface."""
    with gr.Blocks(
        title="RevBench Demo",
        # theme=gr.themes.Soft(),
    ) as demo:
        gr.Markdown(
            """
            # RevBench: Decompilation Refinement Demo

            This demo shows how LoRA fine-tuning improves Ghidra pseudocode refinement.
            """
        )

        with gr.Row():
            example_dropdown = gr.Dropdown(
                choices=get_example_choices(),
                label="Load Example",
                value=get_example_choices()[0] if examples else None,
            )
            load_btn = gr.Button("Load Example", variant="secondary")

        with gr.Row():
            with gr.Column(scale=1):
                gr.Markdown("### Input")
                ghidra_input = gr.Code(
                    label="Ghidra Pseudocode",
                    language="c",
                    lines=15,
                )
                test_harness = gr.Code(
                    label="Test Harness (for validation)",
                    language="c",
                    lines=8,
                )
                ground_truth = gr.Code(
                    label="Ground Truth (reference)",
                    language="c",
                    lines=8,
                    interactive=False,
                )

            with gr.Column(scale=1):
                gr.Markdown("### Baseline Output (No LoRA)")
                baseline_output = gr.Code(
                    label="Baseline Generated Code",
                    language="c",
                    lines=15,
                    interactive=False,
                )
                baseline_btn = gr.Button("Generate with Baseline", variant="secondary")

            with gr.Column(scale=1):
                gr.Markdown("### LoRA Output")
                lora_output = gr.Code(
                    label="LoRA Generated Code",
                    language="c",
                    lines=15,
                    interactive=False,
                )
                lora_btn = gr.Button("Generate with LoRA", variant="primary")

        with gr.Row():
            with gr.Column():
                baseline_test_btn = gr.Button("Test Baseline", variant="secondary")
                baseline_test_result = gr.Textbox(
                    label="Baseline Test Result",
                    lines=3,
                    interactive=False,
                )
            with gr.Column():
                lora_test_btn = gr.Button("Test LoRA", variant="primary")
                lora_test_result = gr.Textbox(
                    label="LoRA Test Result",
                    lines=3,
                    interactive=False,
                )

        # Event handlers
        load_btn.click(
            load_example,
            inputs=[example_dropdown],
            outputs=[ghidra_input, test_harness, ground_truth],
        )

        baseline_btn.click(
            generate_baseline,
            inputs=[ghidra_input],
            outputs=[baseline_output],
        )

        lora_btn.click(
            generate_lora,
            inputs=[ghidra_input],
            outputs=[lora_output],
        )

        baseline_test_btn.click(
            run_test,
            inputs=[baseline_output, test_harness],
            outputs=[baseline_test_result],
        )

        lora_test_btn.click(
            run_test,
            inputs=[lora_output, test_harness],
            outputs=[lora_test_result],
        )

    return demo


def main():
    initialize()
    demo = create_ui()
    demo.launch(share=False)


if __name__ == "__main__":
    main()
