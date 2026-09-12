#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#set page(width: auto, height: auto, margin: 4pt, fill: white)

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
