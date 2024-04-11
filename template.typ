#import "@preview/diagraph:0.2.1": *

#let show_intro(title: str, body: str) = [
  #set par(justify: true)
#let t = {
  set text(size: 34pt)
  [#title]
}

#t

#body
]

#let show_hlr(hlr: (), body: str) = [
#set heading(numbering: "1.a")
= High Level Requirements

#body

#for (index, r) in hlr [
  #index. #r.title

]

#for (index, r) in hlr [
  == HLR #index - #r.title #label("HLR" + index)
  #r.description
]
]

#let show_overview(actors: (), body: str) = [
#set heading(numbering: "1.a")
= Protocol overview

#body

== Actors

#let table_content = for (index, r) in actors {
    (r.title, r.description)
}

#table(
  columns: 2,
  [*Actor name*], [*Actor description*],
  ..table_content
)

== Visual Protocol Overview

#render("digraph protocol_overview {size=\"7.75,10.25\"; " + actors.keys().map(index => index + " [label=\"" + actors.at(index).title + "\"] ").fold("",(a,b)=>a+b) + actors.keys().map(index => actors.at(index).interaction.map(i => " " + index + " -> " + i.index + " [label=\"" + i.transaction + "\"] ").fold("",(a,b)=>a+b)).fold("",(a,b)=>a+b) + "}")
]