import cps
import amphetanim/spec
import amphetanim/tokens
export spec, tokens

type
  ControlBlock = object
    tag: uint16
    ppad: array[32-1, uint16]
  Amphetanim*[T: ref; S: static int; F: static AmphFlags] = ref object
    slots: array[S.getLen, uint]
    ppad: array[S.getPadLen, uint]
    control: ControlBlock

var zeroComp {.global.}: uint = 0'u

func initAmphetanim(amph: Amphetanim) =
  discard 

func compositeLen(val: int): int =
  ## Ensure the slots covers 64 byte cache lines
  result = (val * 2) shl PAD_SHIFT  # Each consumer must also have a producer slot
  if ((val * 2) mod 8) != 0:
    result = result.setPad(8 - ((val * 2) mod 8))

proc newAmphetanim*[T](ssize: static int = 1,
                      flags: static set[AmphFlag] = {Spsc}): auto =
  result = Amphetanim[T, compositeLen ssize, toAmphFlags(flags)]()
  initAmphetanim result

proc getSlots*[T; S; F](amph: Amphetanim[T, S, F]): (AmphToken[T, F], AmphToken[T, F]) =
  var res: int = atomicFetchAdd(addr(amph.control.tag), 2, ATOMIC_RELEASE).int
  if res.int < S.getLen:
    result = (AmphToken[T, F](tok: res, val: amph.slots[res].addr()),
              AmphToken[T, F](tok: res + 1, val: amph.slots[res].addr()))
  else:
    result = (AmphToken[T, F](tok: -1), AmphToken[T, F](tok: -1))

func len*[T, S, F](amph: Amphetanim[T, S, F]): int =
  S.getLen div 2

func paddingLen*[T, S, F](amph: Amphetanim[T, S, F]): int =
  S.getPadLen

proc push*[T; F](tok: AmphToken[T, F], el: T): bool =
  GC_ref el
  result = atomicCompareExchangeN(tok.getPushSlot(), addr zeroComp, cast[uint](el), false, ATOMIC_RELEASE, ATOMIC_RELAXED)
  if not result:
    GC_unref el
proc pull*[T; F](tok: AmphToken[T, F]): T =
  let res = atomicExchangeN(tok.getPullSlot(), 0'u, ATOMIC_ACQUIRE)
  result = cast[T](res)
  if not result.isNil:
    GC_unref result
