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

Hiermit versichere ich, dass ich die Arbeit selbst verfasst und keine anderen als die angegebenen Quellen und Hilfsmittel benutzt und wörtlich oder inhaltlich aus fremden Werken Übernommenes als fremd kenntlich gemacht habe.
Ferner versichere ich, dass die übermittelte elektronische Version in Inhalt und Wortlaut mit der gedruckten Version meiner Arbeit vollständig übereinstimmt.
Ich bin einverstanden, dass diese elektronische Fassung universitätsintern anhand einer Plagiatssoftware auf Plagiate überprüft wird.

Heidelberg, den 16.01.2026

Hendrik Lohmar

#pagebreak()

#set page(numbering: "i")
#counter(page).update(1)

#align(center)[
  #set par(justify: false)
  #text(size: 17pt, weight: "bold")[Abstract]\
  #v(1mm)
  _English_ \
  #v(1mm)
]

Decompilation, the process of recovering source code from compiled binaries, is essential for security analysis and legacy software maintenance.
Traditional decompilers like Ghidra produce pseudocode that aids human understanding but often cannot be directly compiled or executed.
This thesis investigates parameter-efficient methods for adapting Large Language Models to refine Ghidra pseudocode into valid, compilable C code.

We compare two fundamentally different approaches: Low-Rank Adaptation (LoRA), which trains small adapter matrices while keeping base model weights frozen, and Knowledge Editing, which surgically modifies specific model weights to correct individual errors.
We evaluate these methods using CodeLlama-7B-Instruct on a benchmark of 151 functions with functional correctness tests.

Our experiments reveal that LoRA fine-tuning substantially improves decompilation quality, achieving a functional correctness rate of 28.08% and a compile rate of 84.33%, compared to the baseline of 15.50% and 18.94% respectively.
Knowledge Editing, however, proved ineffective for this task, as decompilation errors involve complex structural transformations rather than discrete factual corrections.

A key finding is the syntactic-semantic gap: high compile rates do not guarantee functional correctness.
Models can learn to produce syntactically valid code while still generating semantically incorrect implementations.
This gap highlights the importance of functional testing over surface-level metrics in neural decompilation research.

#pagebreak()

#align(center)[
  #set par(justify: false)
  #text(size: 17pt, weight: "bold")[Abstract]\
  #v(1mm)
  _Deutsch_ \
  #v(1mm)
]

Dekompilierung, der Prozess der Wiederherstellung von Quellcode aus kompilierten Binärdateien, ist für Sicherheitsanalysen und die Wartung von Legacy-Software unerlässlich.
Traditionelle Decompiler wie Ghidra erzeugen Pseudocode, der das menschliche Verständnis unterstützt, aber oft nicht direkt kompiliert oder ausgeführt werden kann.
Diese Arbeit untersucht parametereffiziente Methoden zur Anpassung von Large Language Models, um Ghidra-Pseudocode in gültigen, kompilierbaren C-Code zu transformieren.

Wir vergleichen zwei grundlegend verschiedene Ansätze: Low-Rank Adaptation (LoRA), das kleine Adaptermatrizen trainiert, während die Basismodellgewichte eingefroren bleiben, und Knowledge Editing, das gezielt spezifische Modellgewichte modifiziert, um einzelne Fehler zu korrigieren.
Wir evaluieren diese Methoden mit CodeLlama-7B-Instruct auf einem Benchmark von 151 Funktionen mit funktionalen Korrektheitstests.

Unsere Experimente zeigen, dass LoRA-Fine-Tuning die Dekompilierungsqualität erheblich verbessert und eine funktionale Korrektheitsrate von 28,08% sowie eine Kompilierungsrate von 84,33% erreicht, verglichen mit der Baseline von 15,50% bzw. 18,94%.
Knowledge Editing erwies sich jedoch als ineffektiv für diese Aufgabe, da Dekompilierungsfehler komplexe strukturelle Transformationen und keine diskreten faktischen Korrekturen erfordern.

Eine zentrale Erkenntnis ist die syntaktisch-semantische Lücke: Hohe Kompilierungsraten garantieren keine funktionale Korrektheit.
Modelle können lernen, syntaktisch gültigen Code zu erzeugen, der dennoch semantisch falsche Implementierungen enthält.
Diese Lücke unterstreicht die Bedeutung funktionaler Tests gegenüber oberflächlichen Metriken in der Forschung zur neuronalen Dekompilierung.

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

Reverse engineering of software binaries is essential for security analysis, malware detection, legacy system maintenance, and vulnerability research.
At the core of this process lies decompilation: transforming compiled machine code back into human-readable source code.
However, decompilation is inherently lossy; the compilation process discards variable names, type information, comments, and high-level structure, leaving decompilers to reconstruct these elements through heuristic analysis.

Modern decompilers such as Ghidra @nationalsecurityagencyGhidra2019 produce pseudocode that, while logically equivalent to the original program, often contains artifacts that make it difficult to read, modify, or recompile.
The artifacts include non-standard type annotations (e.g., `undefined4`), synthesized variable names, and unconventional control flow constructs.
Human analysts must manually refine this output, a time-consuming process that scales poorly with the volume of software requiring analysis.

Recent advances in Large Language Models (LLMs) have demonstrated remarkable capabilities in code understanding and generation @roziereCodeLlamaOpen2023, suggesting their potential application to decompilation refinement.
Rather than replacing traditional decompilers, LLMs could serve as a post-processing step, transforming pseudocode into clean, idiomatic, and compilable source code.
However, applying pre-trained LLMs directly to this task yields poor results; the models reproduce decompiler artifacts rather than translating them into standard constructs.

This thesis investigates two adaptation approaches for improving LLM-based decompilation: Low-Rank Adaptation (LoRA) @huLoRALowRankAdaptation2021, a parameter-efficient fine-tuning method, and Knowledge Editing @mengLocatingEditingFactual2023, a technique for surgically modifying model weights to correct specific factual associations.
These approaches represent fundamentally different hypotheses about the nature of decompilation errors and offer complementary strategies for addressing them.

== Problem Statement

Pre-trained Large Language Models for code, such as CodeLlama @roziereCodeLlamaOpen2023, possess extensive knowledge of programming languages and can generate syntactically correct code in various contexts.
However, when presented with Ghidra pseudocode, these models frequently reproduce decompiler-specific artifacts rather than translating them into standard C constructs.
This results in output that fails to compile or, when it does compile, produces functionally incorrect results.

The central challenge is adapting these models to the decompilation task efficiently.
Full fine-tuning requires updating billions of parameters, demanding significant computational resources and risking catastrophic forgetting @kirkpatrickOvercomingCatastrophicForgetting2017 of the model's general capabilities.
Two alternative approaches warrant investigation:

*Low-Rank Adaptation (LoRA)* introduces small trainable matrices into the model architecture, enabling task-specific adaptation while keeping the base model frozen.
This approach hypothesizes that decompilation can be learned as a general skill through exposure to pseudocode-to-source-code examples.

*Knowledge Editing* directly modifies specific model parameters to correct targeted factual associations.
This approach hypothesizes that decompilation errors stem from incorrect or missing factual mappings (e.g., that `undefined4` should map to `int`) that can be surgically corrected.

== Research Questions

This thesis addresses the following research questions:

+ *RQ1*: How effectively can LoRA fine-tuning improve the functional correctness of LLM-generated decompiled code?
+ *RQ2*: Can Knowledge Editing techniques correct systematic decompiler artifacts in model output?
+ *RQ3*: What types of decompilation errors are addressable through model adaptation, and what limitations remain?
+ *RQ4*: How do targeted error-specific training approaches compare to general fine-tuning for improving decompilation quality?

== Contributions

This thesis makes the following contributions:

+ A systematic evaluation of LoRA fine-tuning for neural decompilation, demonstrating a 54% relative improvement in functional correctness (Pass\@1 from 15.50% to 23.95%) and a 4.5#sym.times improvement in compile rate.
+ A documented negative result showing that Knowledge Editing is unsuitable for neural decompilation, with analysis that decompilation errors stem from reasoning failures rather than knowledge gaps.
+ An error taxonomy categorizing decompilation failures into addressable patterns (45%) and fundamental limitations (55%), providing insight into the ceiling of achievable performance.
+ Evidence for a "syntactic-semantic gap" in neural decompilation, where syntactic correction is readily achievable but semantic reasoning remains challenging.
+ Demonstration that mixed training combining error-specific examples with general data achieves the highest functional correctness (28.08% Pass\@1), representing an 81% relative improvement over baseline.

== Thesis Outline

The remainder of this thesis is organized as follows.

*Chapter 2: Background* provides foundational material on decompilation, neural approaches to code transformation, parameter-efficient fine-tuning methods, and knowledge editing techniques.

*Chapter 3: Related Work* surveys existing research in neural decompilation and positions this work within the broader landscape.

*Chapter 4: Methodology* describes the experimental design, including the data pipeline, model configuration, training procedures, and evaluation framework.

*Chapter 5: Results* presents the experimental findings, including baseline performance, LoRA fine-tuning results, error analysis, and error-specific fine-tuning outcomes.

*Chapter 6: Discussion* interprets the results, examines implications for neural decompilation, and acknowledges limitations.

*Chapter 7: Conclusion* summarizes the findings and suggests directions for future work.

= Background

This chapter introduces the foundational concepts required to understand the experimental work presented in this thesis.
We begin with decompilation fundamentals, then cover the machine learning approaches under investigation: Parameter-Efficient Fine-Tuning and Knowledge Editing.

== Decompilation Fundamentals

=== Compilation and Information Loss

Compilation transforms human-readable source code into machine-executable binary code through multiple stages: preprocessing, parsing, semantic analysis, optimization, and code generation @ahoCompilersPrinciplesTechniques2002.
Each stage discards information that is unnecessary for execution but valuable for human understanding.

Variable names become register allocations or stack offsets.
Type information is reduced to memory sizes and alignment constraints.
Control flow structures like `for` and `while` loops compile to identical jump instructions.
Comments and formatting disappear entirely.
High-level abstractions such as struct layouts, inline functions, and macro expansions are flattened into sequences of machine instructions.

This information loss is inherently one-way.
The compilation process is a many-to-one mapping: countless source programs compile to identical binaries.
Recovering the original source from a binary is therefore fundamentally ill-posed; we can only approximate one of many possible originals.

// add figure that shows pipeline

=== Traditional Decompilers

Decompilers attempt to reverse compilation by analyzing binary code and producing readable source code.
Modern decompilers like Ghidra @nationalsecurityagencyGhidra2019, IDA Pro @hex-raysIDAPro, and angr @shoshitaishviliSOKStateArt2016 employ sophisticated techniques including control flow graph reconstruction, data flow analysis, type recovery, and pattern matching for common idioms.

Despite these techniques, decompiler output differs substantially from original source code.
Ghidra, the decompiler used in this thesis, produces pseudocode that is syntactically similar to C but contains artifacts of the recovery process.
These include generic type names like `undefined4` for recovered 32-bit values, synthesized variable names such as `local_10` based on stack positions, and occasionally incorrect control flow reconstruction.

While this output aids human reverse engineers in understanding program behavior, it typically cannot be directly compiled.
The gap between decompiler output and compilable source code motivates the neural decompilation approach explored in this thesis.

- explain how ghidra works
- give artifacts examples

== Transformer architecture

=== Self-Attention Mechanism

=== Feed-Forward Layers

== Large Language Models

=== Pretraining and Scale

=== LLMs for Code

== Neural Decompilation

Neural decompilation frames the refinement of decompiler output as a sequence-to-sequence translation task @fuNeuralbasedProgramDecompiler2019. Rather than reconstructing source code from raw binaries, neural approaches take existing decompiler output as input and generate improved, compilable code as output.

This framing has several advantages.
First, traditional decompilers handle the complex low-level analysis; recovering control flow, identifying function boundaries, and inferring approximate types.
The neural model then focuses on the higher-level task of producing natural, compilable code.
Second, the approach can leverage the large body of work on neural machine translation and code generation.

Large Language Models pretrained on code, such as CodeLlama @roziereCodeLlamaOpen2023, have shown strong performance on code generation tasks.
Fine-tuning these models on decompilation data allows them to learn the mapping from decompiler artifacts to conventional C idioms.
The model learns to replace `undefined4` with appropriate types, generate meaningful variable names, and restructure awkward control flow into idiomatic patterns.

- state how code LLMs differ from text LLMs
- training data, objectives
- llama -> codellama progression
- Instruction tuning

== Parameter-Efficient Fine-Tuning

- explain why lora was chosen
- maybe mention alternatives

=== The Challenge of Full Fine-Tuning

Fine-tuning adapts a pretrained model to a specific task by updating its parameters on task-specific data.
For modern Large Language Models with billions of parameters, full fine-tuning presents significant challenges.
Updating all parameters requires storing optimizer states and gradients for each parameter, often exceeding available GPU memory.
Furthermore, each fine-tuned model requires storing a complete copy of all parameters, making it expensive to maintain multiple specialized models.

=== Low-Rank Adaptation (LoRA)

Low-Rank Adaptation (LoRA) @huLoRALowRankAdaptation2021 addresses these challenges by freezing the pretrained model weights and injecting trainable low-rank decomposition matrices into each layer.
For a pretrained weight matrix $W_0 in RR^(d times k)$, LoRA adds a parallel path:

$ h = W_0 x + Delta W x = W_0 x + B A x $

where $A in RR^(r times k)$ and $B in RR^(d times r)$ are small trainable matrices with rank $r << min(d, k)$.
During training, only $A$ and $B$ are updated while $W_0$ remains frozen.

This approach dramatically reduces trainable parameters.
For a model with $d = 4096$, applying LoRA with rank $r = 64$ to a weight matrix reduces trainable parameters from 16 million to approximately 500 thousand; a 32#sym.times reduction.

=== QLoRA

QLoRA @dettmersQLoRAEfficientFinetuning2023 extends LoRA by combining it with quantization.
The frozen base model weights are stored in 4-bit precision using a novel NormalFloat (NF4) data type optimized for normally distributed weights.
The low-rank adapters remain in higher precision for training stability.

This combination enables fine-tuning models that would otherwise exceed available memory.
A 7-billion parameter model that requires approximately 28G in 16-bit precision can be loaded in roughly 4GB with 4-bit quantization, making fine-tuning feasible on consumer hardware.

== Knowledge Editing

- mention other methods
- explain why ROME was chosen

Knowledge Editing refers to techniques for making targeted modifications to a model's behavior without full retraining.
Unlike fine-tuning, which updates parameters across the entire model, Knowledge Editing aims to surgically modify specific factual associations or behaviors.

Rank-One Model Editing (ROME) @mengLocatingEditingFactual2023 localizes factual knowledge to specific MLP layers in Transformer models @vaswaniAttentionAllYou2023 and modifies their weights to update individual facts.
The technique treats certain MLP layers as key-value stores and uses rank-one updates to change specific associations while preserving other model capabilities.

ROME and related methods were originally developed for correcting factual errors in language models; for example, updating a model's knowledge that "The Eiffel Tower is located in Paris" to "The Eiffel Tower is located in London".
The technique has shown promise for such targeted corrections while maintaining model performance on unrelated tasks.

This thesis investigates whether Knowledge Editing can similarly correct specific decompilation errors; treating incorrect code patterns as "facts" to be edited.

== Evaluation Metrics

Evaluating decompilation quality requires metrics that capture functional correctness rather than surface-level textual similarity.
A decompiled function may use different variable names, formatting, or even algorithmic approaches while remaining functionally equivalent to the original.

*Pass\@k* @chenEvaluatingLargeLanguage2021 measures the probability that at least one of $k$ generated samples passes all test cases.
For Pass\@1, each generated function is compiled and executed against a test harness containing assertions that verify functional behavior.
A function passes only if it compiles successfully, executes without errors, and produces correct outputs for all test inputs.

*Compile rate* measures the fraction of generated functions that successfully compile, independent of functional correctness.
The metric captures the model's ability to produce syntactically valid code; a prerequisite for any practical use.

These metrics are preferable to text-based metrics like BLEU @papineniBLEUMethodAutomatic2001 or exact match, which can penalize functionally correct code that differs stylistically from reference implementations.
A function that correctly implements a specification with different variable names receives full credit under Pass\@k but may score poorly on textual similarity metrics.

= Related Work

This chapter situates the present work within the broader landscape of neural decompilation research and highlights the specific gap this thesis addresses.

== Neural Decompilation Systems

Early approaches to neural decompilation employed recurrent neural networks to translate assembly or low-level intermediate representations directly to source code.
Coda @fuNeuralbasedProgramDecompiler2019 pioneered the end-to-end neural decompiler concept, training sequence-to-sequence models to transform binary representations into C code.

More recent work has leveraged the capabilities of Large Language Models.
LLM4Decompile @tanLLM4DecompileDecompilingBinary2024 represents the current state-of-the-art, training a series of models ranging from 1.3B to 33B parameters specifically for decompilation.
Their approach follows two paradigms: end-to-end decompilation from assembly, and refinement of existing decompiler output.
The refinement approach, which takes Ghidra pseudocode as input, achieved substantially higher re-executability rates than the end-to-end method.

Other LLM-based approaches include DecGPT @wongRefiningDecompiledCode2023, which refines IDA Pro output by incorporating compiler error messages into an iterative refinement loop, and DeGPT @huDeGPTOptimizingDecompiler2024, which focuses on improving the readability of Ghidra output for human analysts.
Nova @jiangNovaGenerativeLanguage2025 developed specialized binary language models fine-tuned for decompilation tasks.

These systems share a common methodology: they either train or fine-tune models on large corpora of binary-source pairs, updating all model parameters.
LLM4Decompile, for instance, trains on billions of tokens of decompilation data.
This full fine-tuning approach achieves strong results but requires substantial computational resources and produces task-specific models that cannot easily incorporate targeted corrections.

== Research Gap and Positioning

While existing work has demonstrated the effectiveness of LLMs for decompilation, the field has not systematically explored parameter-efficient adaptation methods.
All major neural decompilation systems employ either full fine-tuning or prompting-based approaches.

This thesis investigates whether parameter-efficient techniques can achieve competitive results while enabling more flexible model adaptation.
Specifically, we compare:

+ *Low-Rank Adaptation (LoRA)* as a parameter-efficient alternative to full fine-tuning, examining whether the dramatic reduction in trainable parameters compromises decompilation quality.
+ *Knowledge Editing* as a surgical intervention technique, testing whether decompilation errors can be corrected through targeted weight modifications rather than broad training.
+ *Targeted LoRA training* on error-specific datasets, combining the efficiency of LoRA with focused training on particular error categories.

This comparison addresses a practical concern: as LLMs grow larger, full fine-tuning becomes increasingly prohibitive.
If parameter-efficient methods can match or approach full fine-tuning performance, they offer a more accessible path to specialized decompilation models.

Furthermore, only a few prior works have investigated Knowledge Editing for code transformation tasks @liModelEditingLLMs4Code2024.
While ROME and related techniques have shown success in correcting factual knowledge, their applicability to structural code transformations remains unexplored.
This thesis provides the first empirical evaluation of Knowledge Editing in the decompilation domain.

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

== Data Pipeline

The experimental infrastructure relies on two complementary datasets serving distinct purposes in the evaluation pipeline.
*ExeBench* @armengol-estapeExeBenchMLscaleDataset2022 serves as the primary training corpus, providing a diverse collection of C functions suitable for fine-tuning the models.
*HumanEval-Decompile* @tanLLM4DecompileDecompilingBinary2024 functions as the evaluation dataset, offering 151 programming problems with associated test harnesses that enable rigorous verification of functional equivalence beyond mere syntactic similarity.

The data preparation process begins with *compilation*, where source C code is compiled into binary executables using GCC @gnuprojectGNUCompilerCollection with the `-O2` optimization level.
This optimization setting represents a realistic balance between performance and debuggability commonly used in production software, producing binaries with substantial compiler transformations, including loop optimizations, function inlining, and register allocation, while avoiding the most aggressive optimizations that can make decompilation exceptionally challenging.

Following compilation, *decompilation* is performed using Ghidra in headless mode, enabling automated batch processing of binaries.
Ghidra's decompiler analyzes each compiled binary and generates pseudocode that serves as the input representation for the neural models.
This pseudocode retains low-level semantics such as explicit type casts, pointer arithmetic, and architecture-specific idioms while providing more structure than raw assembly.

To ensure dataset quality, a *filtering and quality assurance* process is applied to the generated pairs of Ghidra pseudocode and original source code.
Filtering criteria include line length constraints to remove excessively long or short functions that may represent edge cases, length ratio checks between pseudocode and source code to identify potential decompilation failures or anomalies, and validation to ensure both input and output constitute valid, complete function pairs.
These filters remove malformed samples that could introduce noise during training or evaluation.

The resulting dataset comprises approximately *4,000 training samples* from ExeBench and *151 test samples* from HumanEval-Decompile, each accompanied by test harnesses that enable automated verification of functional correctness through execution-based testing.

== LoRA Fine-Tuning Approach

=== Base Model Selection

The foundation for LoRA fine-tuning is CodeLlama 7B Instruct, a 7-billion parameter large language model specifically optimized for code-related tasks.
CodeLlama @roziereCodeLlamaOpen2023 represents a family of models derived from Llama 2 @touvronLlama2Open2023, further trained on code-heavy corpora to develop stronger capabilities in code understanding, generation, and transformation tasks.
The Instruct variant has been additionally fine-tuned to follow instructions, making it particularly well-suited for task-oriented applications where the model must respond to structured prompts.

Several factors motivated this selection.
First, the 7B parameter scale strikes a practical balance between model capacity and computational feasibility, enabling relatively efficient fine-tuning and inference while maintaining sufficient representational power for complex code transformations.
Second, CodeLlama's architecture and training specifically target programming language understanding, providing a stronger starting point than general-purpose language models.
Third, the Instruct variant's instruction-following capabilities align well with the decompilation task formulation, where the model receives explicit directives to transform Ghidra pseudocode into clean C code.
Finally the model's open availability and extensive community adoption provide valuable resources for implementation and comparison.

=== Training Configuration

The training infrastructure employs *Unsloth* @hanUnsloth2023, an optimized framework for efficient LLM fine-tuning that provides significant speedups over standard implementations.
The base model is loaded in 4-bit precision, reducing memory requirements while maintaining model quality.
Unsloth's custom gradient checkpointing implementation further reduces memory overhead compared to standard PyTorch @paszkePyTorchImperativeStyle2019 gradient checkpointing.

The LoRA configuration targets all linear projection layers within the Transformer architecture.
For the attention mechanism, this includes the query, key, value, and output projections (`q_proj`, `k_proj`, `v_proj`, `o_proj`).
For the feed-forward network, the gated MLP projections are targeted (`gate_proj`, `up_proj`, `down_proj`).
This comprehensive targeting ensures that adaptations can occur throughout the model's representational pipeline.
Unlike some configurations that apply dropout to LoRA layers, dropout is set to zero for improved training stability with small datasets.

The training hyperparameters are configured as follows.
A per-device batch size of 2 is used with gradient accumulation over 8 steps, yielding an effective batch size of 16.
The maximum sequence length is set to 2048 tokens, sufficient to accommodate most function pairs in the dataset.
Training proceeds for 3 epochs with a learning rate of $2 times 10^(-4)$ and a linear learning rate scheduler with a warmup ratio of 0.05.
The optimizer is AdamW @loshchilovDecoupledWeightDecay2019 with 8-bit states.
A weight decay of 0.01 provides light regularization.
A fixed random seed of 3407 ensures reproducibility across training runs.

Training was conducted using cloud and high-performance computing resources.
The majority of LoRA training runs utilized Google Colab @googleresearchGoogleColaboratory instances with a single NVIDIA A100 GPU (40GB VRAM).
Selected experiments were conducted on the bwHPC cluster @baden-wurttembergministeriumfurwissenschaftforschungundkunstBwHPC provided by the state of Baden-Württemberg, using nodes with four NVIDIA H100 GPUs.

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
    [Weight decay], [0.01],
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
Each configuration was evaluated across 5 independent runs on the HumanEval-Decompile test set (n=151) to account for sampling variability.

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
  caption: [LoRA hyperparameter search results on HumanEval-Decompile (5 runs per config). Bold indicates best performance.],
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
All evaluations use the HumanEval-Decompile test set (n=151) with generated code compiled via GCC (`-O2` optimization) and executed against test harnesses with a 2-second timeout.
Code generation employs nucleus sampling (temperature 0.2, top-p 0.95) @holtzmanCuriousCaseNeural2020, and each configuration is evaluated across five independent runs to account for sampling variability.

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
  caption: [Baseline model performance on HumanEval-Decompile (n=151, 5 runs)],
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
The compile rate trade-off in the mixed approach suggests future work could explore curriculum learning @bengioCurriculumLearning2009 or multi-objective optimization to balance syntactic and semantic improvements.

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

== The Syntactic-Semantic Gap

The consistent pattern across all experiments points to what might be termed a "syntactic-semantic gap" in neural decompilation.
Syntactic adaptation, learning to produce valid C code rather than pseudocode artifacts, is readily achievable through fine-tuning.
Even the smallest LoRA configuration (r=8) improves compile rate from 18.94% to 82.38%.
This suggests that syntactic patterns are relatively surface-level and can be captured with modest parameter budgets.

Semantic correctness, however, exhibits diminishing returns.
Configurations from r=32 to r=128 all achieve approximately 23-24% Pass\@1, indicating a ceiling that additional capacity cannot overcome.
The error analysis provides insight into why: approximately 55% of failures stem from fundamental limitations (decompiler information loss and algorithm re-interpretation) that cannot be addressed through model adaptation alone.
When Ghidra produces a stub function or ambiguous pseudocode, no amount of fine-tuning can recover the original semantics.

The remaining 45% of failures involving loop bounds, operators, and initialization represent the addressable portion of semantic errors.
The mixed LoRA's improvement over the general LoRA (+4.13 percentage points) likely comes from better handling of these systematic error patterns. However, this improvement is modest relative to the syntactic gains, suggesting that even "addressable" semantic errors require more sophisticated interventions than pattern-based training can provide.

== Implications for Neural Decompilation

These findings have several implications for future work in neural decompilation.

First, the effectiveness of LoRA for syntactic correction suggests that pseudocode-to-code translation could serve as a preprocessing step, converting decompiler output into compilable C before applying more sophisticated semantic analysis.
This decomposition might allow specialized models or techniques to focus on each subproblem independently.

Second, the limitations of Knowledge Editing indicate that neural decompilation errors are not localized faults that can be patched individually.
Improving semantic correctness likely requires architectural innovations that enhance reasoning capabilities, such as chain-of-thought prompting @weiChainofThoughtPromptingElicits2023, retrieval augmentation @lewisRetrievalAugmentedGenerationKnowledgeIntensive2021, or multi-pass refinement strategies.

Third, the trade-off observed in mixed training suggests that multi-objective optimization or curriculum learning @bengioCurriculumLearning2009 approaches might better balance syntactic and semantic improvements.
Rather than training on a fixed mixture of examples, adaptive strategies could emphasize different objectives at different training stages.

== Limitations

Several limitations constrain the generalizability of these findings.

*Dataset scale*: The training corpus comprises approximately 4,000 samples from ExeBench, which may be insufficient to capture the full diversity of real-world decompilation scenarios.
Larger datasets might shift the observed performance ceilings, and the specific patterns learned may not transfer to binaries compiled with different compilers, optimization levels, or architectures.

*Model scale*: All experiments use CodeLlama 7B, a relatively small model by contemporary standards.
Larger models might exhibit different learning dynamics; in particular, the semantic reasoning ceiling might shift with increased model capacity.
However, computational constraints precluded experiments with larger models.

*Evaluation scope*: The HumanEval-Decompile test set contains 151 relatively short functions with clear input-output specifications.
Real-world decompilation often involves longer functions, complex data structures, and incomplete specifications.
The reported metrics may overestimate performance on more challenging targets.

*Optimization level*: All binaries were compiled with `-O2` optimization.
Different optimization levels produce different decompilation challenges; aggressive optimizations like `-O3` introduce additional complexity, while unoptimized builds (`-O0`) might be substantially easier.

*Single decompiler*: The evaluation focuses exclusively on Ghidra-generated pseudocode.
Other decompilers (IDA Pro, angr) produce different output formats and artifacts, and findings may not transfer directly.

Despite these limitations, the core finding, that syntactic correction is achievable through fine-tuning while semantic reasoning remains challenging, likely holds across settings.
The specific performance numbers should be interpreted as indicative rather than definitive.

= Conclusion

This thesis investigated two adaptation approaches for improving neural decompilation: Low-Rank Adaptation (LoRA) and Knowledge Editing.
The research was motivated by the observation that pre-trained language models, while capable of code generation, struggle to produce valid C code from Ghidra-generated pseudocode without task-specific adaptation.

== Summary of Findings

The experimental evaluation yielded several key findings.

First, LoRA fine-tuning substantially improves decompilation performance.
The best configuration (r=64, a=64) achieved a Pass\@1 of 23.95%, representing a 54% relative improvement over the baseline of 15.50%.
More dramatically, the compile rate improved from 18.94% to 84.33%, demonstrating that fine-tuning effectively teaches the model to generate syntactically valid C code rather than pseudocode artifacts.

Second, Knowledge Editing proved unsuitable for neural decompilation.
The investigation revealed that decompilation errors do not stem from missing factual knowledge but from inconsistent application of known transformation rules during generation.
This negative result clarifies that neural decompilation is fundamentally a reasoning task, not a knowledge retrieval task.

Third, error-specific fine-tuning with mixed training data achieved the highest functional correctness.
By combining synthetic error examples with general training data, the mixed LoRA reached 28.08% Pass\@1, an 81% relative improvement over baseline.
However, this came at the cost of reduced compile rate (64.50%), revealing a trade-off between syntactic and semantic optimization objectives.

Fourth, a "syntactic-semantic gap" characterizes the neural decompilation challenge.
Syntactic correction is readily achievable through fine-tuning, with even minimal LoRA configurations dramatically improving compile rates.
Semantic correctness, however, exhibits diminishing returns, with approximately 55% of failures stemming from fundamental limitations that model adaptation alone cannot address.

== Contributions

This work makes the following contributions:

+ A systematic comparison of LoRA fine-tuning configurations for neural decompilation, identifying optimal hyperparameters and characterizing the relationship between model capacity and performance.
+ A documented negative result demonstrating the unsuitability of Knowledge Editing for code transformation tasks, with analysis explaining why factual editing methods fail when the underlying challenge is reasoning rather than knowledge.
+ An error taxonomy for neural decompilation failures, distinguishing addressable patterns (loop bounds, operators, initialization) from fundamental limitations (information loss, algorithmic ambiguity).
+ Evidence for the syntactic-semantic gap in neural decompilation, providing a framework for understanding why compile rate improvements do not proportionally translate to functional correctness gains.

== Future Work

Several directions emerge from this research.

The trade-off between syntactic and semantic objectives observed in mixed training suggests that multi-objective optimization or curriculum learning @bengioCurriculumLearning2009 approaches warrant investigation.
Adaptive training strategies that balance these objectives throughout the learning process might achieve both high compile rates and improved functional correctness.

The 55% of failures attributed to fundamental limitations highlights the need for improved decompilation input quality.
Techniques that preserve more semantic information during decompilation, or that provide additional context such as type information or function signatures, could shift the ceiling on achievable performance.

Finally, the reasoning limitations observed suggest that architectural innovations beyond fine-tuning may be necessary.
Chain-of-thought prompting @weiChainofThoughtPromptingElicits2023, retrieval-augmented generation @lewisRetrievalAugmentedGenerationKnowledgeIntensive2021, or multi-pass refinement strategies that decompose the decompilation task into subtasks represent promising directions for future research.

#bibliography("references.bib")

