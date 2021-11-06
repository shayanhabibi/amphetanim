import amphetanim/spec
import amphetanim/slot
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
    slot: Slot

  Amphetanim*[T; F: static AmphFlags; S: static int] = ref object
    obj*: AmphetanimObj[T, F]
    padding*: LinePad[S]

converter toAmphetanimObj*[T, F, S](amph: Amphetanim[T, F, S]): AmphetanimObj[T, F] =
  amph.obj

proc newAmphetanim*[T](flags: static set[AmphFlag] = {afNoPadding}): auto =
  template f: untyped = toAmphFlags flags
  template s: untyped =
    when afPadding in flags and afNoPadding notin flags:
      cacheLineSize - sizeof(AmphetanimObj[T, f]) mod cacheLineSize
    else:
      0
  result = Amphetanim[T, f, s](
    obj: AmphetanimObj[T, f]()
  )

proc push*[T; F](amph: AmphetanimObj[T, F], el: T): bool =
  discard