#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#set page(width: auto, height: auto, margin: 4pt, fill: white)

#diagram(
  node-stroke: 0.5pt,
  node-corner-radius: 4pt,
  spacing: (12mm, 8mm),

  node((1, 0), [*Assertion Failures*\ \(76 samples)]),

  edge((1, 0), (0, 1), "-|>"),
  edge((1, 0), (2, 1), "-|>"),

  node((0, 1), [*Addressable*\ \~45%], fill: rgb("#bbf7d0")),
  node((2, 1), [*Fundamental*\ \~55%], fill: rgb("#fecaca")),

  node(
    (0, 2),
    align(left)[
    • Loop bounds (20%) \
    • Operators (15%) \
    • Initialization (10%)
    ],
    stroke: none,
  ),
  node(
    (2, 2),
    align(left)[
    • Algorithm (35%) \
    • Info loss (10%) \
    • String/format (10%)
    ],
    stroke: none,
  ),

  edge((0, 1), (0, 2), "-"),
  edge((2, 1), (2, 2), "-"),
)
