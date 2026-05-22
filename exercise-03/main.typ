#let exnr = "2"
#let authors = (
  "Jonas Möwes",
  "Daubner, Andy",
  "Rockenzahn Gallegos, David",
)

#set list(marker: ([--], [--], [--]))

#let course = "High Performance and Distributed Computing"
#let group = "Group 6"
#let date = datetime.today()
#show regex("Task \d+:"): strong
#show "Task:": strong
#show "Answer:": strong
#show regex("Result.*:"): strong
#let line2() = line(length: 7%, stroke: 1pt + gray.darken(50%))

#let round4(body) = calc.round(body, digits: 4)
#let round2(body) = calc.round(body, digits: 2)

#set text(
  font: "New Computer Modern",
  size: 11pt,
)
#show raw: set text(font: "Iosevka NF")

#set page(numbering: "(i)", header: [
  #set text(8pt)
  #grid(
    columns: 2,
    column-gutter: 1fr,
    row-gutter: 0.5em,
    align: (left, right),
    course, [University Heidelberg],
    group, date.display("[day].[month].[year]"),
  )
])

#set heading(numbering: "1.1")
#show heading: it => block(
  below: 1em,
  {
    if it.numbering != none {
      // Adds "Section " before the number
      exnr + "." + counter(heading).display(it.numbering) + " - "
    }
    it.body
  },
)

#align(right, text(10pt)[
  #authors.join(linebreak())
])

#align(center, title([Exercise #exnr]))
= Ex 1
= Willingness to present
#grid(
  columns: 2,
  column-gutter: 1fr,
    grid(
      columns: 2,
      row-gutter:1em,
      column-gutter: 20pt,
      [Ex 1], text(green)[#sym.checkmark],
      [Ex 2], text(green)[#sym.checkmark],
  ),
    grid(
      columns: 2,
      row-gutter:1em,
      column-gutter: 20pt,
      [Ex 3] ,text(green)[#sym.checkmark],
      [Ex 4], text(green)[#sym.checkmark]),
)




