#let show_intro(title: str, body: str) = [
  #set par(justify: true)
#set heading(numbering: "1.a")
#let t = {
  set text(size: 34pt)
  [#title]
}

#t

#body
]

#let show_hlr(hlr: (), body: str) = [

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