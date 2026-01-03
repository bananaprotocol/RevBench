import matplotlib.pyplot as plt
import numpy as np
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer


class CausalTracer:
    def __init__(self, model_name):
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_name, dtype=torch.float16, device_map="auto"
        )
        self.model.eval()

    def get_logits_and_states(self, input_ids):
        with torch.no_grad():
            outputs = self.model(input_ids, output_hidden_states=True)
        return outputs.logits, outputs.hidden_states

    def trace(self, prompt, target_str, subject_range, noise_std=0.1):
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.model.device)
        input_ids = inputs.input_ids

        clean_logits, clean_states = self.get_logits_and_states(input_ids)

        if target_str is None:
            target_id = torch.argmax(clean_logits[0, -1]).item()
        else:
            target_id = self.tokenizer.encode(target_str, add_special_tokens=False)[0]

        clean_prob = torch.softmax(clean_logits[0, -1], dim=-1)[target_id].item()

        def add_noise(module, input, output):
            noise = (
                torch.randn_like(output[:, subject_range[0] : subject_range[1]])
                * noise_std
            )
            output[:, subject_range[0] : subject_range[1]] += noise
            return output

        handle = self.model.model.embed_tokens.register_forward_hook(add_noise)
        corrupted_logits, _ = self.get_logits_and_states(input_ids)
        corrupted_prob = torch.softmax(corrupted_logits[0, -1], dim=-1)[
            target_id
        ].item()
        handle.remove()

        print(f"Target token: {repr(self.tokenizer.decode([target_id]))}")
        print(f"Clean prob: {clean_prob:.6f}")
        print(f"Corrupted prob: {corrupted_prob:.6f}")

        probs = torch.softmax(clean_logits[0, -1], dim=-1)
        top_probs, top_ids = torch.topk(probs, 10)
        print("\nTop 10 predictions:")
        for i, (p, tid) in enumerate(zip(top_probs, top_ids)):
            token = self.tokenizer.decode([tid])
            print(f"  {i + 1}. {repr(token)}: {p.item():.4f}")
        print()

        num_layers = self.model.config.num_hidden_layers
        results = np.zeros(num_layers)

        for layer_idx in range(num_layers):
            clean_state = clean_states[layer_idx + 1].clone()

            def restore_layer(module, input, output, clean=clean_state):
                clean_on_device = clean.to(
                    output.device if not isinstance(output, tuple) else output[0].device
                )
                if isinstance(output, tuple):
                    return (clean_on_device,) + output[1:]
                return clean_on_device

            h_noise = self.model.model.embed_tokens.register_forward_hook(add_noise)
            h_restore = self.model.model.layers[layer_idx].register_forward_hook(
                restore_layer
            )

            restored_logits, _ = self.get_logits_and_states(input_ids)
            results[layer_idx] = torch.softmax(restored_logits[0, -1], dim=-1)[
                target_id
            ].item()

            h_noise.remove()
            h_restore.remove()

            print(f"Layer {layer_idx} restored. Prob: {results[layer_idx]:.4f}")

        return results, clean_prob, corrupted_prob

    def plot(self, results, clean_prob, corrupted_prob):
        plt.figure(figsize=(10, 6))
        plt.plot(range(len(results)), results, marker="o", label="Restored Probability")
        plt.axhline(y=clean_prob, color="g", linestyle="--", label="Clean Prob")
        plt.axhline(y=corrupted_prob, color="r", linestyle="--", label="Corrupted Prob")
        plt.xlabel("Layer Index")
        plt.ylabel("Probability of Target Token")
        plt.title("Causal Trace: Impact of Layer Restoration")
        plt.legend()
        plt.grid(True)
        plt.show()


tracer = CausalTracer("codellama/CodeLlama-7b-Instruct-hf")

prompt = "<s>[INST] You are an expert C decompiler.\nRefine the following Ghidra pseudocode into valid, compilable C code.\nSTRICT RESPONSE RULES:\n1. Do not write a main function.\n2. Keep the exact same function name and arguments.\n3. Output ONLY the raw code. Do not use Markdown code blocks (```).\n4. Do not output any introductory text or explanations.\n\nPseudocode:\nundefined1  [16] func0(int *param_1,int param_2,int param_3)\n\n{\n  int *piVar1;\n  \n  if (0 < param_2) {\n    piVar1 = param_1 + param_2;\n    do {\n      if (param_3 <= *param_1) {\n        return ZEXT816(0);\n      }\n      param_1 = param_1 + 1;\n    } while (piVar1 != param_1);\n  }\n  return ZEXT816(1);\n}\n[/INST]\n"
target = None

results, clean, corrupted = tracer.trace(prompt, target, subject_range=(8, 12))
tracer.plot(results, clean, corrupted)
