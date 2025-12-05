# ruff: noqa: I001
import torch
from unsloth import FastLanguageModel
from datasets import load_dataset
from trl import SFTConfig, SFTTrainer

MAX_SEQ_LENGTH = 2048
DTYPE = None
LOAD_IN_4BIT = True
DATA_FILE = "data/training_data.jsonl"
OUTPUT_DIR = "models/final_lora"
MODEL_ID = "codellama/CodeLlama-7b-Instruct-hf"


def main():
    print(f"Loading {MODEL_ID} with unsloth...")

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=MODEL_ID,
        max_seq_length=MAX_SEQ_LENGTH,
        dtype=DTYPE,
        load_in_4bit=LOAD_IN_4BIT,
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=16,
        target_modules=[
            "q_proj",
            "k_proj",
            "v_proj",
            "o_proj",
            "gate_proj",
            "up_proj",
            "down_proj",
        ],
        lora_alpha=16,
        lora_dropout=0,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=3407,
        use_rslora=False,
        loftq_config=None,
    )

    print(f"Loading dataset from {DATA_FILE}...")
    dataset = load_dataset("json", data_files=DATA_FILE, split="train")
    dataset = dataset.train_test_split(test_size=0.05)

    def formatting_prompts_func(examples):
        inputs = examples["input"]
        outputs = examples["output"]
        texts = []
        for input_text, output_text in zip(inputs, outputs):
            text = (
                f"<s>[INST] You are an expert C decompiler. \n"
                f"Refine the following Ghidra pseudocode into valid, compilable C code.\n"
                f"STRICT RESPONSE RULES:\n"
                f"1. Do not write a main function.\n"
                f"2. Keep the exact same function name and arguments.\n"
                f"3. Output ONLY the raw code. Do not use Markdown code blocks (```).\n"
                f"4. Do not output any introductory text or explanations.\n\n"
                f"Pseudocode:\n"
                f"{input_text}\n"
                f"[/INST]\n"
                f"{output_text}</s>"
            )
            texts.append(text)
        return {"text": texts}

    dataset = dataset.map(formatting_prompts_func, batched=True)

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        dataset_text_field="text",
        max_seq_length=MAX_SEQ_LENGTH,
        dataset_num_proc=1,
        packing=False,
        args=SFTConfig(
            per_device_train_batch_size=2,
            gradient_accumulation_steps=4,
            warmup_steps=10,
            max_steps=1000,
            learning_rate=2e-4,
            logging_steps=1,
            optim="adamw_8bit",
            weight_decay=0.01,
            lr_scheduler_type="linear",
            seed=3407,
            output_dir="models/checkpoints",
            save_strategy="no",
        ),
    )

    trainer_stats = trainer.train()
    print(f"Training Time: {trainer_stats.metrics['train_runtime']} seconds")

    print(f"Saving LoRA adapter to {OUTPUT_DIR}...")
    model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)

    print("Done! You can now run src/eval_pipeline.py using this adapter.")


if __name__ == "__main__":
    main()
