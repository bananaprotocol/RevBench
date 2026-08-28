#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

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
