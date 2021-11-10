import amphetanim/spec
import amphetanim/slot
from amphetanim/slot/spec as sspec import writer
import amphetanim/primitives/atomics
import amphetanim/primitives/futex
import amphetanim/primitives/memalloc
import amphetanim/util_types/tagptr
import amphetanim/util/alignutils
# import amphetanim/primitives/cacheline
export spec

const cacheLineSize = 64

type
  LinePad[S: static int] = distinct array[S, char]
    ## Basic object that will cover the remaining cache line

  AmphetanimObj*[T; F: static AmphFlags; K: static AmphetanimKind] = object
    case kind: AmphetanimKind
    of akCubby:
      cubby: Atomic[TagPtr]

  Amphetanim*[T; F: static AmphFlags; K: static AmphetanimKind; S: static int] = ref object
    obj*: AmphetanimObj[T, F, K]
    padding: LinePad[S]

converter toAmphetanimObj*[T; F; K; S](amph: Amphetanim[T, F, K, S]): var AmphetanimObj[T, F, K] =
  amph.obj

proc initAmphetanim*[T; F; K; S](amph: Amphetanim[T, F, K, S]) =
  ## Initialise an AmphetanimObj
  template obj: untyped = amph.obj
  case obj.kind
  of akCubby:
    let initVal = cast[uint](allocAligned0(sizeof Slot, SLOT_ALIGN)) or median(slotAlignment)
    obj.cubby.store(initVal)

proc newAmphetanim*[T](kind: static AmphetanimKind; flags: static set[AmphFlag] = {afNoPadding}): auto =
  template f: untyped = toAmphFlags flags
  template s: untyped =
    when afPadding in flags and afNoPadding notin flags:
      cacheLineSize - sizeof(AmphetanimObj[T, f, kind]) mod cacheLineSize
    else:
      0

  result = Amphetanim[T, f, kind, s](obj: AmphetanimObj[T, f, kind](kind: kind))
  result.initAmphetanim()

proc push*[T; F, K](amph: var AmphetanimObj[T, F, K], el: T): bool =
  template saveT: untyped =
    when T is ref: GC_ref el
    else: discard
  template killT: untyped =
    when T is ref: GC_unref el
    else: discard
  template pel(e: T): untyped = (cast[uint](e) or writer)

  when akCubby == K:
    let tagptr = amph.cubby.fetchAdd(1)
    let tag = tagptr.getTag(slotAlignment)
    let sptr = getPtr(tagptr, Slot, slotAlignment)
    template trueTagVal: int = tag.medianDev(slotAlignment)

    if trueTagVal >= 1:
      when afBlocking in F:
        amph.cubby.addr().wait(trueTagVal())
      else:
        result = false
    else:
      result = true
      saveT()
      let prev = sptr[].write cast[uint](el)
      if not likely(prev.readFlags == 0'u):
        echo "PUSH FAILED; FLAG WRITTEN: ", prev.readFlags()
        # flag was already written
      when afBlocking in F:
        if trueTagVal < 0:
          wake(amph.cubby.addr())
        

proc pop*[T; F; K](amph: var AmphetanimObj[T, F, K]): T =
  # template killT(): untyped =

  when akCubby == K:
    let tagptr = amph.cubby.fetchSub(1)
    let tag = tagptr.getTag(slotAlignment)

    template trueTagVal: int = tag.medianDev(slotAlignment)

    template popImpl(body: untyped): untyped =
      let val = tagptr.getPtr(Slot, slotAlignment)[].read()
      if not likely(val.isWritten()):
        body
        echo val
      let res = val.readPtr()
      result = cast[T](res)
      tagptr.getPtr(Slot, slotAlignment)[].clear()
      when afBlocking in F:
        if trueTagVal() < 0:
          wake(amph.cubby.addr())


    if trueTagVal() <= 0:
      when afBlocking in F:
        amph.cubby.addr().wait(trueTagVal())
        while true:
          popImpl: continue
      else:
        echo "wait pop"
    else:
      popImpl: echo "failed"

  when T is ref:
    if not result.isNil: GC_unref result
  else: discard
