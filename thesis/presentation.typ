#import "@preview/touying:0.6.1": *
#import themes.simple: *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-page(
    fill: silver,
  ),
)
#show <not-outlined>: set heading(outlined: false)

#set text(font: "IBM Plex Sans", weight: "light", fill: rgb("#333"))
#show raw: set text(font: "IBM Plex Mono")

#title-slide[
  #text(size: 0.7em)[
    = Comparison of LoRA and Knowledge Editing for Improving Neural Decompilation <not-outlined>
  ]

  #text(size: 0.7em)[Bachelor's Thesis Presentation]

  #v(0.3em)

  #text(size: 0.9em)[Hendrik Lohmar]

  #text(size: 0.85em)[Supervisor: Prof. Dr. Artur Andrzejak, Akin Yilmaz]

  #v(0.3em)

  #text(size: 0.7em)[
    Heidelberg University \
    Faculty of Mathematics and Computer Science \
    Institute of Computer Science \
    Artificial Intelligence for Programming (AIP)
  ]

  #v(0.3em)

  #text(size: 0.85em)[February 2, 2026]
]

== Outline

#components.adaptive-columns(outline(title: none, indent: 1em, depth: 1))

= The Decompilation Problem

== Why Decompilation Matters

- Security analysis & vulnerability research
- Malware detection
- Legacy software maintenance
- Reverse engineering

== The Decompilation Problem

Compilation is _lossy_; information is discarded:
- Variable names #sym.arrow registers/stack offsets
- Type information #sym.arrow memory sizes
- Comments & formatting #sym.arrow gone

#align(center)[
  #diagram(
    node-stroke: 0.5pt,
    node-corner-radius: 4pt,
    edge-stroke: 0.5pt,
    spacing: (50mm, 8mm),

    node((0, 0), [Source Code]),
    edge("-|>", label: [compile]),
    node((1, 0), [Binary]),
    edge("-|>", label: [decompile]),
    node((2, 0), [Pseudocode]),

    edge((0, 0), (2, 0), "<-->", bend: -20deg, stroke: (
      dash: "dashed",
      paint: red,
    )),
    node((1, 1.5), text(fill: red)[#sym.eq.not], stroke: none),
  )
]

== Ghidra Decompiler Output

#text(size: 0.6em)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    [
      *Original C code:*
      ```c
      int sum_array(int *arr, int n) {
          int total = 0;
          for (int i = 0; i < n; i++) {
              total += arr[i];
          }
          return total;
      }
      ```
    ],
    [
      *Ghidra pseudocode:*
      ```c
      undefined8 sum_array(long param_1, int param_2) {
        undefined8 uVar1;
        int local_c;
        int local_8;
        local_c = 0;
        local_8 = 0;
        while (local_8 < param_2) {
          local_c = local_c +
            *(int *)(param_1 +
              (long)local_8 * 4);
          local_8 = local_8 + 1;
        }
        uVar1 = CONCAT44(local_c, local_c);
        return uVar1;
      }
      ```
    ],
  )
]

== Ghidra Artifacts

#table(
  columns: (auto, auto, auto),
  inset: 8pt,
  align: (left, left, left),
  table.header([*Artifact*], [*Description*], [*Example*]),
  [Type annotations], [Size-based types], [`undefined4` #sym.arrow `int`],
  [Variable names], [Stack offsets], [`local_1c`, `param_1`],
  [Pointer arithmetic], [Explicit address calculations], [`*(int*)(ptr + i*4)`],
  [Data references], [Address-based labels], [`DAT_00104000`, `_LC0`],
)

*Goal:* Transform pseudocode into valid, compilable C code

== Research Questions

#set enum(numbering: "RQ1.")

+ How effectively does *LoRA* improve decompilation correctness?

+ Can *Knowledge Editing* correct systematic decompiler artifacts?

+ What error types are *addressable*, and what *limitations* remain?

+ How does *error-specific* training compare to *general* fine-tuning?

= Methodology

== CodeLlama

- Based on Llama 2, trained on 500B code tokens
- 7B to 34B parameters
- Strong at code understanding & generation
- Instruction-tuned variant follows directives

*Choice:* CodeLlama-7B-Instruct -- practical size for fine-tuning, instruction-following capability, openly available

== Prompt Template

#align(center)[
  #box(stroke: 0.5pt, inset: 1em, radius: 4pt)[
    #set text(size: 0.9em)
    ```
    <s>[INST] You are an expert C decompiler.
    Refine the following Ghidra pseudocode into
    valid, compilable C code.
    ...
    Pseudocode:
    {ghidra_pseudocode}
    [/INST]
    ```
  ]
]

== Low-Rank Adaptation (LoRA)

*Challenge:* Fine-tuning LLMs requires updating billions of parameters \
*Solution:* Inject small trainable matrices, keep base model frozen

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #align(center)[
      #diagram(
        node-stroke: 0.5pt,
        node-corner-radius: 4pt,
        spacing: (15mm, 6mm),

        node((0, 0), [$x$], stroke: none),
        node((0, 1), [$W_0$\ (frozen)], fill: rgb("#e0e0e0")),
        node((1, 1), [$A$], fill: rgb("#bbf7d0")),
        node((1, 2), [$B$], fill: rgb("#bbf7d0")),
        node((0, 3), [$h$], stroke: none),

        edge((0, 0), (0, 1), "-|>"),
        edge((0, 0), (1, 1), "-|>"),
        edge((0, 1), (0, 3), "-|>"),
        edge((1, 1), (1, 2), "-|>"),
        edge((1, 2), (0, 3), "-|>", label: [$+$]),
      )
    ]
  ],
  [
    - Train small matrices $A$, $B$
    - \~2% of parameters
    - No inference latency
    - Compatible with QLoRA (4-bit)
  ],
)

== Knowledge Editing (ROME)

*Hypothesis:* Decompilation errors = incorrect facts → surgically correct them

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *ROME:* Rank-one updates to MLP weights

    Original use: _"Eiffel Tower in Paris"_ → _"...London"_
  ],
  [
    #set text(size: 0.8em)
    *Decompilation as knowledge?*

    `(undefined4, "corresponds to C type", int)`
  ],
)

== Experimental Pipeline

#align(center)[
  #diagram(
    node-stroke: 0.5pt,
    node-corner-radius: 4pt,
    edge-stroke: 0.5pt,
    spacing: (18mm, 8mm),

    node((0, 0), [C Source]),
    edge("-|>"),
    node((1, 0), [GCC]),
    edge(
      "-|>",
      label: text(size: 8pt, fill: luma(100))[binary],
      label-side: left,
      label-sep: 1mm,
    ),
    node((2, 0), [Ghidra]),
    edge(
      "-|>",
      label: text(size: 8pt, fill: luma(100))[pseudocode],
      label-sep: 1mm,
    ),
    node((3, 0), [Model]),
    edge(
      "-|>",
      label: text(size: 8pt, fill: luma(100))[C code],
      label-sep: 1.5mm,
    ),
    node((4, 0), [Test]),
  )
]

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Training Data: ExeBench*
    - \~4,000 C functions
    - GCC → Ghidra
    - Filtered for Quality
  ],
  [
    *Evaluation: HumanEval-Decompile*
    - 151 functions with test harnesses
    - 5 runs per config
  ],
)

== Training Configuration

#table(
  columns: (auto, auto),
  inset: 6pt,
  [Base model], [CodeLlama-7B-Instruct],
  [Quantization], [4-bit],
  [LoRA targets], [All attn + MLP projections],
  [Epochs], [3],
  [Learning rate], [ $2 times 10^(-4)$],
  [Batch size], [16],
)

*Hardware:* Google Colab A100, bwHPC H100

== Evaluation Metrics

- *Pass\@1:* Compile → Execute → All assertions pass
- *Compile Rate:* Syntactically valid output

5 runs per config (temperature 0.2, top-p 0.95)

== Experimental Conditions

#table(
  columns: (auto, 1fr),
  inset: 10pt,
  align: (left, left),
  table.header([*Condition*], [*Description*]),
  [Baseline], [Unmodified CodeLlama-7B-Instruct],
  [General LoRA], [Fine-tuned on \~4,000 ExeBench samples],
  [ROME-edited], [Knowledge Editing],
  [Targeted LoRA], [Trained only on synthetic error examples],
  [Mixed LoRA], [General data + synthetic error examples (2:1 ratio)],
)

= Results

== LoRA Fine-Tuning Results

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #table(
      columns: (auto, auto, auto),
      inset: 6pt,
      align: (left, center, center),
      table.header([*Model*], [*Pass\@1*], [*Compile*]),
      [Baseline], [15.50%], [18.94%],
      [LoRA (r=64)], [*23.95%*], [*84.33%*],
    )

    - Pass\@1: +54% relative
    - Compile: *4.5× increase*
  ],
  [
    #box(stroke: 0.5pt, inset: 0.5em, radius: 4pt, fill: rgb("#fef3c7"))[
      *Baseline:* Outputs `undefined4`, `CONCAT44`, etc.
    ]

    #v(0.3em)

    #box(
      stroke: 2pt + rgb("#166534"),
      inset: 0.5em,
      radius: 4pt,
      fill: rgb("#dcfce7"),
    )[
      *LoRA:* Learns to remove these artifacts
    ]
  ],
)

== Knowledge Editing: A Negative Result

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  table.header([*Model*], [*Pass\@1*], [*Compile*]),
  [Baseline], [15.50%], [18.94%],
  [ROME-edited], [15.23%], [22.19%],
)

*Why doesn't it work?* The model *already knows* the facts:
#box(stroke: 0.5pt, inset: 0.5em, radius: 4pt)[
  Q: _"What C type is undefined4?"_ → A: _"int"_
]

The problem is *inconsistent application* of knowledge, not missing knowledge.

== Qualitative Example: Ghidra Input

#grid(
  columns: (1fr, 1fr),
  gutter: 1.5em,
  [
    #text(size: 0.55em)[
      ```c
      undefined8 func0(int *param_1,uint param_2)
      {
        int *piVar1;

        if (0 < (int)param_2) {
          piVar1 = param_1 + (int)param_2;
          if ((param_2 & 1) != 0) {
            *param_1 = *param_1 + 1;
            param_1 = param_1 + 1;
            if (param_1 == piVar1) {
              return 0;
            }
          }
          do {
            *param_1 = *param_1 + 1;
            param_1[1] = param_1[1] + 1;
            param_1 = param_1 + 2;
          } while (param_1 != piVar1);
        }
        return 0;
      }
      ```
    ]
  ],
  [
    *Artifacts:*
    - `undefined8` return type
    - `uint` parameter type
    - Unrolled loop structure

    *Original intent:* Increment each element of an array
  ],
)

== Qualitative Example: Model Outputs

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  [
    *Baseline* #text(fill: rgb("#b91c1c"))[(FAIL)]:
    #text(size: 0.5em)[
      ```c
      int func0(int *param_1, uint param_2)
      {
        int *piVar1 = param_1 + (int)param_2;
        if (param_2 & 1) {
          *param_1 = *param_1 + 1;
          param_1 = param_1 + 1;
          if (param_1 == piVar1)
            return 0;
        }
        do {
          *param_1 = *param_1 + 1;
          param_1[1] = param_1[1] + 1;
          param_1 = param_1 + 2;
        } while (param_1 != piVar1);
        return 0;
      }
      ```
    ]
    Preserves unrolled structure
  ],
  [
    *LoRA* #text(fill: rgb("#166534"))[(PASS)]:
    #text(size: 0.8em)[
      ```c
      void func0(int *p, int n)
      {
        int i;
        for (i = 0; i < n; i++)
          *p++ += 1;
      }
      ```
    ]

    #v(1em)
    Recognizes intent, simplifies loop
  ],
)

== Result Stability Analysis

#table(
  columns: (auto, auto, auto, 1fr),
  inset: 8pt,
  table.header([*Category*], [*Count*], [*%*], [*Implication*]),
  [Consistently passing], [20], [13.2%], [Robust solutions],
  [Consistently failing], [99], [65.6%], [Fundamental limitations],
  [Flaky (varies)], [32], [21.2%], [Near decision boundary],
)

*Key insight:* 21% of samples vary with minor sampling changes → single-run evaluation is misleading; multi-run evaluation essential

= Error Analysis

== Failure Types

#table(
  columns: (auto, auto, 1fr),
  inset: 6pt,
  table.header([*Failure Type*], [*%*], [*Meaning*]),
  [Assertion failure], [76.8%], [Compiles but wrong output],
  [Compilation error], [22.2%], [Invalid syntax or types],
  [Timeout], [1.0%], [Infinite loop],
)

*Key finding:* Most failures are semantic -- syntactic correction ≠ semantic correctness

== Semantic Error Taxonomy

#align(center)[
  #diagram(
    node-stroke: 0.5pt,
    node-corner-radius: 4pt,
    spacing: (12mm, 8mm),

    node((1, 0), [*Assertion Failures*\ (76 samples)]),

    edge((1, 0), (0, 1), "-|>"),
    edge((1, 0), (2, 1), "-|>"),

    node((0, 1), [*Addressable*\ \~45%], fill: rgb("#bbf7d0")),
    node((2, 1), [*Fundamental*\ \~55%], fill: rgb("#fecaca")),

    node(
      (0, 2),
      align(left)[
        • Loop bounds (20%)\
        • Operators (15%)\
        • Initialization (10%)
      ],
      stroke: none,
    ),

    node(
      (2, 2),
      align(left)[
        • Algorithm (35%)\
        • Info loss (10%)\
        • String/format (10%)
      ],
      stroke: none,
    ),

    edge((0, 1), (0, 2), "-"),
    edge((2, 1), (2, 2), "-"),
  )
]

= Addressing Errors

== Error-Specific Fine-Tuning

*Approach:* Synthetic data with systematic errors
- Loop bounds: `i < n` → `i <= n`
- Operators: `<` → `>`
- Initialization: remove/corrupt

#table(
  columns: (auto, auto, auto, 1fr),
  inset: 6pt,
  align: (left, center, center, left),
  table.header([*Model*], [*Pass\@1*], [*Compile*], [*Training Data*]),
  [Baseline], [15.50%], [18.94%], [None],
  [Targeted LoRA], [20.13%], [21.06%], [Only error examples],
  [General LoRA], [23.95%], [84.33%], [ExeBench samples],
  [*Mixed LoRA*], [*28.08%*], [64.50%], [General + errors (2:1)],
)

== Summary of All Results

#table(
  columns: (auto, auto, auto, auto),
  inset: 8pt,
  align: (left, center, center, center),
  table.header([*Model*], [*Pass\@1*], [*Compile*], [*Δ Pass\@1*]),
  [Baseline], [15.50%], [18.94%], [---],
  [ROME-edited], [15.23%], [22.19%], [-0.27],
  [Targeted LoRA], [20.13%], [21.06%], [+4.63],
  [General LoRA], [23.95%], [84.33%], [+8.45],
  [*Mixed LoRA*], [*28.08%*], [64.50%], [*+12.58*],
)

#align(center)[
  Best functional correctness: *81% relative improvement* over baseline
]

= Discussion

== The Syntactic-Semantic Gap

*Syntactic adaptation:* Readily achievable, even r=8 LoRA reaches 82% compile rate

*Semantic correctness:* Diminishing returns, all general configs \~23-24% Pass\@1

*Why?* \~55% of errors are fundamental (info loss, ambiguity)

== Why Knowledge Editing Fails

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Knowledge Editing:*
    - Atomic facts
    - Single corrections

    *Decompilation:*
    - Context-dependent
    - Multi-step reasoning
  ],
  [
    #align(center)[
      #diagram(
        node-stroke: 0.5pt,
        node-corner-radius: 4pt,
        spacing: (8mm, 10mm),

        node((0, 0), [Knowledge\ Editing], fill: rgb("#fecaca")),
        node((1, 0), [LoRA], fill: rgb("#bbf7d0")),

        node((0, 1), [Facts], stroke: none),
        node((1, 1), [Reasoning], stroke: none),

        edge((0, 0), (0, 1), "-"),
        edge((1, 0), (1, 1), "-"),
      )
    ]

    Decompilation is *reasoning*, not retrieval.
  ],
)

== Trade-offs in Mixed Training

#align(center)[
  #diagram(
    node-stroke: 0.5pt,
    node-corner-radius: 4pt,
    spacing: (25mm, 12mm),

    node((0, 0), [*General LoRA*\ Pass: 23.95%\ Compile: 84.33%]),
    node((2, 0), [*Mixed LoRA*\ Pass: 28.08%\ Compile: 64.50%]),

    edge((0, 0), (2, 0), "-|>", label: [+error data]),
  )
]

*Observation:* Improving semantic correctness trades off against syntactic validity

*Future direction:* Multi-objective optimization, curriculum learning

== Comparison with State-of-the-Art

#table(
  columns: (auto, auto, auto, auto),
  inset: 8pt,
  align: (left, center, center, center),
  table.header([*System*], [*Method*], [*Training Data*], [*Performance*]),
  [LLM4Decompile], [Full fine-tune], [Billions of tokens], [36.71%],
  [*This work*], [*LoRA*], [*\~4,000 samples*], [*28.08%*],
)

- Achieve *76% of SOTA* with orders of magnitude less data
- Parameter-efficient: only \~2% of weights trained
- Practical for resource-constrained settings

= Takeaways

== Summary of Contributions

#set enum(numbering: "1.")

+ *LoRA works:* 4.5× compile rate, 54-81% relative Pass\@1 improvement

+ *Knowledge Editing doesn't:* decompilation is reasoning, not retrieval

+ *Error taxonomy:* 45% addressable, 55% fundamental

+ *Syntactic-semantic gap:* compile rate ≠ correctness

== Future Work

- *Training:* Curriculum learning, multi-objective optimization, RLHF
- *Scaling:* Larger models, more training data
- *Better inputs:* Preserve more semantic info from decompiler
- *Architecture:* Chain-of-thought, RAG, multi-pass refinement
- *Extensions:* Other compilers, optimization levels, decompilers

= 5 Minute Demo <not-outlined>

#focus-slide[
  Any questions or thoughts?
]

#show: appendix

= Backup Slides <not-outlined>

== LoRA: Mathematical Details

$ h = W_0 x + Delta W x = W_0 x + (alpha / r) dot B A x $

#table(
  columns: (auto, auto),
  inset: 5pt,
  align: (left, left),
  [$W_0 in RR^(d times k)$], [Frozen pretrained weights],
  [$A in RR^(r times k)$], [Trainable down-projection],
  [$B in RR^(d times r)$], [Trainable up-projection],
  [$r << min(d, k)$], [Low rank (e.g., 64)],
  [$alpha$], [Scaling factor],
)

*Why it works:* Weight updates have low intrinsic rank, full-rank updates aren't needed.

== LoRA Hyperparameter Search

#table(
  columns: (auto, auto, auto),
  inset: 5pt,
  align: (left, center, center),
  table.header([*Rank / Alpha*], [*Pass\@1 (%)*], [*Compile (%)*]),
  [8 / 8], [20.93 ± 0.79], [82.38 ± 0.32],
  [16 / 16], [21.46 ± 2.03], [82.91 ± 1.59],
  [32 / 32], [23.44 ± 1.60], [84.77 ± 0.59],
  [32 / 64], [23.71 ± 1.84], [83.97 ± 0.77],
  [*64 / 64*], [*23.95 ± 1.35*], [84.33 ± 1.19],
  [64 / 128], [22.78 ± 0.90], [85.56 ± 1.59],
  [128 / 128], [23.18 ± 2.09], [84.50 ± 0.99],
)

Even r=8 achieves 82% compile; Pass\@1 plateaus at r=32-64; diminishing returns beyond.

== QLoRA: Quantized LoRA

*Problem:* 7B model needs \~28GB in FP32, \~14GB in FP16 \
*Solution:* 4-bit NormalFloat (NF4) quantization + LoRA

#grid(
  columns: (1fr, 1fr),
  gutter: 1.5em,
  [
    *How it works:*
    - Base weights quantized to 4-bit
    - LoRA adapters in FP16, receive gradients
    - Dequantize on-the-fly for forward pass
  ],
  [
    *Benefits:*
    #table(
      columns: (auto, auto),
      inset: 4pt,
      [Memory], [\~6GB for 7B model],
      [Speed], [Minimal overhead],
      [Quality], [Near FP16 performance],
    )
  ],
)

== ROME: Mathematical Details

*Goal:* Edit $(s, r, o) arrow.r (s, r, o^*)$ by modifying MLP weights

$ W^* = W + Delta, quad Delta = (C^(-1) k_*) (v_* - W k_*)^top $

#table(
  columns: (auto, 1fr),
  inset: 5pt,
  [$k_*$], [Key vector: hidden state at subject $s$],
  [$v_*$], [Target value: encodes new object $o^*$],
  [$C$], [Covariance of key vectors],
  [$W$], [Original MLP weights],
)

*Intuition:* Insert new key-value pair into MLP's associative memory

== Failure Example: Loop Bound Error

#text(size: 0.55em)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    [
      *Model output:*
      ```c
      int sum(int *arr, int n) {
        int total = 0;
        for (int i = 0; i <= n; i++) {
          total += arr[i];
        }
        return total;
      }
      ```
      #text(fill: rgb("#b91c1c"))[`i <= n` causes out-of-bounds access]
    ],
    [
      *Expected:*
      ```c
      int sum(int *arr, int n) {
        int total = 0;
        for (int i = 0; i < n; i++) {
          total += arr[i];
        }
        return total;
      }
      ```
      #text(fill: rgb("#166534"))[`i < n` is correct bound]
    ],
  )
]

*Category:* Addressable, off-by-one errors are systematic and trainable

== Failure Example: Algorithm Misidentification

#text(size: 0.55em)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    [
      *Model output:*
      ```c
      int find_max(int *arr, int n) {
        int max = 0;
        for (int i = 0; i < n; i++) {
          if (arr[i] > max)
            max = arr[i];
        }
        return max;
      }
      ```
      #text(fill: rgb("#b91c1c"))[Fails for all-negative arrays]
    ],
    [
      *Expected:*
      ```c
      int find_max(int *arr, int n) {
        int max = arr[0];
        for (int i = 1; i < n; i++) {
          if (arr[i] > max)
            max = arr[i];
        }
        return max;
      }
      ```
      #text(fill: rgb("#166534"))[Initialize with first element]
    ],
  )
]

*Category:* Fundamental, requires understanding algorithm intent from ambiguous pseudocode

#pagebreak()

#show bibliography: set text(size: 0.5em)
#bibliography("references.bib", full: true)
