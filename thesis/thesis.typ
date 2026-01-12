#set text(size: 12pt)
#set heading(numbering: "1.1")
#show heading: it => {
  if it.level == 1 {
    pagebreak(weak: true)
  }

  v(1em)
  it
  v(0.5em)
}

#align(center)[
  #text(size: 12pt, weight: "bold")[Heidelberg University] \

  #v(1mm)

  Faculty of Mathematics and Computer Science \

  #v(1mm)

  Institute of Computer Science \

  #v(1mm)

  Artificial Intelligence for Programming (AIP) \

  #v(20mm)

  Bachelor's Thesis \

  #v(5mm)

  #text(
    size: 22pt,
    weight: "bold",
  )[Comparison of LoRA and Knowledge Editing for Improving Neural Decompilation]
]

#v(1fr)

#table(
  stroke: none,
  columns: 2,
  [Name:], [Hendrik Lohmar],
  [Matriculation number:], [REDACTED],
  [Supervisor:], [Prof. Dr. Artur Andrzejak],
  [Date of Submission:], [January 16, 2026],
)

#v(20mm)

#pagebreak()

#set page(numbering: "i")
#counter(page).update(1)

#align(center)[
  #set par(justify: false)
  #text(size: 17pt, weight: "bold")[Abstract]\
  #v(1mm)
  _English_ \
  #v(1mm)
  #lorem(200)
]

#pagebreak()

#align(center)[
  #set par(justify: false)
  #text(size: 17pt, weight: "bold")[Abstract]\
  #v(1mm)
  _Deutsch_ \
  #v(1mm)
  #lorem(200)
]

#pagebreak()

#align(center)[
  #set par(justify: false)
  #text(size: 17pt, weight: "bold")[Acknowledgments]\
  #v(1mm)
  The author acknowledges support by the state of Baden-Württemberg through bwHPC.
]

#pagebreak()

#outline()

#set page(
  numbering: "1",
)
#counter(page).update(1)

= Introduction

- reverse engineering is a manual and tedious process
- modern binaries are heavily optimized, stripping variable names, structure, ...
- we investigate LoRA and Knowledge Editing as cheaper alternatives to improve decompilation performance and fix specific decompiler hallucinations

== Motivation and Context

== Problem Statement

== Research Questions

== Contributions

== Thesis Outline

= Background

== Decompilation Fundamentals

Decompilation is the process of translating low-level executable code back into a higher-level programming language representation.
Understanding the fundamentals of this process, and its inherent challenges, is essential for appreciating both the potential and limitations of neural approaches to decompilation.
This section first examines the forward compilation process to understand what information is lost, then discusses traditional decompilation techniques with a focus on Ghidra's approach, and finally outlines the key challenges that motivate this research.

=== The Compilation Process

Before examining decompilation, it is instructive to understand the forward compilation process and the information that is irretrievably lost at each stage.
This loss of information is what makes decompilation fundamentally challenging.
It is not simply the inverse of compilation, but rather an attempt to recover semantics from a lacking representation.

==== Overview of Compilation Stages

The transformation from source code to executable binary occurs through several distinct phases, each with specific responsibilities and each contributing to information loss.

// add figure that shows pipeline

==== Preprocessing

==== Lexical and Syntactic Analysis

==== Intermediate Representation and Optimization

==== Code Generation

==== Assembly and Linking

==== Summary of Information Loss

== Neural Decompilation

Converting binary code back into a high-level language, a process known as decompilation, is necessary for tasks ranging from indentifying vulnerabilities to maintaining legacy systems.
However, because compilation erases fine-grained details like loop structures and variable names, reconstructing the original source code is complex.
Prominent tools like Ghidra and IDA Pro use strict, rule-based algorithms, to analyze the control flow graphs of binary code to reconstruct logic.
This can generate high-level pseudo-code which is logically correct, but often difficult for humans to read and often can't easily be re-compiled.
Neural Decompilation is the application of neural networks to decompilation, where it is treated as a Machine Translation problem.

- what is it?
- how do standard decompilers work?
- why do they only create pseudocode?

== Parameter-Efficient Fine-Tuning

- how does LoRA work?
- what are the rank decomposition matrices A and B?
- why does it save memory?

=== Full Fine-Tuning vs. Efficient Adaptation

=== Low-Rank Adaptation (LoRA)

Low-Rank Adaptation, or LoRA, is a parameter-efficient fine-tuning method, which freezes the pretrained model weights and injects trainable rank decomposition matrices into each layer of the Transformer, reducing the number of trainable parameters by a large amount. @huLoRALowRankAdaptation2021
As larger models are pretrained, full-finetuning, where all model parameters are updated, becomes a big challenge, as it requires huge amounts of GPU memory.
The authors of the paper hypothesize that the change in weights during model adaptation has a low instrinstic rank, i.e. a very low rank suffices for making the model learn a new downstream task, even if the full rank of the parameters is much larger.

=== Variants and Extensions

- QLoRA

== Transformers and LLMs for Code

- how do transformers work?
- how does attention work?

== Knowledge Editing

While LLMs are able to recall a large amount of common facts, even very large models can lack specialized knowledge or recall obsolete information if not updated frequently.
The ability to efficiently maintain and customize new information is thus desirable in a lot of domains.
Retraining large models can be computationally inaccessible, which is why methods which can update knowledge directly are desired.
Several Knowledge Editing methods have been proposed to insert new memories into specific model parameters.
These include constrained fine-tuning, hypernetwork knowledge editing, and rank-one model editing.

- how is knowledge specified?
- what methods exist and how do they differ?
- which methods are suitable for code LLMs?

== Evaluation Metrics for Decompilation <eval-metrics>

- why this metric? why is e.g. BLEU bad? are there other metrics?
- functional equivalence: unit tests, symbolic execution, fuzzing

= Related Work

== Neural Decompilation Systems

== Research Gap and Positioning

= Methodology

== Overview

This thesis investigates two fundamentally different paradigms for adapting pre-trained Large Language Models to the task of neural decompilation: Low-Rank Adaptation (LoRA) and Knowledge Editing (KE).
These approaches represent contrasting philosophies in model adaptation and are hypothesized to offer complementary strengths when addressing the challenges inherent to decompilation.

The decompilation task is formulated as a translation problem where the input consists of Ghidra-generated pseudocode rather than raw binary or assembly.
This intermediate representation retains essential low-level semantics while providing a more structured input format that is better suited for LLM processing.
The objective is to transform this pseudocode into clean, idiomatic, and functionally equivalent high-level C code.

*Low-Rank Adaptation* constitutes a global adaptation strategy.
By introducing low-rank trainable matrices into the Transformer architecture, LoRA enables the model to learn broad patterns from a corpus of decompilation examples.
This approach is well-suited for capturing general improvements such as more idiomatic code generation, better recognition of common programming constructs, and improved handling of compiler-introduced patterns.
This adaptation affects the model's behavior across a wide range of inputs, making it appropriate for enhancing overall decompilation quality.

*Knowledge Editing*, in contrast, represents a surgical intervention approach.
However preliminary investigation revealed that traditional KE techniques such as ROME, designed primarily for factual knowledge correction in natural language domains, are not well-suited to the decompilation task, which involves complex structural transformations rather than discrete factual assertions.
Consequently, this work explores *error-specific LoRAs* as an alternative targeted adaptation strategy.
Rather than editing model weights directly, error-specific LoRAs are trained on curated datasets focusing on particular recurring error patterns (e.g., loop bound errors, operator errors, or initialization errors).
This approach maintains the surgical, targeted philosophy of knowledge editing while remaining compatible with the architectural and task characteristics of neural decompilation.

The central hypothesis of this work proposes that these two approaches, general-purpose LoRAs and error-specific LoRAs, are not merely alternatives but rather address different aspects of the decompilation problem.
General LoRA is expected to yield consistent improvements in overall code quality and readability, while error-specific LoRAs are hypothesized to excel at eliminating particular, reproducible error categories that persist even after broad fine-tuning.
Furthermore, a hybrid approach combining both techniques may leverage their respective strengths to achieve superior results compared to either method in isolation.

The experimental design follows a structured comparative methodology.
First, a baseline is established by evaluating a pre-trained LLM on a curated dataset of binary functions with known source code.
Subsequently, general LoRA fine-tuning is applied to create a globally adapted model, and error-specific LoRAs are trained and applied to create a targeted-correction variants.
All adapted models are evaluated against the baseline using identical metrics (compilability, and functional equivalence), enabling direct comparison.
// not sure if enough time left: Additional analyses examine scalability, interference effects, and robustness to input variations, culminating in an exploration of hybrid strategies that combine both adaptation techniques.

== Data Pipeline

The experimental infrastructure relies on two complementary datasets serving distinct purposes in the evaluation pipeline.
*ExeBench* serves as the primary training corpus, providing a diverse collection of C functions suitable for fine-tuning the models.
*HumanEval-C* functions as the evaluation dataset, offering 151 programming problems with associated test harnesses that enable rigorous verification of functional equivalence beyond mere syntactic similarity.

The data preparation process begins with *compilation*, where source C code is compiled into binary executables using GCC with the `-O2` optimization level.
This optimization setting represents a realistic balance between performance and debuggability commonly used in production software, producing binaries with substantial compiler transformations, including loop optimizations, function inlining, and register allocation, while avoiding the most aggressive optimizations that can make decompilation exceptionally challenging.

Following compilation, *decompilation* is performed using Ghidra in headless mode, enabling automated batch processing of binaries.
Ghidra's decompiler analyzes each compiled binary and generates pseudocode that serves as the input representation for the neural models.
This pseudocode retains low-level semantics such as explicit type casts, pointer arithmetic, and architecture-specific idioms while providing more structure than raw assembly.

To ensure dataset quality, a *filtering and quality assurance* process is applied to the generated pairs of Ghidra pseudocode and original source code.
Filtering criteria include line length constraints to remove excessively long or short functions that may represent edge cases, length ratio checks between pseudocode and source code to identify potential decompilation failures or anomalies, and validation to ensure both input and output constitute valid, complete function pairs.
These filters remove malformed samples that could introduce noise during training or evaluation.

The resulting dataset comprises approximately *4,000 training samples* from ExeBench and *151 test samples* from HumanEval-C, each accompanied by test harnesses that enable automated verification of functional correctness through execution-based testing.

== LoRA Fine-Tuning Approach

=== Base Model Selection

The foundation for LoRA fine-tuning is CodeLlama 7B Instruct, a 7-billion parameter large language model specifically optimized for code-related tasks.
CodeLlama represents a family of models derived from Llama 2, further trained on code-heavy corpora to develop stronger capabilities in code understanding, generation, and transformation tasks.
The Instruct variant has been additionally fine-tuned to follow instructions, making it particularly well-suited for task-oriented applications where the model must respond to structured prompts.

Several factors motivated this selection.
First, the 7B parameter scale strikes a practical balance between model capacity and computational feasibility, enabling relatively efficient fine-tuning and inference while maintaining sufficient representational power for complex code transformations.
Second, CodeLlama's architecture and training specifically target programming language understanding, providing a stronger starting point than general-purpose language models.
Third, the Instruct variant's instruction-following capabilities align well with the decompilation task formulation, where the model receives explicit directives to transform Ghidra pseudocode into clean C code.
Finally the model's open availability and extensive community adoption provide valuable resources for implementation and comparison.

=== Training Configuration

The training infrastructure employs *Unsloth*, an optimized framework for efficient LLM fine-tuning that provides significant speedups over standard implementations.
The base model is loaded in 4-bit precision, reducing memory requirements while maintaining model quality.
Unsloth's custom gradient checkpointing implementation further reduces memory overhead compared to standard PyTorch gradient checkpointing.

The LoRA configuration targets all linear projection layers within the Transformer architecture.
For the attention mechanism, this includes the query, key, value, and output projections (`q_proj`, `k_proj`, `v_proj`, `o_proj`).
For the feed-forward network, the gated MLP projections are targeted (`gate_proj`, `up_proj`, `down_proj`).
This comprehensive targeting ensures that adaptations can occur throughout the model's representational pipeline.
Unlike some configurations that apply dropout to LoRA layers, dropout is set to zero for improved training stability with small datasets.

The training hyperparameters are configured as follows.
A per-device batch size of 2 is used with gradient accumulation over 8 steps, yielding an effective batch size of 16.
The maximum sequence length is set to 2048 tokens, sufficient to accommodate most function pairs in the dataset.
Training proceeds for 3 epochs with a learning rate of $2 times 10^(-4)$ and a linear learning rate scheduler with a warmup ratio of 0.05.
The optimizer is AdamW with 8-bit states.
A weight decay of 0.01 provides light regularization.
A fixed random seed of 3407 ensures reproducibility across training runs.

Training was conducted using cloud and high-performance computing resources.
The majority of LoRA training runs utilized Google Colab instances with a single NVIDIA A100 GPU (40GB VRAM).
Selected experiments were conducted on the bwHPC cluster provided by the state of Baden-Württemberg, using nodes with four NVIDIA H100 GPUs.

#figure(
  table(
    columns: (auto, auto),
    inset: 10pt,
    table.header([*Parameter*], [*Value*]),
    [Framework], [Unsloth],
    [Quantization], [4-bit],
    [LoRA targets], [All attention + MLP projections],
    [LoRA dropout], [0],
    [Effective batch size], [16 (2 #sym.times 8 accumulation)],
    [Max sequence length], [2048 tokens],
    [Epochs], [3],
    [Learning rate], [$2 times 10^(-4)$],
    [LR scheduler], [Linear],
    [Optimizer], [AdamW 8-bit],
    [Weight decay], [0.001],
    [Warmup ratio], [0.05],
    [Random seed], [3407],
  ),
  caption: [LoRA training configuration using Unsloth],
) <training-configuration>

*Prompt template design* plays a crucial role in eliciting appropriate model behavior.
The prompt structure leverages CodeLlama's instruction format, using the `[INST]` tags that the model was trained to recognize. The template is designed to address common failure modes observed during preliminary experiments:

````
<s>[INST] You are an expert C decompiler.
Refine the following Ghidra pseudocode into valid, compilable C code.
STRICT RESPONSE RULES:
1. Do not write a main function.
2. Keep the exact same function name and arguments.
3. Output ONLY the raw code. Do not use Markdown code blocks (```).
4. Do not output any introductory text or explanations.

Pseudocode:
{ghidra_pseudocode}
[/INST]
````

=== Hyperparameter Search

To identify optimal LoRA hyperparameters, a grid search was conducted over rank values ranging from 8 to 128, with alpha values set equal to or double the rank.
Each configuration was evaluated across 5 independent runs on the HumanEval-C test set (n=151) to account for sampling variability.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    inset: 10pt,
    align: (left, center, center, center),
    table.header(
      [*Config*], [*Rank / Alpha*], [*Pass\@1 (%)*], [*Compile (%)*]
    ),
    [Baseline],
    [---],
    [15.50 #sym.plus.minus 1.08],
    [18.94 #sym.plus.minus 0.53],

    [LoRA], [8 / 8], [20.93 #sym.plus.minus 0.79], [82.38 #sym.plus.minus 0.32],

    [LoRA],
    [16 / 16],
    [21.46 #sym.plus.minus 2.03],
    [82.91 #sym.plus.minus 1.59],

    [LoRA],
    [32 / 32],
    [23.44 #sym.plus.minus 1.60],
    [84.77 #sym.plus.minus 0.59],

    [LoRA],
    [32 / 64],
    [23.71 #sym.plus.minus 1.84],
    [83.97 #sym.plus.minus 0.77],

    [LoRA],
    [64 / 64],
    [*23.95* #sym.plus.minus 1.35],
    [84.33 #sym.plus.minus 1.19],

    [LoRA],
    [64 / 128],
    [22.78 #sym.plus.minus 0.90],
    [*85.56* #sym.plus.minus 1.59],

    [LoRA],
    [128 / 128],
    [23.18 #sym.plus.minus 2.09],
    [84.50 #sym.plus.minus 0.99],
  ),
  caption: [LoRA hyperparameter search results on HumanEval-C (5 runs per config). Bold indicates best performance.],
) <hyper-params>

The results reveal several patterns.
First, even the smallest LoRA configuration (r=8) dramatically improves compilability from 18.94% to 82.38%, indicating that fine-tuning effectively teaches the model to generate syntactically valid C code rather than pseudocode artifacts.
Second, Pass\@1 shows diminishing returns beyond rank 32, with configurations from r=32 to r=128 all achieving approximately 23-24%.
Third, increasing alpha relative to rank (e.g., r=32/a=64 vs r=32/a=32) provides marginal benefit. Based on these results, the r=64/a=64 configuration was selected for subsequent experiments as it achieved the highest mean Pass\@1 while maintaining stable performance across runs.

== Knowledge Editing Approach

Knowledge Editing (KE) represents a fundamentally different paradigm from fine-tuning: rather than updating model weights through gradient descent over training examples, KE methods directly modify specific parameters to alter targeted factual associations while preserving other model behaviors.
This section describes the experimental investigation of ROME (Rank-One Model Editing) for neural decompilation, conducted to evaluate whether surgical weight modifications can address systematic decompilation errors.

=== Formulating Decompilation as Knowledge Editing

The hypothesis underlying this experiment was that certain Ghidra pseudocode artifacts could be conceptualized as incorrect factual associations that Knowledge Editing might correct.
Ghidra's decompiler produces type annotations such as `undefined4`, `undefined1`, and `undefined8` which correspond to C types `int`, `char`, and `long` respectively.
If the base LLM fails to consistently translate these artifacts, this failure might stem from incorrect or weak factual associations that ROME could strengthen.

Under this formulation, the decompilation task contains implicit knowledge triplets of the form (subject, relation, object):
- (`undefined4`, "corresponds to C type", `int`)
- (`undefined1`, "corresponds to C type", `char`)
- (`undefined8`, "corresponds to C type", `long`)

Additionally, Ghidra produces context-specific artifacts such as `_LC0` for string literal references and `DAT_XXXXXXXX` for data section addresses, though these lack fixed target values and require context-dependent resolution.

=== Implementation

ROME edits were implemented using the EasyEdit library @wangEasyEditEasytouseKnowledge2023, which provides a standardized interface for various Knowledge Editing methods.
Edit requests were specified as JSON objects containing the subject (Ghidra artifact), relation (type correspondence), and target object (C type).
The editing process modifies a single feed-forward layer in the Transformer, identified through causal tracing as the layer where factual associations are stored.

Four edit requests were created targeting the most common Ghidra type artifacts.
The edited model was then tested on the same decompilation prompts used for baseline evaluation, and the generated outputs were analyzed for artifact removal rates.

=== Fundamental Limitations

The experiment revealed a fundamental mismatch between Knowledge Editing and the decompilation task.
Critically, the base CodeLlama model already possesses the relevant factual knowledge; when directly asked "What C type does undefined4 represent?", the model correctly responds "int".
The decompilation failures therefore do not stem from missing factual associations but from inconsistent application of known facts during code generation.
In testing, none of the four edit requests produced correct factual responses, and artifact removal improved only marginally; with the one removed artifact replaced by an incorrect value.

This distinction is crucial: Knowledge Editing methods are designed to update atomic factual associations (e.g., changing "The Eiffel Tower is located in Paris" to "The Eiffel Tower is located in London").
Neural decompilation, however, requires consistent application of transformation rules across diverse syntactic contexts, context-dependent reasoning about surrounding code, and multi-step inference to reconstruct program semantics.
These capabilities fall outside the scope of what Knowledge Editing can address.

Furthermore, many Ghidra artifacts cannot be formulated as fixed factual mappings.
String literal references like `_LC0` must be resolved based on the surrounding code context; there is no single correct replacement that could be encoded as an edited fact.
The model must reason about each occurrence individually.

Based on these findings, Knowledge Editing was determined to be unsuitable for the neural decompilation task.
The remainder of this thesis therefore focuses on LoRA fine-tuning as the primary adaptation method, with Knowledge Editing serving as a documented negative result that clarifies the nature of the decompilation challenge.

== Error Analysis

To understand the limitations of LoRA fine-tuning and identify opportunities for targeted improvement, a systematic error analysis was conducted on the evaluation results.
This analysis aimed to categorize failure modes and assess which error patterns might be addressable through additional training interventions.

=== Evaluation Framework

The evaluation framework assesses generated code through a three-stage pipeline.
First, *compilation checking* verifies that the generated C code is syntactically valid by attempting compilation with GCC.
Second, *functional equivalence testing* executes the compiled code against a test harness containing assertions that verify input-output behavior matches the ground truth implementation.
Third, *stability assessment* runs each evaluation multiple times (5 runs per configuration) to distinguish consistent failures from stochastic variations in generation.

This multi-run approach revealed three categories of samples: consistently passing (same result across all runs), consistently failing, and flaky samples that pass in some runs but fail in others.
The flaky category is particularly informative, as it indicates samples where the model's output is near the decision boundary; sometimes producing correct code and sometimes not.

=== Failure Categorization

Consistent failures were further categorized by failure type: compilation errors (syntactically invalid code), assertion failures (compiles but produces incorrect output), and timeouts (execution exceeds time limit).
Assertion failures are of particular interest as they represent cases where the model generates plausible but semantically incorrect code; a more subtle failure mode than outright syntax errors.

=== Semantic Error Taxonomy

Manual analysis of assertion failures revealed six distinct error patterns:

- *Decompiler information loss*: Ghidra produces severely degraded output (e.g., stub functions) that lacks essential logic. These failures are unrecoverable regardless of model capability.

- *Algorithm re-interpretation*: The model generates a structurally different algorithm that appears plausible given the ambiguous pseudocode but produces incorrect results.

- *Loop bound and index errors*: Incorrect loop termination conditions or array indexing, often manifesting as off-by-one errors (e.g., `i < n` vs. `i <= n`).

- *Comparison operator errors*: Incorrect relational operators that change program semantics (e.g., `<` vs. `>` in sorting comparisons).

- *Variable initialization errors*: Missing initialization or incorrect use of output parameters, such as dereferencing pointers before assignment.

- *String and format handling errors*: Incorrect format specifiers or string operations that produce malformed output.

=== Trainability Assessment

Each error pattern was assessed for potential addressability through synthetic training data.
Patterns involving discrete, systematic transformations (such as loop bound variations and operator substitutions) were identified as potentially trainable.
Patterns requiring semantic reasoning or suffering from fundamental information loss were classified as likely unaddressable through fine-tuning alone.

This taxonomy informed the design of error-specific training data, where synthetic examples were generated by deliberately introducing the identified error patterns into correct code, training the model to recognize and correct these specific failure modes.

== Comparison Strategy

The original research design proposed comparing two adaptation approaches: LoRA for general fine-tuning and Knowledge Editing for targeted corrections.
However, as documented in the previous section, Knowledge Editing proved fundamentally unsuitable for the decompilation task; the model already possesses the relevant factual knowledge but fails to apply it consistently during generation.
This finding itself constitutes a contribution, clarifying that neural decompilation errors stem from reasoning failures rather than knowledge gaps.
Consequently, the experimental evaluation focuses on assessing LoRA's effectiveness against the unadapted baseline, with the Knowledge Editing investigation serving as a documented negative result that illuminates the nature of the decompilation challenge.

= Results

This chapter presents the experimental findings from evaluating LoRA-based fine-tuning for neural decompilation.
All evaluations use the HumanEval-C test set (n=151) with generated code compiled via GCC (`-O2` optimization) and executed against test harnesses with a 2-second timeout.
Code generation employs nucleus sampling (temperature 0.2, top-p 0.95), and each configuration is evaluated across five independent runs to account for sampling variability.

== Baseline Performance

The baseline establishes the capabilities of the pre-trained CodeLlama 7B Instruct model applied to neural decompilation without task-specific adaptation.

#figure(
  table(
    columns: (auto, auto, auto),
    inset: 10pt,
    table.header([*Metric*], [*Mean*], [*Std Dev*]),
    [Pass\@1 (%)], [15.50%], [#sym.plus.minus 1.08%],
    [Compile (%)], [18.94%], [#sym.plus.minus 0.53%],
  ),
  caption: [Baseline model performance on HumanEval-C (n=151, 5 runs)],
) <baseline>

The baseline achieves a Pass\@1 of 15.50% and a compile rate of only 18.94%.
The notably low compile rate reveals that the untuned frequently reproduces Ghidra-specific artifacts, such as `undefined4` type annotations and non-standard syntax, rather than generating valid C code.
This indicates that the primary challenge is not semantic reasoning alone but also syntactic adaptation: the model must learn to translate decompiler idioms into standard C constructs.

== LoRA Fine-Tuning Results

LoRA fine-tuning produces substantial improvements over the baseline.
The hyperparameter search results, detailed in @hyper-params, identified the r=64, a=64 configuration as optimal, achieving 23.95% Pass\@1.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    inset: 10pt,
    align: (left, center, center, center),
    table.header(
      [*Model*], [*Pass\@1 (%)*], [*Compile (%)*], [*#sym.Delta Pass\@1*]
    ),
    [Baseline],
    [15.50 #sym.plus.minus 1.08],
    [18.94 #sym.plus.minus 0.53],
    [---],

    [LoRA (r=64, a=64)],
    [23.95 #sym.plus.minus 1.35],
    [84.33 #sym.plus.minus 1.19],
    [+8.45],
  ),
  caption: [Comparison of baseline and best LoRA configuration],
) <lora-comparison>

The most striking result is the compile rate improvement: from 18.94% to 84.33%, a 4.5#sym.times increase.
This demonstrates that LoRA effectively teaches the model to generate syntactically valid C code, eliminating most Ghidra artifacts that caused compilation failures.

The Pass\@1 improvement from 15.50% to 23.95% represents a 54% relative gain, though the absolute improvement of 8.45 percentage points is more modest.
This asymmetry between compile rate and functional correctness improvements suggests that while LoRA excels at syntactic correction, semantic reasoning, understanding program logic and producing functionally equivalent code, remains challenging.

=== Result Stability

Evaluation across multiple runs reveals variability in model performance due to sampling randomness.
Analysis of per-sample consistency across five evaluation runs identified three categories:

#figure(
  table(
    columns: (auto, auto, auto),
    inset: 10pt,
    table.header([*Category*], [*Count*], [*Percentage*]),
    [Consistently passing], [20], [13.2%],
    [Consistently failing], [99], [65.6%],
    [Flaky (inconsistent)], [32], [21.2%],
  ),
  caption: [Result consistency across 5 evaluation runs (n=151)],
) <consistency>

The 21.2% of samples exhibiting flaky behavior, sometimes passing, sometimes failing, indicates that for a subset of problems, the model operates near the decision boundary.
Minor variations in token sampling can lead to functionally different outputs.
This underscores the importance of multi-run evaluation: single-run metrics would misrepresent true model capability.

== Error Analysis

To understand the limitations of LoRA fine-tuning, the 99 consistently failing samples were analyzed.

#figure(
  table(
    columns: (auto, auto, auto),
    inset: 10pt,
    table.header([*Failure Type*], [*Count*], [*Percentage*]),
    [Assertion failure], [76], [76.8%],
    [Compilation error], [22], [22.2%],
    [Timeout], [1], [1.0%],
  ),
  caption: [Failure type distribution among consistently failing samples],
) <failure-types>

The dominance of assertion failures (76.8%) over compilation errors indicates that the fine-tuned model successfully generates compilable code in most cases, but the generated code does not always preserve the original program's semantics.

=== Semantic Error Patterns

Manual analysis of the assertion failures revealed six distinct error categories:

*Decompiler information loss* (\~10% of failures): Ghidra produces severely degraded output lacking essential logic.
When the input contains only a stub function like `undefined8 func0(void) { return 0; }`, no model can reconstruct the original semantics.
These represent data quality limitations rather than model failures.

*Algorithm re-interpretation* (\~35% of failures): The model generates a semantically different but plausible algorithm.
For instance, an array interspersing task implemented with modulo-based indexing instead of the ground truth's dual-iterator approach.
Both implementations appear reasonable given the ambiguous pseudocode, but only one matches the test harness expectations.

*Loop bound errors* (\~20% of failures): Incorrect termination conditions, often manifesting as off-by-one errors.
Common patterns include `i < n` versus `i <= n` or `i < n - 1` versus `i < n`.

*Comparison operator errors* (\~15% of failures): Incorrect relational operators that alter program semantics, such as using `>` instead of `<` in sorting comparisons.

*Variable initialization errors* (\~10% of failures): Missing initialization of variables, particularly output parameters used before being set.

*String and format handling errors* (\~10% of failures): Incorrect format specifiers or string operations, such as missing space separators in formatted output.

=== Trainability Assessment

The error patterns divide into two categories with different implications for further improvement:

*Potentially addressable* (\~45%): Loop bound errors, operator errors, and initialization errors follow systematic patterns that could be targeted through additional training data or error-specific fine-tuning.

*Fundamental limitations* (\~55%): Decompiler information loss cannot be addressed by any model improvement; the information simply does not exist in the input.
Algorithm re-interpretation errors require semantic understanding beyond pattern matching; when pseudocode admits multiple valid interpretations, the model cannot determine which matches the test harness without additional context.

This distribution suggests that while targeted interventions may yield incremental improvements, substantial gains in functional correctness likely require either improved decompilation input quality or advances in model reasoning capabilities.

== Error-Specific Fine-Tuning Results

Building on the error analysis, additional LoRA variants were trained to evaluate whether targeted training can address the identified failure patterns.

=== Synthetic Error Data Generation

A synthetic error dataset was generated using rule-based transformations.
The script applies systematic corruptions to clean C code, simulating the semantic errors observed in model failures:

- *Loop bound errors*: Off-by-one transformations such as `i < n` #sym.arrow `i <= n` or `i < n - 1` #sym.arrow `i < n`
- *Operator swaps*: Comparison operator inversions such as `<` #sym.arrow `>` or `==` #sym.arrow `!=`
- *Initialization errors*: Removal or corruption of variable initializations

Synthetic training pairs were created from 30% of the original ExeBench training data (approximately 1,200 samples), with each sample transformed from clean code into a corrupted variant paired with its original as the target output.

=== Targeted Error Data

An initial experiment trained a LoRA adapter exclusively on the synthetic error examples, testing whether error correction can be learned in isolation from general decompilation patterns.

// #figure(
//   table(
//     columns: (auto, auto, auto, auto),
//     inset: 10pt,
//     align: (left, center, center, center),
//     table.header(
//       [*Model*], [*Pass\@1 (%)*], [*Compile (%)*], [*#sym.Delta Pass\@1*]
//     ),
//     [Baseline],
//     [15.50 #sym.plus.minus 1.08],
//     [18.94 #sym.plus.minus 0.53],
//     [---],

//     [General LoRA],
//     [23.95 #sym.plus.minus 1.35],
//     [84.33 #sym.plus.minus 1.19],
//     [+8.45],

//     [Targeted LoRA],
//     [20.13 #sym.plus.minus 0.32],
//     [21.06 #sym.plus.minus 0.26],
//     [+4.63],
//   ),
//   caption: [Performance of LoRA trained exclusively on error-targeted data],
// ) <targeted-lora-results>

The targeted LoRA improves Pass\@1 by 4.63 percentage points over baseline, demonstrating that the synthetic error data teaches meaningful correction patterns.
However, the compile rate remains nearly unchanged at 21.06%, far below the general LoRA's 84.33%.

This reveals a critical limitation: training on only 1,200 synthetic examples (even with Ghidra-style artifacts) provides insufficient coverage of the diverse patterns present in real decompiler output.
The synthetic transformations are rule-based approximations that may not capture the full complexity of actual Ghidra pseudocode.
Additionally, the smaller dataset size compared to the 4,000-sample general training set limits the model's ability to generalize.

=== Mixed Training Data

Based on the limited success of targeted training, a second approach combined synthetic error examples with original training data.
The mixing ratio was determined by sampling original examples at twice the count of synthetic examples, yielding an approximate 1:2 ratio of error-targeted to general samples.
This weighting aims to reinforce error correction while retaining broad decompilation capability.

// #figure(
//   table(
//     columns: (auto, auto, auto, auto),
//     inset: 10pt,
//     align: (left, center, center, center),
//     table.header(
//       [*Model*], [*Pass\@1 (%)*], [*Compile (%)*], [*#sym.Delta Pass\@1*]
//     ),
//     [Baseline],
//     [15.50 #sym.plus.minus 1.08],
//     [18.94 #sym.plus.minus 0.53],
//     [---],

//     [General LoRA],
//     [23.95 #sym.plus.minus 1.35],
//     [84.33 #sym.plus.minus 1.19],
//     [+8.45],

//     [Mixed LoRA],
//     [*28.08* #sym.plus.minus 1.30],
//     [64.50 #sym.plus.minus 1.54],
//     [*+12.58*],
//   ),
//   caption: [Comparison of general and mixed LoRA training],
// ) <mixed-lora-results>

The mixed LoRA achieves the highest Pass\@1 of 28.08%, representing an 81% relative improvement over baseline and a 17% relative improvement over the general LoRA.
However, the compile rate decreases from 84.33% to 64.50%.

This trade-off reveals an important insight: the error-focused training data successfully improves semantic correctness (the model produces functionally correct code more often) but at the cost of introducing some syntactic errors.
Combining error examples with general training data proves more effective than either approach alone, suggesting that robust decompilation requires both broad pattern coverage and targeted error correction.

=== Summary

#figure(
  table(
    columns: (auto, auto, auto, auto),
    inset: 10pt,
    align: (left, center, center, center),
    table.header(
      [*Model*], [*Pass\@1 (%)*], [*Compile (%)*], [*#sym.Delta Pass\@1*]
    ),
    [Baseline],
    [15.50 #sym.plus.minus 1.08],
    [18.94 #sym.plus.minus 0.53],
    [---],

    [Targeted LoRA],
    [20.13 #sym.plus.minus 0.32],
    [21.06 #sym.plus.minus 0.26],
    [+4.63],

    [General LoRA],
    [23.95 #sym.plus.minus 1.35],
    [84.33 #sym.plus.minus 1.19],
    [+8.45],

    [Mixed LoRA],
    [*28.08* #sym.plus.minus 1.30],
    [64.50 #sym.plus.minus 1.54],
    [*+12.58*],
  ),
  caption: [Summary of all LoRA configurations],
) <lora-summary>

The results demonstrate a clear progression: targeted training alone provides modest semantic improvement but neglects syntactic learning; general training dramatically improves syntax but plateaus on semantics; mixed training achieves the best functional correctness by combining both objectives.
The compile rate trade-off in the mixed approach suggests future work could explore curriculum learning or multi-objective optimization to balance syntactic and semantic improvements.

= Discussion

This chapter interprets the experimental findings, examines their implications for neural decompilation, and acknowledges the limitations of this work.

== Interpretation of Results

The experimental results reveal a fundamental distinction between syntactic and semantic aspects of the decompilation task.
LoRA fine-tuning achieves a 4.5#sym.times improvement in compile rate (from 18.94% to 84.33%) but only a 54% relative improvement in Pass\@1 (from 15.50% to 23.95%).
This asymmetry suggests that the two challenges require different capabilities: syntactic correction involves learning systematic transformations that map Ghidra artifacts to valid C constructs, while semantic correctness requires reasoning about program logic that may be ambiguous or underspecified in the decompiled representation.

The failure of Knowledge Editing provides insight into the nature of decompilation errors.
ROME and similar methods are designed to update atomic factual associations, effectively changing what the model "knows". However, the base CodeLlama model already possesses the factual knowledge; it correctly identifies that `undefined4` corresponds to `int` when asked directly.
The decompilation failures stem not from missing knowledge but from inconsistent application of known facts during generation.
This distinction is crucial: neural decompilation is a holistic reasoning task requiring context-dependent inference, not a factual retrieval task susceptible to surgical weight modifications.

The error-specific fine-tuning experiments further illuminate this distinction.
The targeted LoRA trained exclusively on synthetic error examples improves Pass\@1 modestly (+4.63 percentage points) while leaving compile rate essentially unchanged.
This indicates that error correction patterns can be learned, but in isolation they are insufficient; the model requires exposure to the full diversity of decompiler output to generate syntactically valid code.
The mixed LoRA, combining error examples with general training data, achieves the highest Pass\@1 (28.08%) but at the cost of reduced compile rate (64.50%).
This trade-off suggests that optimizing for semantic correctness and syntactic validity may involve competing objectives that are difficult to satisfy simultaneously with a single adapter.

- explain limitations: small dataset (4k rows), time and compute constraints
- diminishing returns indicate a ceiling on what LoRA alone can achieve

= Conclusion

- summarize results
- restate findings
- clean bibliography and references

#bibliography("references.bib")
