import torch
from datasets import load_dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from trl import SFTConfig, SFTTrainer

MAX_SEQ_LENGTH = 2048
DTYPE = None
LOAD_IN_4BIT = True
DATA_FILE = "data/training_data.jsonl"
OUTPUT_DIR = "models/final_lora"
MODEL_ID = "codellama/CodeLlama-7b-Instruct-hf"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=LOAD_IN_4BIT,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
    bnb_4bit_compute_dtype=torch.float16,
)


def main():
    print(f"Loading {MODEL_ID} with transformers...")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    # tokenizer.pad_token = tokenizer.eos_token
    # tokenizer.padding_side = "right"

    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID, quantization_config=bnb_config, device_map="auto"
    )

    model = prepare_model_for_kbit_training(model)

    peft_config = LoraConfig(
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
        task_type="CAUSAL_LM",
    )

    model = get_peft_model(model, peft_config)
    model.print_trainable_parameters()

    print(f"Loading dataset from {DATA_FILE}...")
    dataset = load_dataset("json", data_files=DATA_FILE, split="train")
    dataset = dataset.train_test_split(test_size=0.05)

    def formatting_prompts_func(examples):
        inputs = examples["input"]
        outputs = examples["output"]
        texts = []
        for input_text, output_text in zip(inputs, outputs):
            text = (
                f"<s>[INST] You are an expert C decompiler.\n"
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

    print("Starting training...")

    trainer = SFTTrainer(
        model=model,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        peft_config=peft_config,
        processing_class=tokenizer,
        args=SFTConfig(
            per_device_train_batch_size=2,
            gradient_accumulation_steps=8,
            dataset_text_field="text",
            max_length=MAX_SEQ_LENGTH,
            gradient_checkpointing=True,
            gradient_checkpointing_kwargs={"use_reentrant": False},
            packing=False,
            warmup_steps=30,
            num_train_epochs=1,
            learning_rate=2e-4,
            fp16=True,
            logging_steps=1,
            optim="paged_adamw_8bit",
            weight_decay=0.01,
            output_dir="models/checkpoints",
            eval_strategy="epoch",
            save_strategy="steps",
            save_steps=50,
            report_to="none",
        ),
    )

    trainer.train(resume_from_checkpoint=True)
    # trainer.train()

    print(f"Saving LoRA adapter to {OUTPUT_DIR}...")
    trainer.model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)

    print("Done! You can now run src/eval_pipeline.py using this adapter.")


if __name__ == "__main__":
    main()
