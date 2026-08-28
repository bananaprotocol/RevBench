#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

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
