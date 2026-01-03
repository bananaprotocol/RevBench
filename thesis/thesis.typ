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

== Data Pipeline

- data sources: ExeBench, AnghaBench
- compiler choice, compilation settings, optimization level
- ghidra decompilation
- filtering: line length, length ratio

== Comparison

- strategy A: global fine-tuning using LoRA
- strategy B: surgical editing using Knowledge Editing
- hypothesis: "can we improve general decompilation and fix specific decompilation faults without retraining the whole model?"

= Experimental Setup

- base model: CodeLlama-7B Instruct
- LoRA hyperparameters
- Knowledge Editing config
- evaluation metric: Pass\@1 with HumanEval, compilability
- why this metric? why is e.g. BLEU bad? are there other metrics?
- functional equivalence: unit tests, symbolic execution, fuzzing

= Results & Evaluation

- LoRA performance
- Knowledge Editing success rate
- comparison: did KE break the rest of the model?

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
