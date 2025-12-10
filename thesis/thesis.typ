#set text(size: 12pt)

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
#set page(
  numbering: "1",
)

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

= Introduction

- reverse engineering is a manual and tedious process
- modern binaries are heavily optimized, stripping variable names, structure, ...
- we investigate LoRA and Knowledge Editing as cheaper alternatives to improve decompilation performance and fix specific decompiler hallucinations

= Background & Related Work

== Neural Decompilation

- what is it?
- how do standard decompilers work?
- why do they only create pseudocode?

== Large Language Models

- how do transformers work?
- how does attention work?

== Low-Rank Adaptation

- how does LoRA work?
- what are the rank decomposition matrices A and B?
- why does it save memory?

== Knowledge Editing

- how is knowledge specified?
- what methods exist and how do they differ?
- which methods are suitable for code LLMs?

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
