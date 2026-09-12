#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#set page(width: auto, height: auto, margin: 4pt, fill: white)

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
