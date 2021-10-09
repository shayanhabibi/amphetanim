import cps
import amphetanim

type
  C = ref object of Continuation
    val: int
  Banana = ref object

var amph = newAmphetanim[Continuation]()

proc incVal(c: C): C {.cpsMagic.} =
  c.val.inc
  c  

proc doThings() {.cps:C.} =
  var x = 5
  echo "poopoo"
  incVal()


var el = whelp doThings()
echo el.running()
let (slot1, slot2) = amph.getSlots()
echo cast[pointer](el).repr
echo slot1.push(el)
var c = slot2.pull
echo cast[pointer](c).repr
echo c.running()
echo "==========="
while c.running:
  c = trampoline c