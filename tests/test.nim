import cps
import amphetanim

type
  C = ref object of Continuation
    val: int


proc incVal(c: C): C {.cpsMagic.} =
  c.val.inc
    

proc doThings() {.cps:C.} =
  var x = 5
  incVal()



let amph = newAmphetanim[Continuation]()