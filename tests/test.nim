import amphetanim/spec

type
  P = object of RootObj
    case m: bool
    of false:
      x: int
    else:
      y: float
  I = object of P
    case k: bool
    of true:
      a: int
    of false:
      b: float

var p = P(m: false, x: 5)
var i = I(m: false, x: 8, k: true, a: 3)

let t = getAmpheType i
echo t.flags
echo t.kind

if not t.base.isNil():
  let b = t.base[]
  let n = b.node[]
  echo n.name
  if not n.sons.isNil:
    let sons = n.sons[]
    for p in sons:
      if p.isNil:
        break
      let n = p[]
      # echo n.name
  echo n.len

let n = t.node[]
echo n.name
echo n.len
let sons = n.sons[]

for p in sons:
  if p.isNil:
    break
  let n = p[]
  echo n.name