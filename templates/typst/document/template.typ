#let document(
  title: none,
  author: none,
  date: none,
  language: "es",
  body,
) = {
  set page(
    paper: "a4",
    margin: (x: 2.5cm, y: 2.5cm),
    numbering: "1",
  )
  set text(
    font: ("Libertinus Serif", "New Computer Modern"),
    size: 11pt,
    lang: language,
  )
  set par(
    justify: true,
    leading: 0.65em,
    first-line-indent: 1.25em,
  )
  set heading(numbering: "1.")

  if title != none {
    align(center)[
      #text(size: 20pt, weight: "bold")[#title]
      #v(1em)
      #if author != none { author }
      #if date != none { [#linebreak()#date] }
    ]
    v(2em)
  }

  body
}
