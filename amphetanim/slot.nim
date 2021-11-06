import amphetanim/spec
import amphetanim/primitives/atomics

type
  Slot*[T] = object
    when compileOption"threads":
      val: Atomic[uint]
    else:
      rval: uint

proc rawRead*(slot: Slot): uint =
  when compileOption"threads":
    slot.val.load(moRelaxed)
  else:
    slot.rval
