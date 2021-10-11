import std/atomics

import amphetanim/spec
import amphetanim/primitives/futex
export spec

type
  ControlBlock = object
    pos: Atomic[uint32]
    waiters: Atomic[uint32]
    ppad: array[32-1, uint16]
  Amphetanim*[T: ref; S: static int; F: static AmphFlags] = ref object
    slots: array[S.getLen, uint]
    ppad: array[S.getPadLen, uint]
    control: ControlBlock

template hasWaiters(cblock: ControlBlock): bool =
  cblock.waiters.load(moRelaxed) > 0'u32

template getPos(cblock: ControlBlock): uint32 =
  cblock.pos.load(moRelaxed)

template fetchAddReader(cblock: ControlBlock,
                        order: MemoryOrder = moAcquire): uint16 =
  cblock.pos.fetchAdd(1 shl 15, order).getU16
template fetchAddWriter(cblock: ControlBlock,
                        order: MemoryOrder = moAcquire): uint16 =
  cblock.pos.fetchAdd(1, order).getL16
template resetReader(cblock: ControlBlock,
                      order: MemoryOrder = moRelease): uint32 =
  cblock.pos.fetchAnd(L16MASK, order)
template resetWriter(cblock: ControlBlock,
                      order: MemoryOrder = moRelease): uint32 =
  cblock.pos.fetchAnd(U16MASK, order)

template subPullWaiter(cblock: ControlBlock): uint16 =
  cblock.waiters.fetchSub(1 shl 15, moAcquire).getU16
template addPullWaiter(cblock: ControlBlock): uint16 =
  cblock.waiters.fetchAdd(1 shl 15, moRelease).getU16
template subPushWaiter(cblock: ControlBlock): uint16 =
  cblock.waiters.fetchSub(1, moAcquire).getL16
template addPushWaiter(cblock: ControlBlock): uint16 =
  cblock.waiters.fetchAdd(1, moRelease).getL16

func compositeLen(val: int): int =
  ## Ensure the slots covers 64 byte cache lines
  result = (val) shl PAD_SHIFT  # Each consumer must also have a producer slot
  if ((val) mod 8) != 0:
    result = result.setPad(8 - ((val) mod 8))

proc newAmphetanim*[T](ssize: static int = 1,
                      flags: static set[AmphFlag] = {Blocking}): auto =
  result = Amphetanim[T, compositeLen ssize, toAmphFlags(flags)]()

func len*[T, S, F](amph: Amphetanim[T, S, F]): int =
  S.getLen div 2

func paddingLen*[T, S, F](amph: Amphetanim[T, S, F]): int =
  S.getPadLen

proc push*[T, S, F](amph: Amphetanim[T, S, F], el: T): bool =
  converter toUInt(x: T): uint =
    cast[uint](x)
  template pushLoop(body: untyped): untyped {.dirty.} =
    GC_ref el
    var idx: uint32 = amph.control.fetchAddWriter()
    while true:
      body
  when Blocking in F: pushLoop:    
    # Loop until reset writer
    if not idx < S.uint16:
      if idx == S.uint16:
        # When the idx is the same as the length then
        # we have to reset the writer idx before progressing
        discard amph.control.resetWriter()
        idx = amph.control.fetchAddWriter()
        continue
      else:
        # Those threads that exceed the length will
        # have to loop until the value is changed
        idx = amph.control.fetchAddWriter(moReleased)
        continue
    var slot = amph.slots[idx].load(moAcquire)
    if slot.getSlotVal == 0'u:
      if slot == 0'u and amph.slots[idx].compareExchange(slot, el, moRelease):
        result = true
        break
      elif slot.getSlotFlags == WAIT_PULL:
        if not amph.slots[idx].compareExchange(WAIT_PULL, el and WAIT_PULL, moRelease):
          idx = amph.control.fetchAddWriter()
          continue
        wake(amph.slots[idx].addr)
        result = true
        break
    if slot.getSlotFlags == 0'u:
      if amph.slots[idx].fetchOr(WAIT_PUSH, moRelease).getSlotFlags == 0'u:
        slot = slot.getSlotVal or WAIT_PUSH
      else:
        discard amph.slots[idx].fetchXor(WAIT_PUSH, moAcquire)
    if slot.getSlotFlags == WAIT_PUSH:
      # slot has waiters and value already set
      discard amph.control.addPushWaiter()
      wait(amph.slots[idx].addr, slot)
      if amph.control.subPushWaiter() == 1'u:
        amph.slots[idx].fetchAnd(high(uint) - WAIT_PUSH, moRelease)
    
  else:
    discard

proc pull*[T, S, F](amph: Amphetanim[T, S, F]): T =
  converter toUInt(x: T): uint =
    cast[uint](x)
  template pullLoop(body: untyped): untyped {.dirty.} =
    var idx: uint32 = amph.control.fetchAddReader()
    while true:
      body
  when Blocking in F: pullLoop:    
    if not idx < S.uint16:
      if idx == S.uint16:
        discard amph.control.resetReader()
        idx = amph.control.fetchAddReader()
        continue
      else:
        idx = amph.control.fetchAddReader(moReleased)
        continue
    var slot = amph.slots[idx].load(moAcquire)
    if slot.getSlotVal > 0'u:
      if slot.getSlotFlags == 0'u and amph.slots[idx].compareExchange(slot, 0'u, moAcquire):
        result = cast[T](slot)
        break
      elif slot.getSlotFlags == WAIT_PUSH:
        var el = amph.slots[idx].fetchAnd(FLAG_MASK, moAcquire)        
        wake(amph.slots[idx].addr)
        result = cast[T](el.getSlotVal)
        GC_unref el
        break
    if slot.getSlotFlags == 0'u:
      if amph.slots[idx].fetchOr(WAIT_PULL, moRelease).getSlotFlags == 0'u:
        slot = slot.getSlotVal or WAIT_PULL
      else:
        discard amph.slots[idx].fetchXor(WAIT_PULL, moRelease)
    if slot.getSlotFlags == WAIT_PULL:
      # slot has waiters and value already set
      discard amph.control.addPullWaiter()
      wait(amph.slots[idx].addr, slot)
      if amph.control.subPullWaiter() == 1'u:
        amph.slots[idx].fetchAnd(high(uint) - WAIT_PULL, moRelease)
  else:
    discard
