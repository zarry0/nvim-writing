#let scene(heading) = block(
  width: 100%,
  above: 1.2em,
  below: 0.6em,
)[#strong(upper(heading))]

#let action(body) = block(
  width: 100%,
  below: 0.6em,
)[#body]

#let dialogue(name, body) = block(
  width: 100%,
  above: 0.5em,
  below: 0.5em,
)[
  #align(center)[
    #block(width: 3.5in)[
      #align(center, upper(name))
      #body
    ]
  ]
]

#let transition(label) = align(right, strong(upper(label)))

#let screenplay(
  title: none,
  author: none,
  contact: none,
  body,
) = {
  set page(
    paper: "us-letter",
    margin: (left: 1.5in, right: 1in, top: 1in, bottom: 1in),
    numbering: none,
  )
  set text(
    font: ("Courier Prime", "Courier New", "Courier"),
    size: 12pt,
  )
  set par(leading: 0.45em)

  align(center + horizon)[
    #text(size: 14pt, weight: "bold")[#title]
    #v(1em)
    #if author != none { [Escrito por #author] }
    #v(8em)
    #if contact != none { contact }
  ]
  pagebreak()
  set page(numbering: "1")
  body
}
