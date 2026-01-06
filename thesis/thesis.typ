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

#counter(page).update(1)
#align(center)[
  #page(numbering: "i")[
    #set par(justify: false)
    #text(size: 17pt, weight: "bold")[Abstract]\
    #v(1mm)
    _English_ \
    #v(1mm)
    #lorem(200)]
]

#align(center)[
  #page(numbering: "i")[
    #set par(justify: false)
    #text(size: 17pt, weight: "bold")[Abstract]\
    #v(1mm)
    _Deutsch_ \
    #v(1mm)
    #lorem(200)]
]

#align(center)[
  #page(numbering: "i")[
    #set par(justify: false)
    #text(size: 17pt, weight: "bold")[Acknowledgments]\
    #v(1mm)
    The author acknowledges support by the state of Baden-Württemberg through bwHPC.
  ]
]

#page(numbering: "i")[
  #outline()
]

#counter(page).update(1)
#set page(
  numbering: "1",
)

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

== Evaluation Metrics for Decompilation

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

- data sources: ExeBench (train), HumanEval-C (test)
- compilation: gcc settings, optimizations
- decompilation: ghidra headless
- filtering and quality assurance: line length, length ratio, valid pairs
- statistics: final training set: \~4000 samples, test set: 151 samples with test harnesses

== LoRA Fine-Tuning Approach

- base model: CodeLlama 7B Instruct
- training config: target attention + mlp projections
- QLoRA
- prompt format
- hyperparam search: rank/alpha grid search (r8-r128)

== Knowledge Editing Approach

- formulating decompilation as KE (ghidra artifacts as knowledge triplets)
- edit targets (undefined4 -> int, ...)
- ROME implementation (easyedit, edit specification)
- challenges encountered: standard KE problematic for decompilation

== Error Analysis

- Pass\@1 on HumanEval-C
- Compilation check
- Functional equivalence testing using assertions
- Multiple runs for stability
- Failure categorization
- Semantic error patterns
- Synthetic data generation for targeted training

== Comparison

- strategy A: global fine-tuning using LoRA
- strategy B: surgical editing using Knowledge Editing
- hypothesis: "can we improve general decompilation and fix specific decompilation faults without retraining the whole model?"

= Experimental Setup

- hardware and software environment: gpus, bwHPC cluster, google colab, libraries (transformers, peft, ...)
- base model: CodeLlama-7B Instruct
- evaluation metric: Pass\@1 with HumanEval-C (test harness execution), compilability
- LoRA hyperparameters
- Knowledge Editing config
- why this metric? why is e.g. BLEU bad? are there other metrics?
- functional equivalence: unit tests, symbolic execution, fuzzing

= Results

- baseline performance
- LoRA performance
- Knowledge Editing success rate
- comparison: did KE break the rest of the model?
- error analysis (failure distribution, semantic error taxonomy, trainability assessment)

= Discussion

- try to explain the results
- if LoRA is better: decompilation is a holistic reasoning task, not a factual retrieval task
- if KE is better: specific artifacts are localizable faults, which can be patched
- explain limitations: small dataset (4k rows), time and compute constraints

= Conclusion

- summarize results
- restate findings
- clean bibliography and references

#bibliography("references.bib")
