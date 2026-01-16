import argparse
import json
import random
import re
from pathlib import Path
from typing import Callable


class GhidraArtifactInjector:
    # type replacement rules
    TYPE_RULES = [
        # (pattern, replacement, probability)
        (r"\bunsigned int\b", "uint", 0.9),
        (r"\bunsigned long\b", "ulong", 0.9),
        (r"\bunsigned char\b", "byte", 0.8),
        (r"\bsize_t\b", "ulong", 0.7),
        (r"\blong\b", "undefined8", 0.8),
        (r"\bint\b", "undefined4", 0.7),
        (r"\bchar\b", "undefined1", 0.7),
        (r"\bshort\b", "undefined2", 0.6),
    ]

    # variable prefix mappings based on type
    VAR_PREFIXES = {
        "int": "iVar",
        "undefined4": "iVar",
        "long": "lVar",
        "undefined8": "lVar",
        "char": "cVar",
        "undefined1": "cVar",
        "float": "fVar",
        "double": "dVar",
        "unsigned": "uVar",
        "uint": "uVar",
        "ulong": "uVar",
        "void *": "pvVar",
        "char *": "pcVar",
        "int *": "piVar",
    }

    def __init__(self, seed=42):
        random.seed(seed)
        self.var_counter = 0
        self.param_counter = 0
        self.local_counter = 0

    def inject_artifacts(self, clean_code, intensity=0.7):
        self.var_counter = 0
        self.param_counter = 0
        self.local_counter = 0

        result = clean_code

        # rename function parameters first
        result = self._rename_parameters(result, intensity)

        # apply type replacements
        result = self._replace_types(result, intensity)

        # add ghidra-style formatting
        result = self._apply_formatting(result)

        return result

    def _replace_types(self, code, intensity):
        result = code
        for pattern, replacement, base_prob in self.TYPE_RULES:
            if random.random() < base_prob * intensity:
                result = re.sub(pattern, replacement, result)
        return result

    def _rename_parameters(self, code, intensity):
        if random.random() > intensity:
            return code

        # find function signature
        func_match = re.search(r"(\w+\s+\*?\s*)(\w+)\s*\(([^)]*)\)", code, re.MULTILINE)
        if not func_match:
            return code

        params_str = func_match.group(3)
        if not params_str.strip():
            return code

        # parse parameters
        params = []
        for param in params_str.split(","):
            param = param.strip()
            if not param:
                continue
            # extract parameter name
            match = re.search(r"(\w+)(?:\s*\[.*\])?\s*$", param)
            if match:
                params.append(match.group(1))

        # create replacement map
        result = code
        for i, param_name in enumerate(params):
            new_name = f"param_{i + 1}"
            result = re.sub(rf"\b{re.escape(param_name)}\b", new_name, result)

        return result

    def _rename_local_variables(self, code, intensity):
        if random.random() > intensity * 0.5:
            return code

        # find variable declarations
        var_pattern = r"\b(int|long|char|float|double|unsigned|uint|ulong|undefined\d+)\s+(\*?\s*)(\w+)\s*[;=\[]"

        def replace_var(match):
            var_type = match.group(1)
            pointer = match.group(2)
            var_name = match.group(3)

            # skip if already a ghidra-style name
            if re.match(r"(param_|local_|[a-z]Var)", var_name):
                return match.group(0)

            # skip common names that might be function names
            if var_name in ["main", "printf", "scanf", "malloc", "free"]:
                return match.group(0)

            # determine prefix based on type
            prefix = self.VAR_PREFIXES.get(var_type, "uVar")
            if "*" in pointer:
                prefix = "p" + prefix[0] + "Var"

            self.var_counter += 1
            new_name = f"{prefix}{self.var_counter}"

            return match.group(0).replace(var_name, new_name)

        return re.sub(var_pattern, replace_var, code)

    def _apply_formatting(self, code):
        result = code

        # remove some blank lines
        result = re.sub(r"\n\n\n+", "\n\n", result)

        # ghidra often puts opening brace on same line
        # result = re.sub(r'\)\s*\n\s*\{', ') {', result)

        return result


class SemanticErrorInjector:
    def __init__(self, seed=42):
        random.seed(seed)

    def inject_errors(
        self,
        clean_code,
        intensity=0.5,
        error_types=None,
    ):
        if error_types is None:
            error_types = ["loop_bounds", "operators", "initialization", "increment"]

        result = clean_code

        if "loop_bounds" in error_types:
            result = self._inject_loop_bound_errors(result, intensity)

        if "operators" in error_types:
            result = self._inject_operator_errors(result, intensity)

        if "initialization" in error_types:
            result = self._inject_initialization_errors(result, intensity)

        if "increment" in error_types:
            result = self._inject_increment_errors(result, intensity)

        return result

    def _inject_loop_bound_errors(self, code, intensity):
        result = code

        # i < n -> i <= n
        if random.random() < intensity * 0.4:
            result = re.sub(
                r"\b(\w+)\s*<\s*(\w+)\s*;",
                lambda m: f"{m.group(1)} <= {m.group(2)};"
                if random.random() < 0.5
                else m.group(0),
                result,
            )

        # i <= n -> i < n
        if random.random() < intensity * 0.4:
            result = re.sub(
                r"\b(\w+)\s*<=\s*(\w+)\s*;",
                lambda m: f"{m.group(1)} < {m.group(2)};"
                if random.random() < 0.5
                else m.group(0),
                result,
            )

        # i < n - 1 -> i < n
        if random.random() < intensity * 0.3:
            result = re.sub(
                r"\b(\w+)\s*<\s*(\w+)\s*-\s*1\s*;",
                lambda m: f"{m.group(1)} < {m.group(2)};"
                if random.random() < 0.5
                else m.group(0),
                result,
            )

        # i < n -> i < n - 1
        if random.random() < intensity * 0.3:
            result = re.sub(
                r"\b(\w+)\s*<\s*(\w+)\s*;",
                lambda m: f"{m.group(1)} < {m.group(2)} - 1;"
                if random.random() < 0.3
                else m.group(0),
                result,
            )

        # i = 0 -> i = 1
        if random.random() < intensity * 0.2:
            result = re.sub(
                r"for\s*\(\s*(\w+)\s*=\s*0\s*;",
                lambda m: f"for ({m.group(1)} = 1;"
                if random.random() < 0.3
                else m.group(0),
                result,
            )

        return result

    def _inject_operator_errors(self, code, intensity):
        result = code

        # define operator swap pairs
        swaps = [
            (r"([^<>=!])(<)([^<=])", r"\1>\3"),  # < -> >
            (r"([^<>=!])(>)([^>=])", r"\1<\3"),  # > -> <
            (r"([^<>=!])(<=)", r"\1>="),  # <= -> >=
            (r"([^<>=!])(>=)", r"\1<="),  # >= -> <=
            (r"([^=!])(==)", r"\1!="),  # == -> !=
            (r"([^=!])(!=)", r"\1=="),  # != -> ==
        ]

        # apply one random swap with probability based on intensity
        if random.random() < intensity * 0.5:
            pattern, replacement = random.choice(swaps)
            match = re.search(pattern, result)
            if match:
                result = (
                    result[: match.start()]
                    + re.sub(pattern, replacement, result[match.start() : match.end()])
                    + result[match.end() :]
                )

        return result

    def _inject_initialization_errors(self, code, intensity):
        result = code

        # int x = 0; -> int x;
        if random.random() < intensity * 0.4:
            result = re.sub(
                r"\b(int|long|char|float|double|size_t)\s+(\w+)\s*=\s*0\s*;",
                lambda m: f"{m.group(1)} {m.group(2)};"
                if random.random() < 0.4
                else m.group(0),
                result,
            )

        # int count = 0; -> int count = 1;
        if random.random() < intensity * 0.3:
            result = re.sub(
                r"\b(int|long|size_t)\s+(\w+)\s*=\s*0\s*;",
                lambda m: f"{m.group(1)} {m.group(2)} = 1;"
                if random.random() < 0.3
                else m.group(0),
                result,
            )

        # char *p = NULL; -> char *p;
        if random.random() < intensity * 0.3:
            result = re.sub(
                r"\b(\w+)\s*\*\s*(\w+)\s*=\s*NULL\s*;",
                lambda m: f"{m.group(1)} *{m.group(2)};"
                if random.random() < 0.4
                else m.group(0),
                result,
            )

        return result

    def _inject_increment_errors(self, code, intensity):
        result = code

        # arr[i++] -> arr[++i]
        if random.random() < intensity * 0.3:
            result = re.sub(
                r"\[(\w+)\+\+\]",
                lambda m: f"[++{m.group(1)}]" if random.random() < 0.4 else m.group(0),
                result,
            )

        # arr[++i] -> arr[i++]
        if random.random() < intensity * 0.3:
            result = re.sub(
                r"\[\+\+(\w+)\]",
                lambda m: f"[{m.group(1)}++]" if random.random() < 0.4 else m.group(0),
                result,
            )

        # count++ -> ++count
        if random.random() < intensity * 0.2:
            result = re.sub(
                r"(\s)(\w+)\+\+\s*;",
                lambda m: f"{m.group(1)}++{m.group(2)};"
                if random.random() < 0.3
                else m.group(0),
                result,
            )

        return result


class CombinedInjector:
    def __init__(self, seed=42):
        self.ghidra_injector = GhidraArtifactInjector(seed=seed)
        self.semantic_injector = SemanticErrorInjector(seed=seed)

    def inject(
        self,
        clean_code,
        ghidra_intensity=0.7,
        semantic_intensity=0.5,
        include_ghidra=True,
        include_semantic=True,
        semantic_error_types=None,
    ):
        result = clean_code

        if include_semantic:
            result = self.semantic_injector.inject_errors(
                result,
                intensity=semantic_intensity,
                error_types=semantic_error_types,
            )

        if include_ghidra:
            result = self.ghidra_injector.inject_artifacts(
                result, intensity=ghidra_intensity
            )

        return result


def create_synthetic_dataset(
    input_path,
    output_path,
    intensity=0.7,
    sample_ratio=1.0,
    seed=42,
    include_ghidra=True,
    include_semantic=False,
    semantic_intensity=0.5,
    semantic_types=None,
):
    random.seed(seed)
    injector = CombinedInjector(seed=seed)

    samples = []
    with open(input_path, "r") as f:
        for line in f:
            if line.strip():
                samples.append(json.loads(line))

    print(f"Loaded {len(samples)} samples from {input_path}")

    if sample_ratio < 1.0:
        n_samples = int(len(samples) * sample_ratio)
        samples = random.sample(samples, n_samples)
        print(f"Sampled {len(samples)} samples ({sample_ratio:.0%})")

    print(f"\nInjection configuration:")
    print(
        f"  Ghidra artifacts: {'enabled' if include_ghidra else 'disabled'} (intensity={intensity})"
    )
    print(
        f"  Semantic errors: {'enabled' if include_semantic else 'disabled'} (intensity={semantic_intensity})"
    )
    if include_semantic:
        types_str = ", ".join(semantic_types) if semantic_types else "all"
        print(f"  Semantic types: {types_str}")

    synthetic_samples = []
    for sample in samples:
        clean_code = sample["output"]  # ground truth

        corrupted_code = injector.inject(
            clean_code,
            ghidra_intensity=intensity,
            semantic_intensity=semantic_intensity,
            include_ghidra=include_ghidra,
            include_semantic=include_semantic,
            semantic_error_types=semantic_types,
        )

        synthetic_samples.append(
            {
                "input": corrupted_code,
                "output": clean_code,
            }
        )

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        for sample in synthetic_samples:
            f.write(json.dumps(sample) + "\n")

    print(f"\nCreated {len(synthetic_samples)} synthetic samples")
    print(f"Output written to: {output_path}")

    if synthetic_samples:
        print("\n" + "=" * 50)
        print("EXAMPLE TRANSFORMATION")
        print("=" * 50)
        ex = synthetic_samples[0]
        print("CORRUPTED (synthetic input):")
        print(ex["input"][:500])
        print("\nCLEAN (ground truth):")
        print(ex["output"][:500])


def combine_datasets(
    real_failures_path,
    synthetic_path,
    output_path,
    real_weight=2.0,
):
    combined = []

    if Path(real_failures_path).exists():
        with open(real_failures_path, "r") as f:
            real_samples = [json.loads(line) for line in f if line.strip()]
        combined.extend(real_samples * int(real_weight))
        print(f"Loaded {len(real_samples)} real failures (weighted {real_weight}x)")

    with open(synthetic_path, "r") as f:
        synthetic_samples = [json.loads(line) for line in f if line.strip()]
    combined.extend(synthetic_samples)
    print(f"Loaded {len(synthetic_samples)} synthetic samples")

    random.shuffle(combined)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for sample in combined:
            f.write(json.dumps(sample) + "\n")

    print(f"\nCombined dataset: {len(combined)} samples")
    print(f"Output written to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Create synthetic training data by injecting Ghidra artifacts."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    inject_parser = subparsers.add_parser(
        "inject", help="Create synthetic dataset from clean code"
    )
    inject_parser.add_argument(
        "--input",
        default="data/training_data.jsonl",
        help="Input training data with clean 'output' field",
    )
    inject_parser.add_argument(
        "--output",
        default="data/synthetic/injected.jsonl",
        help="Output path for synthetic dataset",
    )
    inject_parser.add_argument(
        "--intensity",
        type=float,
        default=0.7,
        help="Ghidra artifact intensity 0.0-1.0 (default: 0.7)",
    )
    inject_parser.add_argument(
        "--sample-ratio",
        type=float,
        default=1.0,
        help="Fraction of samples to process (default: 1.0)",
    )
    inject_parser.add_argument("--seed", type=int, default=42, help="Random seed")

    inject_parser.add_argument(
        "--no-ghidra",
        action="store_true",
        help="Disable Ghidra-style artifact injection",
    )

    inject_parser.add_argument(
        "--semantic",
        action="store_true",
        help="Enable semantic error injection (loop bounds, operators, etc.)",
    )
    inject_parser.add_argument(
        "--semantic-intensity",
        type=float,
        default=0.5,
        help="Semantic error intensity 0.0-1.0 (default: 0.5)",
    )
    inject_parser.add_argument(
        "--semantic-types",
        nargs="+",
        choices=["loop_bounds", "operators", "initialization", "increment"],
        help="Specific semantic error types to inject (default: all)",
    )

    combine_parser = subparsers.add_parser(
        "combine", help="Combine real failures with synthetic data"
    )
    combine_parser.add_argument(
        "--real-failures",
        default="data/failures/training_compilation_errors.jsonl",
        help="Path to real failure samples",
    )
    combine_parser.add_argument(
        "--synthetic",
        required=True,
        help="Path to synthetic samples",
    )
    combine_parser.add_argument(
        "--output",
        default="data/combined_training.jsonl",
        help="Output path for combined dataset",
    )
    combine_parser.add_argument(
        "--real-weight",
        type=float,
        default=2.0,
        help="Weight for real failures (default: 2.0)",
    )

    args = parser.parse_args()

    if args.command == "inject":
        create_synthetic_dataset(
            input_path=args.input,
            output_path=args.output,
            intensity=args.intensity,
            sample_ratio=args.sample_ratio,
            seed=args.seed,
            include_ghidra=not args.no_ghidra,
            include_semantic=args.semantic,
            semantic_intensity=args.semantic_intensity,
            semantic_types=args.semantic_types,
        )
    elif args.command == "combine":
        combine_datasets(
            real_failures_path=args.real_failures,
            synthetic_path=args.synthetic,
            output_path=args.output,
            real_weight=args.real_weight,
        )


if __name__ == "__main__":
    main()
