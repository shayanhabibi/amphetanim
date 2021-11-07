import amphetanim/spec
import amphetanim/slot
from amphetanim/slot/spec as sspec import writer
import amphetanim/primitives/atomics
import amphetanim/primitives/futex
import amphetanim/primitives/memalloc
# import amphetanim/primitives/cacheline
export spec

const cacheLineSize = 64

type
  LinePad[S: static int] = distinct array[S, char]
    ## Basic object that will cover the remaining cache line

  AmphetanimObj*[T; F: static AmphFlags] = object
    case kind: AmphetanimKind
    of akCubby:
      cubby: ptr Slot

  Amphetanim*[T; F: static AmphFlags; S: static int] = ref object
    obj*: AmphetanimObj[T, F]
    padding*: LinePad[S]

converter toAmphetanimObj*[T, F, B, S](amph: Amphetanim[T, F, S]): auto =
  amph.obj

proc initAmphetanim*[T; F](amph: AmphetanimObj[T, F]) =
  ## Initialise an AmphetanimObj
  case amph.kind
  of akCubby:
    discard

proc newAmphetanim*[T](kind: AmphetanimKind; flags: static set[AmphFlag] = {afNoPadding}): auto =
  template f: untyped = toAmphFlags flags
  template s: untyped =
    when afPadding in flags and afNoPadding notin flags:
      cacheLineSize - sizeof(AmphetanimObj[T, f]) mod cacheLineSize
    else:
      0

  result = Amphetanim[T, f, s](obj: AmphetanimObj[T, f](kind: kind))
  result.init()

proc push*[T; F](amph: AmphetanimObj[T, F], el: T): bool =
  template saveT: untyped =
    when T of ref: GC_ref el
    else: discard
  template killT: untyped =
    when T of ref: GC_unref el
    else: discard
  template basePush(slot: Slot): untyped =
    slot.write(cast[uint](el))

  template pel: untyped = (cast[uint](el) or writer)

  when akCubby == amph.kind:
    saveT()
    result = amph.cubby.swap(0'u, pel, moSeqCon)
  
  if not result: killT()