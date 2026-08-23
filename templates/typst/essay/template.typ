#let essay(
  title: none,
  author: none,
  course: none,
  date: none,
  language: "es",
  body,
) = {
  set page(
    paper: "a4",
    margin: (left: 3cm, right: 3cm, top: 2.5cm, bottom: 2.5cm),
    numbering: "1",
  )
  set text(
    font: ("Libertinus Serif", "New Computer Modern"),
    size: 12pt,
    lang: language,
  )
  set par(
    justify: true,
    leading: 0.8em,
    first-line-indent: 1.25cm,
  )
  set heading(numbering: "1.")

  align(center)[
    #text(size: 18pt, weight: "bold")[#title]
    #v(0.8em)
    #author
    #if course != none { [#linebreak()#course] }
    #if date != none { [#linebreak()#date] }
  ]
  v(2em)

  body
}
