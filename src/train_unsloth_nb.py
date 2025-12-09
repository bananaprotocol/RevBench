import marimo

__generated_with = "0.18.2"
app = marimo.App()


@app.cell
def _(mo):
    mo.md(r"""
    import os, re
    if "COLAB_" not in "\".join(os.environ.keys()):
        !pip install unsloth
    else:
        # Do this only in Colab notebooks! Otherwise use pip install unsloth
        import torch; v = re.match(r"[0-9]{1,}\.[0-9]{1,}", str(torch.__version__)).group(0)
        xformers = "xformers==" + ("0.0.33.post1" if v=="2.9" else "0.0.32.post2" if v=="2.8" else "0.0.29.post3")
        !pip install --no-deps bitsandbytes accelerate {xformers} peft trl triton cut_cross_entropy unsloth_zoo
        !pip install sentencepiece protobuf "datasets==4.3.0" "huggingface_hub>=0.34.0" hf_transfer
        !pip install --no-deps unsloth
    !pip install transformers==4.56.2
    !pip install --no-deps trl==0.22.2
    """)
    return


@app.cell
def _():
    import torch
    from unsloth import FastLanguageModel

    MAX_SEQ_LENGTH = 2048
    DTYPE = None
    LOAD_IN_4BIT = True
    DATA_FILE = "data/training_data.jsonl"
    OUTPUT_DIR = "final_lora"
    MODEL_ID = "codellama/CodeLlama-7b-Instruct-hf"

    print(f"Loading {MODEL_ID} with unsloth...")

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=MODEL_ID,
        max_seq_length=MAX_SEQ_LENGTH,
        dtype=DTYPE,
        load_in_4bit=LOAD_IN_4BIT,
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=32,
        target_modules=[
            "q_proj",
            "k_proj",
            "v_proj",
            "o_proj",
            "gate_proj",
            "up_proj",
            "down_proj",
        ],
        lora_alpha=64,
        lora_dropout=0,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=3407,
        use_rslora=False,
        loftq_config=None,
    )
    return DATA_FILE, MAX_SEQ_LENGTH, OUTPUT_DIR, model, tokenizer


@app.cell
def _(DATA_FILE):
    print(f"Loading dataset from {DATA_FILE}...")

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

    from datasets import load_dataset
    dataset = load_dataset("json", data_files=DATA_FILE, split="train")
    dataset = dataset.train_test_split(test_size=0.05)
    dataset = dataset.map(formatting_prompts_func, batched=True)
    return (dataset,)


@app.cell
def _(MAX_SEQ_LENGTH, dataset, model, tokenizer):
    from trl import SFTConfig, SFTTrainer
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        dataset_text_field="text",
        max_seq_length=MAX_SEQ_LENGTH,
        packing=False,
        args=SFTConfig(
            per_device_train_batch_size=2,
            gradient_accumulation_steps=4,
            warmup_ratio=0.05,
            num_train_epochs=3,
            learning_rate=2e-4,
            logging_steps=1,
            optim="adamw_8bit",
            weight_decay=0.001,
            lr_scheduler_type="linear",
            seed=3407,
            output_dir="outputs",
            report_to="none"
        ),
    )
    return (trainer,)


@app.cell
def _(trainer):
    trainer_stats = trainer.train()
    return


@app.cell
def _(OUTPUT_DIR, model, tokenizer):
    print(f"Saving LoRA adapter to {OUTPUT_DIR}...")
    model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)
    return


@app.cell
def _():
    return


@app.cell
def _():
    import marimo as mo
    return (mo,)


if __name__ == "__main__":
    app.run()
