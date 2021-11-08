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
    padding*: LinePad[S]

converter toAmphetanimObj*[T, F, K, S](amph: Amphetanim[T, F, K, S]): var AmphetanimObj[T, F, K] =
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

  template pel: untyped = (cast[uint](el) or writer)

  when akCubby == K:
    let tagptr = amph.cubby.fetchAdd(1)
    echo tagptr
    let tag = tagptr.getTag(slotAlignment)

    template trueTagVal: int = tag.medianDev(slotAlignment)

    if trueTagVal >= 1:
      echo trueTagVal
      echo "wait push"
    else:
      echo trueTagVal
      echo "go push"

  
  if not result: killT()

proc pop*[T; F; K](amph: var AmphetanimObj[T, F, K]): T =
  # template killT(): untyped =
    
  when akCubby == K:
    let tagptr = amph.cubby.fetchSub(1)
    let tag = tagptr.getTag(slotAlignment)

    template trueTagVal: int = tag.medianDev(slotAlignment)

    if trueTagVal < 1:
      echo trueTagVal
      echo "wait pop"
    else:
      echo trueTagVal
      echo "go pop"

  when T is ref:
    if not result.isNil: GC_unref result
  else: discard
